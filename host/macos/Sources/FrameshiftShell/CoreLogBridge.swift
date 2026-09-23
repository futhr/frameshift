import Foundation
import OSLog

final class CoreLogBridge: @unchecked Sendable {
  private static let logger = Logger(subsystem: "io.frameshift.app", category: "core")
  private static let maximumRecordBytes = 8_192
  private static let maximumBatchRecords = 256
  private let lock = NSLock()
  private let output: FileHandle
  private let error: FileHandle
  private var outputBuffer = Data()
  private var errorBuffer = Data()
  private var discardingOutputLine = false
  private var discardingErrorLine = false
  private var droppedRecords: UInt64 = 0

  struct Record: Equatable {
    let event: String
    let level: String
    let outcome: String
    let correlationID: String
  }

  init(output: Pipe, error: Pipe) {
    self.output = output.fileHandleForReading
    self.error = error.fileHandleForReading

    self.output.readabilityHandler = { [weak self] handle in
      self?.read(handle, isError: false)
    }

    self.error.readabilityHandler = { [weak self] handle in
      self?.read(handle, isError: true)
    }
  }

  func stop() {
    output.readabilityHandler = nil
    error.readabilityHandler = nil
    lock.lock()
    try? output.close()
    try? error.close()
    outputBuffer.removeAll()
    errorBuffer.removeAll()
    discardingOutputLine = false
    discardingErrorLine = false
    let dropped = droppedRecords
    lock.unlock()

    if dropped > 0 {
      Self.logger.warning("core log bridge dropped \(dropped) records")
    }
  }

  private func read(_ handle: FileHandle, isError: Bool) {
    let chunk = handle.availableData
    guard !chunk.isEmpty else {
      handle.readabilityHandler = nil
      return
    }

    lock.lock()
    var buffer = isError ? errorBuffer : outputBuffer
    var discardingLine = isError ? discardingErrorLine : discardingOutputLine
    var records: [Data] = []

    for byte in chunk {
      if byte == 10 {
        if discardingLine || records.count >= Self.maximumBatchRecords {
          droppedRecords += 1
        } else {
          records.append(buffer)
        }
        buffer.removeAll(keepingCapacity: true)
        discardingLine = false
      } else if !discardingLine {
        if buffer.count < Self.maximumRecordBytes {
          buffer.append(byte)
        } else {
          buffer.removeAll(keepingCapacity: true)
          discardingLine = true
        }
      }
    }

    if isError {
      errorBuffer = buffer
      discardingErrorLine = discardingLine
    } else {
      outputBuffer = buffer
      discardingOutputLine = discardingLine
    }
    lock.unlock()

    for record in records where !emit(record) {
      lock.lock()
      droppedRecords += 1
      lock.unlock()
    }
  }

  private func emit(_ record: Data) -> Bool {
    guard let fields = Self.parse(record) else { return false }

    switch fields.level {
    case "error", "critical", "alert", "emergency":
      Self.logger.error(
        "\(fields.event, privacy: .public) outcome=\(fields.outcome, privacy: .public) correlation=\(fields.correlationID, privacy: .public)"
      )
    case "warning":
      Self.logger.warning(
        "\(fields.event, privacy: .public) outcome=\(fields.outcome, privacy: .public) correlation=\(fields.correlationID, privacy: .public)"
      )
    case "info", "notice":
      Self.logger.info(
        "\(fields.event, privacy: .public) outcome=\(fields.outcome, privacy: .public) correlation=\(fields.correlationID, privacy: .public)"
      )
    default:
      Self.logger.debug(
        "\(fields.event, privacy: .public) outcome=\(fields.outcome, privacy: .public) correlation=\(fields.correlationID, privacy: .public)"
      )
    }

    return true
  }

  static func parse(_ record: Data) -> Record? {
    let prefix = Data("FSLOG|".utf8)
    guard record.starts(with: prefix),
      let parsed = try? JSONSerialization.jsonObject(with: record.dropFirst(prefix.count)),
      let fields = parsed as? [String: Any],
      let event = fields["event"] as? String,
      ["command_completed", "ipc_failure", "runtime"].contains(event),
      let level = fields["level"] as? String,
      ["debug", "info", "notice", "warning", "error", "critical", "alert", "emergency"].contains(
        level)
    else { return nil }

    let outcome = fields["outcome"] as? String ?? ""
    let correlationID = fields["correlationId"] as? String ?? ""
    guard ["", "succeeded", "failed", "replay", "unknown", "other"].contains(outcome),
      correlationID.isEmpty || validCorrelationID(correlationID)
    else { return nil }

    return Record(event: event, level: level, outcome: outcome, correlationID: correlationID)
  }

  private static func validCorrelationID(_ value: String) -> Bool {
    guard value.utf8.count == 71, value.hasPrefix("sha256:") else { return false }
    return value.dropFirst(7).utf8.allSatisfy { byte in
      (48...57).contains(byte) || (97...102).contains(byte)
    }
  }
}
