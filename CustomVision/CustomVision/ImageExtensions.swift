import UIKit

// https://stackoverflow.com/questions/44400741/convert-image-to-cvpixelbuffer-for-machine-learning-swift
extension UIImage {
  
  func resize(to newSize: CGSize) -> UIImage {
    
    let widthScaleRatio = newSize.width / size.width
    let heightScaleRatio = newSize.height / size.height
    
    // scale to fill
    let scaleRatio = (widthScaleRatio > heightScaleRatio) ? widthScaleRatio : heightScaleRatio
    let scaledWidth = size.width * scaleRatio
    let scaledHeight = size.height * scaleRatio
    
    let xHalfDiff = (scaledWidth > newSize.height) ? (scaledWidth - newSize.height) / 2 : 0
    let yHalfDiff = (newSize.height > scaledWidth) ? (newSize.height - scaledWidth) / 2 : 0
    
    UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
    self.draw(in: CGRect(x: -xHalfDiff, y: -yHalfDiff, width: scaledWidth, height: scaledHeight))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return resizedImage
  }
  
  func pixelBuffer() -> CVPixelBuffer? {
    let width = self.size.width
    let height = self.size.height
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     Int(width),
                                     Int(height),
                                     kCVPixelFormatType_32ARGB,
                                     attrs,
                                     &pixelBuffer)
    
    guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
      return nil
    }
    
    CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)
    
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: pixelData,
                                  width: Int(width),
                                  height: Int(height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                  space: rgbColorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
                                    return nil
    }
    
    context.translateBy(x: 0, y: height)
    context.scaleBy(x: 1.0, y: -1.0)
    
    UIGraphicsPushContext(context)
    self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    return resultPixelBuffer
  }
}
