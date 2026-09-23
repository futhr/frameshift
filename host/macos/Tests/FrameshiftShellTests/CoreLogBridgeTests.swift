import Foundation
import Testing

@testable import FrameshiftShell

@Suite("Core log bridge")
struct CoreLogBridgeTests {
  @Test("accepts only bounded operational fields")
  func structuredRecord() {
    let digest = "sha256:" + String(repeating: "a", count: 64)
    let record = Data(
      "FSLOG|{\"event\":\"command_completed\",\"level\":\"info\",\"outcome\":\"succeeded\",\"correlationId\":\"\(digest)\"}"
        .utf8
    )

    #expect(
      CoreLogBridge.parse(record)
        == CoreLogBridge.Record(
          event: "command_completed", level: "info", outcome: "succeeded",
          correlationID: digest
        )
    )
  }

  @Test("rejects untrusted public log fields")
  func rejectsSecretFields() {
    let invalid = [
      "FSLOG|{\"event\":\"other\",\"level\":\"info\"}",
      "FSLOG|{\"event\":\"runtime\",\"level\":\"secret\"}",
      "FSLOG|{\"event\":\"runtime\",\"level\":\"info\",\"outcome\":\"token=secret\"}",
      "FSLOG|{\"event\":\"runtime\",\"level\":\"info\",\"correlationId\":\"raw-id\"}",
      "private exception text",
    ]

    for record in invalid {
      #expect(CoreLogBridge.parse(Data(record.utf8)) == nil)
    }
  }
}
