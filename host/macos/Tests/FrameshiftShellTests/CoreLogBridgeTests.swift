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
          correlationID: digest, attemptID: ""
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
      "FSLOG|{\"event\":\"delivery_attempt\",\"level\":\"info\",\"attemptId\":\"raw-id\"}",
      "private exception text",
    ]

    for record in invalid {
      #expect(CoreLogBridge.parse(Data(record.utf8)) == nil)
    }
  }

  @Test("accepts a random attempt ID for a delivery event")
  func deliveryAttempt() {
    let attemptID = String(repeating: "b", count: 32)
    let record = Data(
      "FSLOG|{\"event\":\"delivery_attempt\",\"level\":\"info\",\"outcome\":\"pending\",\"attemptId\":\"\(attemptID)\"}"
        .utf8
    )

    #expect(CoreLogBridge.parse(record)?.attemptID == attemptID)
  }

  @Test("core log queue bounds a slow sink and accounts for dropped records")
  func boundedEmissionQueue() {
    var queue = CoreLogBridge.BoundedRecordQueue()
    let record = Data("FSLOG|{\"event\":\"runtime\",\"level\":\"info\"}".utf8)
    #expect(queue.append(Array(repeating: record, count: 513)) == 1)
    #expect(queue.count == 512)
    #expect(queue.pop() == record)
    #expect(queue.append([record]) == 0)
    #expect(queue.clear() == 512)
    #expect(queue.isEmpty)
  }
}
