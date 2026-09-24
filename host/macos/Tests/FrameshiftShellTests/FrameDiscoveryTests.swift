import Foundation
import FrameshiftShell
import Testing

@Suite("Frame Bonjour introduction")
struct FrameDiscoveryTests {
  private let deviceID = "paper-frame-00001"

  private func fields(_ changes: [String: String] = [:]) -> [String: Data] {
    var values = [
      "v": "0",
      "id": deviceID,
      "td": "/.well-known/wot",
      "scheme": "https",
      "pair": "1",
    ]
    values.merge(changes) { _, new in new }
    return values.mapValues { Data($0.utf8) }
  }

  private func txt(_ entries: [String]) -> Data {
    var bytes = Data()
    for entry in entries {
      bytes.append(UInt8(entry.utf8.count))
      bytes.append(contentsOf: entry.utf8)
    }
    return bytes
  }

  @Test("A bounded advertisement is only a discovery hint")
  func parsesReferenceIntroduction() throws {
    let hint = try #require(FrameIntroduction.parse(fields()))
    #expect(hint.deviceID == deviceID)
    #expect(hint.thingPath == "/.well-known/wot")
    #expect(hint.pairMode)

    let closed = try #require(FrameIntroduction.parse(fields(["pair": "0"])))
    #expect(!closed.pairMode)

    let raw = txt([
      "v=0", "id=\(deviceID)", "td=/.well-known/wot", "scheme=https", "pair=1",
    ])
    #expect(FrameIntroduction.parseTXT(raw)?.deviceID == deviceID)
  }

  @Test("Untrusted routes, identifiers, and metadata are refused")
  func refusesUnsafeIntroductions() {
    let invalid = [
      ["v": "1"],
      ["id": "short"],
      ["id": "bad/id-and-untrusted-host"],
      ["td": "https://other.example/.well-known/wot"],
      ["td": "/private/thing"],
      ["scheme": "http"],
      ["pair": "true"],
      ["owner": "private"],
    ]
    for change in invalid {
      #expect(FrameIntroduction.parse(fields(change)) == nil)
    }

    var missing = fields()
    missing.removeValue(forKey: "id")
    #expect(FrameIntroduction.parse(missing) == nil)

    var nonUTF8 = fields()
    nonUTF8["id"] = Data([0xFF, 0xFE])
    #expect(FrameIntroduction.parse(nonUTF8) == nil)

    var oversized = fields()
    oversized["id"] = Data(String(repeating: "a", count: 513).utf8)
    #expect(FrameIntroduction.parse(oversized) == nil)

    let duplicate = txt([
      "v=0", "id=\(deviceID)", "id=another-frame-0001", "td=/.well-known/wot", "scheme=https",
    ])
    #expect(FrameIntroduction.parseTXT(duplicate) == nil)
    #expect(FrameIntroduction.parseTXT(Data([30, 0x76, 0x3D, 0x30])) == nil)
  }
}
