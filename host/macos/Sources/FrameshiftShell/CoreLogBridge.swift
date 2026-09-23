import Foundation
import OSLog

final class CoreLogBridge: @unchecked Sendable {
  private static let logger = Logger(subsystem: "io.frameshift.app", category: "core")
  private static let maximumRecordBytes = 8_192
  private let lock = NSLock()
  private let output: FileHandle
  private let error: FileHandle
  private var outputBuffer = Data()
  private var errorBuffer = Data()
  private var droppedRecords: UInt64 = 0

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
    buffer.append(chunk)
    var records: [Data] = []

    while let newline = buffer.firstIndex(of: 10) {
      let record = Data(buffer[..<newline])
      buffer.removeSubrange(...newline)
      if record.count <= Self.maximumRecordBytes {
        records.append(record)
      } else {
        droppedRecords += 1
      }
    }

    if buffer.count > Self.maximumRecordBytes {
      buffer.removeAll()
      droppedRecords += 1
    }
    if isError { errorBuffer = buffer } else { outputBuffer = buffer }
    lock.unlock()

    for record in records where !emit(record) {
      lock.lock()
      droppedRecords += 1
      lock.unlock()
    }
  }

  private func emit(_ record: Data) -> Bool {
    let prefix = Data("FSLOG|".utf8)
    guard record.starts(with: prefix),
      let parsed = try? JSONSerialization.jsonObject(with: record.dropFirst(prefix.count)),
      let fields = parsed as? [String: Any],
      let event = fields["event"] as? String,
      ["command_completed", "ipc_failure", "runtime"].contains(event),
      let level = fields["level"] as? String
    else { return false }

    let outcome = fields["outcome"] as? String ?? ""
    let correlationID = fields["correlationId"] as? String ?? ""

    switch level {
    case "error", "critical", "alert", "emergency":
      Self.logger.error(
        "\(event, privacy: .public) outcome=\(outcome, privacy: .public) correlation=\(correlationID, privacy: .public)"
      )
    case "warning":
      Self.logger.warning(
        "\(event, privacy: .public) outcome=\(outcome, privacy: .public) correlation=\(correlationID, privacy: .public)"
      )
    case "info", "notice":
      Self.logger.info(
        "\(event, privacy: .public) outcome=\(outcome, privacy: .public) correlation=\(correlationID, privacy: .public)"
      )
    default:
      Self.logger.debug(
        "\(event, privacy: .public) outcome=\(outcome, privacy: .public) correlation=\(correlationID, privacy: .public)"
      )
    }

    return true
  }
}
