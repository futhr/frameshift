import CoreImage
import Foundation
import FrameshiftShell
import ImageIO
import Testing
import UniformTypeIdentifiers

@Suite("Physical pairing QR image")
struct PairingQRReaderTests {
  @Test("A local still image yields one exact bounded bootstrap payload")
  func readsQRImage() throws {
    let payload = """
      {"version":1,"deviceId":"frame-000000000001","serverSpki":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","secret":"AQIDBAECAwQBAgMEAQIDBA"}
      """
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("physical-label.png")
    try writeQR(payload, to: url)

    #expect(try PairingQRReader.read(url) == payload)
  }

  @Test("A non-image is refused before Vision runs")
  func refusesNonImage() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data("private record".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(throws: PairingQRReaderError.self) { try PairingQRReader.read(url) }
  }

  private func writeQR(_ payload: String, to url: URL) throws {
    let filter = try #require(CIFilter(name: "CIQRCodeGenerator"))
    filter.setValue(Data(payload.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    let source = try #require(filter.outputImage)
    let enlarged = source.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
    let image = try #require(CIContext().createCGImage(enlarged, from: enlarged.extent))
    let destination = try #require(
      CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    )
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
  }
}
