import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

public actor LocalCoreClient: CoreClient {
  private static let maximumRequestBytes = 64 * 1024
  private static let maximumResponseBytes = 1024 * 1024
  private static let maximumImportBytes = 128 * 1024 * 1024

  private let socketPath: String
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  public init(socketPath: String = LocalCoreClient.defaultSocketPath()) {
    self.socketPath = socketPath
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  }

  public func snapshot() async throws -> CoreSnapshot {
    try await exchange(WireRequest(operation: "snapshot"))
  }

  public func send(_ command: CoreCommand) async throws -> CoreSnapshot {
    let prepared = try prepare(command)
    return try await exchange(WireRequest(operation: "command", command: prepared))
  }

  public static func defaultSocketPath() -> String {
    if let configured = ProcessInfo.processInfo.environment["FRAMESHIFT_SOCKET_PATH"],
      !configured.isEmpty
    {
      return URL(fileURLWithPath: configured).standardizedFileURL.path
    }

    let applicationSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0]

    return
      applicationSupport
      .appendingPathComponent("Frameshift", isDirectory: true)
      .appendingPathComponent("core.sock", isDirectory: false)
      .path
  }

  private func prepare(_ command: CoreCommand) throws -> CoreCommand {
    guard command.kind == .importFile else { return command }
    guard let path = command.importPath else { throw CoreClientError.invalidCommand }
    let metadata = try Self.inspectImage(at: URL(fileURLWithPath: path))
    return command.withImportMetadata(metadata)
  }

  private func exchange(_ request: WireRequest) async throws -> CoreSnapshot {
    let payload = try encoder.encode(request)
    guard payload.count <= Self.maximumRequestBytes else {
      throw CoreClientError.invalidCommand
    }

    let path = socketPath
    let responseData = try await Task.detached(priority: .userInitiated) {
      try UnixSocket.exchange(
        path: path,
        payload: payload,
        maximumResponseBytes: Self.maximumResponseBytes
      )
    }.value

    let response: WireResponse
    do {
      response = try decoder.decode(WireResponse.self, from: responseData)
    } catch {
      throw CoreClientError.protocolFailure
    }

    guard response.version == 1, response.requestID == request.requestID else {
      throw CoreClientError.protocolFailure
    }

    if response.ok, let snapshot = response.snapshot {
      return snapshot
    }

    throw Self.clientError(for: response.error?.code)
  }

  private static func inspectImage(at url: URL) throws -> ImportMetadata {
    let values: URLResourceValues
    do {
      values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    } catch {
      throw CoreClientError.importUnreadable
    }

    guard values.isRegularFile == true, let size = values.fileSize else {
      throw CoreClientError.importUnreadable
    }
    guard size > 0, size <= maximumImportBytes else {
      throw CoreClientError.importTooLarge
    }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      CGImageSourceGetCount(source) > 0,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
      let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
      width > 0,
      height > 0,
      let typeIdentifier = CGImageSourceGetType(source),
      let mediaType = UTType(typeIdentifier as String)?.preferredMIMEType
    else {
      throw CoreClientError.importUnreadable
    }

    let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
    let colorProfile = properties[kCGImagePropertyProfileName] as? String

    return ImportMetadata(
      width: width,
      height: height,
      mediaType: mediaType,
      orientation: orientation,
      colorProfile: colorProfile
    )
  }

  private static func clientError(for code: String?) -> CoreClientError {
    switch code {
    case "import_too_large": .importTooLarge
    case "import_unreadable", "import_not_regular", "import_changed": .importUnreadable
    case "unsupported_media_type", "media_type_mismatch": .unsupportedMedia
    case "item_not_found": .itemNotFound
    case "target_not_found": .targetNotFound
    case "invalid_command", "invalid_dimensions", "invalid_orientation", "invalid_color_profile":
      .invalidCommand
    default: .protocolFailure
    }
  }
}

private struct WireRequest: Encodable, Sendable {
  let version: Int
  let requestID: String
  let operation: String
  let command: CoreCommand?

  private enum CodingKeys: String, CodingKey {
    case version
    case requestID = "requestId"
    case operation
    case command
  }

  init(operation: String, command: CoreCommand? = nil) {
    version = 1
    requestID = UUID().uuidString.lowercased()
    self.operation = operation
    self.command = command
  }
}

private struct WireResponse: Decodable, Sendable {
  let version: Int
  let requestID: String?
  let ok: Bool
  let snapshot: CoreSnapshot?
  let error: WireError?

  private enum CodingKeys: String, CodingKey {
    case version
    case requestID = "requestId"
    case ok
    case snapshot
    case error
  }
}

private struct WireError: Decodable, Sendable {
  let code: String
}

private enum UnixSocket {
  private static let timeoutSeconds = 5

  static func exchange(path: String, payload: Data, maximumResponseBytes: Int) throws -> Data {
    let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else { throw CoreClientError.coreUnavailable }
    defer { Darwin.close(descriptor) }

    try configure(descriptor)
    try connect(descriptor, path: path)

    var size = UInt32(payload.count).bigEndian
    var frame = Data(bytes: &size, count: MemoryLayout<UInt32>.size)
    frame.append(payload)
    try writeAll(descriptor, data: frame)

    let prefix = try readExactly(descriptor, count: 4)
    let responseLength = prefix.reduce(0) { ($0 << 8) | Int($1) }
    guard responseLength > 0, responseLength <= maximumResponseBytes else {
      throw CoreClientError.protocolFailure
    }

    return try readExactly(descriptor, count: responseLength)
  }

  private static func configure(_ descriptor: Int32) throws {
    guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else {
      throw CoreClientError.coreUnavailable
    }

    var noSignal: Int32 = 1
    guard
      setsockopt(
        descriptor,
        SOL_SOCKET,
        SO_NOSIGPIPE,
        &noSignal,
        socklen_t(MemoryLayout.size(ofValue: noSignal))
      ) == 0
    else {
      throw CoreClientError.coreUnavailable
    }

    var timeout = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
    let timeoutSize = socklen_t(MemoryLayout.size(ofValue: timeout))
    guard setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, timeoutSize) == 0,
      setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, timeoutSize) == 0
    else {
      throw CoreClientError.coreUnavailable
    }
  }

  private static func connect(_ descriptor: Int32, path: String) throws {
    let pathBytes = Array(path.utf8) + [0]
    var address = sockaddr_un()
    guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
      throw CoreClientError.coreUnavailable
    }

    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    withUnsafeMutableBytes(of: &address.sun_path) { destination in
      destination.copyBytes(from: pathBytes)
    }

    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
        Darwin.connect(
          descriptor,
          socketAddress,
          socklen_t(MemoryLayout<sockaddr_un>.size)
        )
      }
    }

    guard result == 0 else { throw CoreClientError.coreUnavailable }
  }

  private static func writeAll(_ descriptor: Int32, data: Data) throws {
    try data.withUnsafeBytes { bytes in
      guard let baseAddress = bytes.baseAddress else { throw CoreClientError.protocolFailure }
      var written = 0

      while written < data.count {
        let count = Darwin.write(
          descriptor, baseAddress.advanced(by: written), data.count - written)
        if count > 0 {
          written += count
        } else if count < 0, errno == EINTR {
          continue
        } else {
          throw CoreClientError.coreUnavailable
        }
      }
    }
  }

  private static func readExactly(_ descriptor: Int32, count: Int) throws -> Data {
    var data = Data(count: count)
    var received = 0

    try data.withUnsafeMutableBytes { bytes in
      guard let baseAddress = bytes.baseAddress else { throw CoreClientError.protocolFailure }

      while received < count {
        let result = Darwin.read(descriptor, baseAddress.advanced(by: received), count - received)
        if result > 0 {
          received += result
        } else if result < 0, errno == EINTR {
          continue
        } else {
          throw CoreClientError.coreUnavailable
        }
      }
    }

    return data
  }
}
