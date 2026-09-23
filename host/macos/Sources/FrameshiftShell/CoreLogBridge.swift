import Foundation
import OSLog

final class CoreLogBridge: @unchecked Sendable {
  private static let logger = Logger(subsystem: "io.frameshift.app", category: "core")
  private static let maximumRecordBytes = 8_192
  private static let maximumBatchRecords = 256
  private let lock = NSLock()
  private let emissionQueue = DispatchQueue(label: "io.frameshift.app.core-log-bridge")
  private let output: FileHandle
  private let error: FileHandle
  private var outputBuffer = Data()
  private var errorBuffer = Data()
  private var discardingOutputLine = false
  private var discardingErrorLine = false
  private var queuedRecords = BoundedRecordQueue()
  private var drainScheduled = false
  private var stopped = false
  private var droppedRecords: UInt64 = 0

  struct Record: Equatable, Sendable {
    let event: String
    let level: String
    let outcome: String
    let correlationID: String
    let attemptID: String
  }

  struct BoundedRecordQueue {
    private static let capacity = 512
    private var records: [Data] = []

    var count: Int { records.count }
    var isEmpty: Bool { records.isEmpty }

    mutating func append(_ incoming: [Data]) -> UInt64 {
      let available = max(0, Self.capacity - records.count)
      records.append(contentsOf: incoming.prefix(available))
      return UInt64(max(0, incoming.count - available))
    }

    mutating func pop() -> Data? {
      guard !records.isEmpty else { return nil }
      return records.removeFirst()
    }

    mutating func clear() -> UInt64 {
      let discarded = UInt64(records.count)
      records.removeAll()
      return discarded
    }
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
    stopped = true
    droppedRecords += queuedRecords.clear()
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

    enqueue(records)
  }

  private func enqueue(_ records: [Data]) {
    lock.lock()
    if stopped {
      droppedRecords += UInt64(records.count)
      lock.unlock()
      return
    }

    droppedRecords += queuedRecords.append(records)
    let schedule = !drainScheduled && !queuedRecords.isEmpty
    if schedule { drainScheduled = true }
    lock.unlock()

    if schedule {
      emissionQueue.async { [weak self] in self?.drain() }
    }
  }

  private func drain() {
    while true {
      lock.lock()
      guard !stopped, !queuedRecords.isEmpty else {
        drainScheduled = false
        lock.unlock()
        return
      }
      guard let record = queuedRecords.pop() else {
        drainScheduled = false
        lock.unlock()
        return
      }
      lock.unlock()

      if !emit(record) {
        lock.lock()
        droppedRecords += 1
        lock.unlock()
      }
    }
  }

  private func emit(_ record: Data) -> Bool {
    guard let fields = Self.parse(record) else { return false }
    Self.log(fields)
    return true
  }

  private static func log(_ fields: Record) {
    switch fields.level {
    case "error", "critical", "alert", "emergency":
      Self.logger.error(
        "\(fields.event, privacy: .public) outcome=\(fields.outcome, privacy: .public) correlation=\(fields.correlationID, privacy: .public) attempt=\(fields.attemptID, privacy: .public)"
      )
    case "warning":
      Self.logger.warning(
        "\(fields.event, privacy: .public) outcome=\(fields.outcome, privacy: .public) correlation=\(fields.correlationID, privacy: .public) attempt=\(fields.attemptID, privacy: .public)"
      )
    case "info", "notice":
      Self.logger.info(
        "\(fields.event, privacy: .public) outcome=\(fields.outcome, privacy: .public) correlation=\(fields.correlationID, privacy: .public) attempt=\(fields.attemptID, privacy: .public)"
      )
    default:
      Self.logger.debug(
        "\(fields.event, privacy: .public) outcome=\(fields.outcome, privacy: .public) correlation=\(fields.correlationID, privacy: .public) attempt=\(fields.attemptID, privacy: .public)"
      )
    }

  }

  static func parse(_ record: Data) -> Record? {
    let prefix = Data("FSLOG|".utf8)
    guard record.starts(with: prefix),
      let parsed = try? JSONSerialization.jsonObject(with: record.dropFirst(prefix.count)),
      let fields = parsed as? [String: Any],
      let event = fields["event"] as? String,
      ["command_completed", "delivery_attempt", "ipc_failure", "runtime"].contains(event),
      let level = fields["level"] as? String,
      ["debug", "info", "notice", "warning", "error", "critical", "alert", "emergency"].contains(
        level)
    else { return nil }

    let outcome = fields["outcome"] as? String ?? ""
    let correlationID = fields["correlationId"] as? String ?? ""
    let attemptID = fields["attemptId"] as? String ?? ""
    guard
      ["", "succeeded", "failed", "replay", "unknown", "displayed", "pending", "other"].contains(
        outcome),
      correlationID.isEmpty || validCorrelationID(correlationID),
      attemptID.isEmpty || validAttemptID(attemptID)
    else { return nil }

    return Record(
      event: event, level: level, outcome: outcome, correlationID: correlationID,
      attemptID: attemptID)
  }

  private static func validCorrelationID(_ value: String) -> Bool {
    guard value.utf8.count == 71, value.hasPrefix("sha256:") else { return false }
    return value.dropFirst(7).utf8.allSatisfy { byte in
      (48...57).contains(byte) || (97...102).contains(byte)
    }
  }

  private static func validAttemptID(_ value: String) -> Bool {
    guard value.utf8.count == 32 else { return false }
    return value.utf8.allSatisfy { byte in
      (48...57).contains(byte) || (97...102).contains(byte)
    }
  }
}
