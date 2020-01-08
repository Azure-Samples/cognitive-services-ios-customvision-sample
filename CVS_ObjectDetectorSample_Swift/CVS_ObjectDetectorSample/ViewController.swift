// Copyright (c) Microsoft Corporation.  All rights reserved.

import UIKit
import AVFoundation
import Vision
import CVSInference

// controlling the pace of the machine vision analysis
var lastAnalysis: TimeInterval = 0
var pace: TimeInterval = 0.33 // in seconds, classification will not repeat faster than this value

// performance tracking
let trackPerformance = false // use "true" for performance logging
var frameCount = 0
let framesPerSample = 10
var startDate = NSDate.timeIntervalSinceReferenceDate

class ViewController: UIViewController {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var boundingBoxView: UIView!

    var previewLayer: AVCaptureVideoPreviewLayer!

    let queue = DispatchQueue(label: "videoQueue")
    var captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice?
    let videoOutput = AVCaptureVideoDataOutput()

    var unknownCounter = 0 // used to track how many unclassified images in a row
    let confidence: Float = 0.7
    var objectDetector: CVSObjectDetector!

    let colors = [
        UIColor.cyan,
        UIColor.magenta,
        UIColor.orange,
        UIColor.purple,
        UIColor.yellow,
        UIColor.brown,
        UIColor.red,
        UIColor.blue,
        UIColor.green,
        UIColor.white] // color for identifiers
    var supportedIdentifiers: [String]!

    // MARK: Lifecycle
  
    override func viewDidLoad() {
        super.viewDidLoad()
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewView.layer.addSublayer(previewLayer)

        // ObjectDetector configuration
        let config = CVSObjectDetectorConfig()
        config.modelFile.string = Bundle.main.bundlePath.appending("/CatDog/cvexport.manifest")
        config.build()
        supportedIdentifiers = config.supportedIdentifiers.values;

        // create ObjectDetector
        objectDetector = CVSObjectDetector(config: config);
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = previewView.bounds;
    }

    // MARK: Camera handling
  
    func setupCamera() {
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)

        if let device = deviceDiscovery.devices.last {
            captureDevice = device
            beginSession()
        }
    }
  
    func beginSession() {
        do {
        videoOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String) : (NSNumber(value: kCVPixelFormatType_32BGRA) as! UInt32)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)

        captureSession.sessionPreset = .hd1920x1080
        captureSession.addOutput(videoOutput)

        let input = try AVCaptureDeviceInput(device: captureDevice!)
        captureSession.addInput(input)

        captureSession.startRunning()
        } catch {
            print("error connecting to capture device")
        }
    }
}

// MARK: Video Data Delegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  
    // called for each frame of video
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
        let currentDate = NSDate.timeIntervalSinceReferenceDate
    
        // control the pace of the machine vision to protect battery life
        if currentDate - lastAnalysis >= pace {
            lastAnalysis = currentDate
        } else {
            return // don't run the classifier more often than we need
        }
    
        // keep track of performance and log the frame rate
        if trackPerformance {
            frameCount = frameCount + 1
            if frameCount % framesPerSample == 0 {
                let diff = currentDate - startDate
                if diff > 0 {
                    if pace > 0.0 {
                        print("WARNING: Frame rate of image classification is being limited by \"pace\" setting. Set to 0.0 for fastest possible rate.")
                    }
                    print("\(String.localizedStringWithFormat("%0.2f", (diff/Double(framesPerSample))))s per frame (average)")
                }
                startDate = currentDate
            }
        }
    
        do {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                throw NSError(domain: "Can't convert to CVImageBuffer.", code: -1, userInfo: nil)
            }
            let image = imageBufferToUIImage(imageBuffer, orientation: imageOrientationFromDeviceOrientation())

            // ObjectDetector input
            objectDetector?.threshold.value = 0.4
            objectDetector?.maxReturns.value = 10
            objectDetector?.image.image = image

            // run ObjectDetector
            objectDetector?.run()

            // ObjectDetector outputs
            let identifiers = self.objectDetector.identifiers
            let identifierIndex = self.objectDetector.identifierIndexes
            let confidences = self.objectDetector.confidences
            let boundingBoxes = self.objectDetector.boundingBoxes

            DispatchQueue.main.async {
                // remove previous bounding boxes
                self.boundingBoxView.layer.sublayers = nil
                
                // create bounding boxes about detected object
                let countOfIdentifiers = identifiers?.countOfString() ?? 0
                for index in 0..<countOfIdentifiers {
                    guard let identifier = identifiers?.string(at: index) else {
                        continue
                    }
                    guard let identifierIndex = identifierIndex?.value(at: index) else {
                        continue
                    }
                    guard let confidence = confidences?.value(at: index) else {
                        continue
                    }
                    guard let rect = boundingBoxes?.rect(at: index) else {
                        continue
                    }

                    // convert to rect in screen
                    let p1 = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint.init(
                        x: rect.minX,
                        y: rect.minY))
                    let p2 = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint.init(
                        x: rect.maxX,
                        y: rect.maxY))
                    let frame = CGRect.init(
                        x: min(p1.x, p2.x),
                        y: min(p1.y, p2.y),
                        width: abs(p2.x - p1.x),
                        height: abs(p2.y - p1.y))
                
                    // determine color by index of indentifier
                    let color: UIColor = self.colors[Int(identifierIndex) % self.colors.count];

                    // create bounding box layer and add to view
                    let layer = BoundingBoxLayer.init()
                    layer.frame = frame
                    layer.label = String(format: "%@ %.1f", identifier, confidence * 100)
                    layer.color = color
                    self.boundingBoxView.layer.addSublayer(layer)
                }
            }
        }
        catch {
            print(error)
        }
    }
}

public func imageOrientationFromDeviceOrientation() -> UIImage.Orientation {
    let curDeviceOrientation = UIDevice.current.orientation
    let imageOrientation: UIImage.Orientation
    
    switch curDeviceOrientation {
    case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
        imageOrientation = .left
    case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
        imageOrientation = .up
    case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
        imageOrientation = .down
    case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
        imageOrientation = .right
    default:
        imageOrientation = .up
    }
    return imageOrientation
}

func imageBufferToUIImage(_ imageBuffer: CVImageBuffer, orientation: UIImage.Orientation) -> UIImage {
  
    CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

    let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)

    let width = CVPixelBufferGetWidth(imageBuffer)
    let height = CVPixelBufferGetHeight(imageBuffer)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

    let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)

    let quartzImage = context!.makeImage()
    CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

    let image = UIImage(cgImage: quartzImage!, scale: 1.0, orientation: orientation)

    return image
}
