import CoreImage
import Foundation
import Metal
import libwebp

@objc public class ImageUtils: NSObject {
  @objc public func sayHello(imageData: Data, targetSize: CGSize) -> Data? {
    // Step 1: Decode WebP to a format Core Image can work with
    guard let webPImage = WebPDecoder.decode(imageData) else {
      return nil
    }

    // Create a CGImage from the WebP data
    guard let cgImage = webPImage.cgImage else {
      return nil
    }

    // Step 2: Use Core Image for GPU-accelerated resizing
    let ciImage = CIImage(cgImage: cgImage)
    let context = CIContext(options: [.useSoftwareRenderer: false])  // Force GPU rendering

    // Create scale transform
    let scaleTransform = CGAffineTransform(
      scaleX: targetSize.width / ciImage.extent.width,
      y: targetSize.height / ciImage.extent.height
    )
    let scaledImage = ciImage.transformed(by: scaleTransform)

    // Render the transformed image
    guard let renderedImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
      return nil
    }

    // Step 3: Re-encode as WebP
    // For a single frame WebP
    return WebPEncoder.encode(renderedImage, quality: 90)
  }

  @objc public var someField = 123
}
