import CoreGraphics
import Foundation
import FrameshiftShell
import ImageIO
import UniformTypeIdentifiers

private struct ProbeFailure: Error {}

@main
private struct FrameshiftIPCProbe {
  static func main() async throws {
    let client = LocalCoreClient()
    let initial = try await client.snapshot()
    guard initial.targets.isEmpty else { throw ProbeFailure() }

    let marker = "release-smoke-\(UUID().uuidString.lowercased())"
    let updated = try await client.send(
      CoreCommand(kind: .updateInstruction, instruction: marker)
    )
    guard updated.instruction == marker else { throw ProbeFailure() }

    let refreshed = try await client.snapshot()
    guard refreshed.instruction == marker else { throw ProbeFailure() }

    let fixtureDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "frameshift-ipc-probe-\(UUID().uuidString.lowercased())",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: fixtureDirectory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: fixtureDirectory) }
    let fixtureURL = fixtureDirectory.appendingPathComponent("installed-flow.png")
    try writeFixture(to: fixtureURL)

    let imported = try await client.send(
      CoreCommand(kind: .importFile, importPath: fixtureURL.path)
    )
    guard
      imported.items.contains(where: {
        $0.title == "installed-flow" && $0.digest.hasPrefix("sha256:")
      })
    else {
      throw ProbeFailure()
    }
    print("Frameshift Swift-to-Elixir IPC probe passed")
  }

  private static func writeFixture(to url: URL) throws {
    let pixels = Data([255, 0, 0, 255, 0, 255, 0, 255])
    let info = CGBitmapInfo(
      rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.last.rawValue
    )
    guard let provider = CGDataProvider(data: pixels as CFData),
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let image = CGImage(
        width: 2,
        height: 1,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: 8,
        space: colorSpace,
        bitmapInfo: info,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      ),
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    else {
      throw ProbeFailure()
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw ProbeFailure() }
  }
}
