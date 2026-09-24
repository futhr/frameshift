import CoreGraphics
import Foundation
import ImageIO
import Vision

public enum PairingQRReaderError: Error, Sendable {
  case invalidImage
  case missingOrAmbiguousCode
  case invalidPayload
}

/// Reads one bounded QR payload without retaining the image or sending it to a provider.
public enum PairingQRReader {
  private static let maximumFileBytes = 16 * 1024 * 1024
  private static let maximumDimension = 8_192
  private static let maximumPayloadBytes = 2_048

  public static func read(_ url: URL) throws -> String {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
      values.isRegularFile == true,
      let size = values.fileSize, size > 0, size <= maximumFileBytes,
      let source = CGImageSourceCreateWithURL(
        url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
      CGImageSourceGetCount(source) == 1,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
      let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
      width > 0, height > 0, width <= maximumDimension, height <= maximumDimension,
      width * height <= 16_777_011
    else { throw PairingQRReaderError.invalidImage }

    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 2_048,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
    else { throw PairingQRReaderError.invalidImage }

    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]
    do {
      try VNImageRequestHandler(cgImage: image).perform([request])
    } catch {
      throw PairingQRReaderError.invalidImage
    }

    guard let observations = request.results, observations.count == 1,
      let payload = observations[0].payloadStringValue
    else { throw PairingQRReaderError.missingOrAmbiguousCode }
    guard (1...maximumPayloadBytes).contains(payload.utf8.count) else {
      throw PairingQRReaderError.invalidPayload
    }
    return payload
  }
}
