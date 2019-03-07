import UIKit
import AVFoundation
import Vision

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
  
  // MARK: Load the Model
  lazy var classificationRequest: [VNRequest] = {
    do {
      // Load the Custom Vision model.
      // To add a new model, drag it to the Xcode project browser making sure that the "Target Membership" is checked.
      // Then update the following line with the name of your new model.
      let model = try VNCoreMLModel(for: Fruit().model)
      let classificationRequest = VNCoreMLRequest(model: model, completionHandler: self.handleClassification)
        classificationRequest.imageCropAndScaleOption = .centerCrop
      return [ classificationRequest ]
    } catch {
      fatalError("Can't load Vision ML model: \(error)")
    }
  }()
  
  // MARK: Handle image classification results
  
  func handleClassification(request: VNRequest, error: Error?) {
    guard let observations = request.results as? [VNClassificationObservation]
      else { fatalError("unexpected result type from VNCoreMLRequest") }
    
    guard let best = observations.first else {
      fatalError("classification didn't return any results")
    }
    
    // Use results to update user interface (includes basic filtering)
    print("\(best.identifier): \(best.confidence)")
    if best.identifier.starts(with: "Unknown") || best.confidence < confidence {
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
        self.bubbleLayer.string = best.identifier.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      }
    }
  }
  
  // MARK: Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewView.layer.addSublayer(previewLayer)
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
          fatalError("Can't convert to CVImageBuffer.")
      }

      let exifOrientation = exifOrientationFromDeviceOrientation()
      let classifierRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: exifOrientation, options: [:])
      try classifierRequestHandler.perform(classificationRequest)
    } catch {
      print(error)
    }
  }
}

public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
    let curDeviceOrientation = UIDevice.current.orientation
    let exifOrientation: CGImagePropertyOrientation
    
    switch curDeviceOrientation {
    case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
        exifOrientation = .left
    case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
        exifOrientation = .upMirrored
    case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
        exifOrientation = .down
    case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
        exifOrientation = .up
    default:
        exifOrientation = .up
    }
    return exifOrientation
}

// Only used for debugging.
// Turns an image buffer into a UIImage that is easier to display in the UI or debugger.
func imageBufferToUIImage(_ imageBuffer: CVImageBuffer) -> UIImage {
  
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
  
  let image = UIImage(cgImage: quartzImage!, scale: 1.0, orientation: .right)
  
  return image
}
