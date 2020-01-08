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
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var lowerView: UIView!

    var previewLayer: AVCaptureVideoPreviewLayer!
    let bubbleLayer = BubbleLayer(string: "")

    let queue = DispatchQueue(label: "videoQueue")
    var captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice?
    let videoOutput = AVCaptureVideoDataOutput()
    var unknownCounter = 0 // used to track how many unclassified images in a row
    let confidence: Float = 0.7

    var skill: CVSClassifier!
  
    // MARK: Lifecycle
  
    override func viewDidLoad() {
        super.viewDidLoad()
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewView.layer.addSublayer(previewLayer)

        // create skill configuration
        let config = CVSClassifierConfig()
        config.modelFile.string = Bundle.main.bundlePath.appending("/Fruit/cvexport.manifest")
        config.build()

        // create skill instance
        skill = CVSClassifier(config: config);
    }

    override func viewDidAppear(_ animated: Bool) {
        bubbleLayer.opacity = 0.0
        bubbleLayer.position.x = self.view.frame.width / 2.0
        bubbleLayer.position.y = lowerView.frame.height / 2
        lowerView.layer.addSublayer(bubbleLayer)

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
                if (diff > 0) {
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

            // set runner inputs
            skill?.threshold.value = 0.0 // want to see even low confidence returns
            skill?.maxReturns.value = 1 // this model is just a boolean is/is not
            skill?.image.image = image

            // run and report results
            skill?.run()

            guard let bestConfidence = skill?.confidences.value(at: 0) else {
                throw NSError(domain: "Can't get confidence.", code: -1, userInfo: nil)
            }
            guard let bestIdentifier = skill?.identifiers.string(at: 0) else {
                throw NSError(domain: "Can't get identifier.", code: -1, userInfo: nil)
            }

            // Use results to update user interface (includes basic filtering)
            print("\(bestIdentifier): \(bestConfidence)")
            if bestIdentifier.starts(with: "Unknown") || bestConfidence < confidence {
                if self.unknownCounter < 3 { // a bit of a low-pass filter to avoid flickering
                    self.unknownCounter += 1
                } else {
                    self.unknownCounter = 0
                    DispatchQueue.main.async {
                        self.bubbleLayer.string = nil
                    }
                }
            } else {
                self.unknownCounter = 0
                DispatchQueue.main.async {
                    // Trimming labels because they sometimes have unexpected line endings which show up in the GUI
                    self.bubbleLayer.string = bestIdentifier.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                }
            }
        } catch {
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
