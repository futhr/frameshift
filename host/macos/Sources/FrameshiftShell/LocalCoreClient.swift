import CryptoKit
import Darwin
import Foundation

public actor LocalCoreClient: CoreClient {
  private static let maximumRequestBytes = 64 * 1024
  private static let maximumResponseBytes = 1024 * 1024
  private let socketPath: String
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  public init(socketPath: String = LocalCoreClient.defaultSocketPath()) {
    self.socketPath = socketPath
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  }

  public func snapshot() async throws -> CoreSnapshot {
    try await exchange(operation: "snapshot")
  }

  public func send(_ command: CoreCommand) async throws -> CoreSnapshot {
    let prepared = try prepare(command)
    defer { prepared.decodedImport?.removeWorkDirectory() }
    return try await exchange(operation: "command", command: prepared.command)
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

  public static func shutdownBundledCore() async {
    await BundledCore.shared.shutdown()
  }

  private func prepare(_ command: CoreCommand) throws -> PreparedCommand {
    guard command.kind == .importFile else {
      return PreparedCommand(command: command, decodedImport: nil)
    }
    guard let path = command.importPath else { throw CoreClientError.invalidCommand }
    let decoded = try AppleImageDecoder.decode(URL(fileURLWithPath: path))
    return PreparedCommand(command: command.withDecodedImport(decoded), decodedImport: decoded)
  }

  private func exchange(operation: String, command: CoreCommand? = nil) async throws -> CoreSnapshot
  {
    try await BundledCore.shared.ensureRunning(socketPath: socketPath)

    do {
      return try await exchangeOnce(operation: operation, command: command)
    } catch CoreClientError.coreUnavailable {
      try await BundledCore.shared.ensureRunning(socketPath: socketPath, force: true)
      return try await exchangeOnce(operation: operation, command: command)
    }
  }

  private func exchangeOnce(operation: String, command: CoreCommand?) async throws -> CoreSnapshot {
    let auth = try await BundledCore.shared.sessionToken(socketPath: socketPath)
    let request = WireRequest(auth: auth, operation: operation, command: command)
    let payload = try encoder.encode(request)
    guard payload.count <= Self.maximumRequestBytes else {
      throw CoreClientError.invalidCommand
    }

    let responseData = try await send(payload)

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

  private func send(_ payload: Data) async throws -> Data {
    let path = socketPath
    return try await Task.detached(priority: .userInitiated) {
      try UnixSocket.exchange(
        path: path,
        payload: payload,
        maximumResponseBytes: Self.maximumResponseBytes
      )
    }.value
  }

  private static func clientError(for code: String?) -> CoreClientError {
    switch code {
    case "import_too_large": .importTooLarge
    case "import_unreadable", "import_not_regular", "import_changed",
      "invalid_canonical_image", "canonical_digest_mismatch":
      .importUnreadable
    case "unsupported_media_type", "media_type_mismatch": .unsupportedMedia
    case "item_not_found": .itemNotFound
    case "target_not_found": .targetNotFound
    case "invalid_command", "invalid_dimensions", "invalid_orientation", "invalid_color_profile":
      .invalidCommand
    default: .protocolFailure
    }
  }
}

private struct PreparedCommand {
  let command: CoreCommand
  let decodedImport: DecodedImport?
}

private actor BundledCore {
  static let shared = BundledCore()

  private var process: Process?
  private var token: String?

  func ensureRunning(socketPath: String, force: Bool = false) async throws {
    if !force, FileManager.default.fileExists(atPath: socketPath) {
      try loadExternalTokenIfNeeded()
      return
    }

    if process?.isRunning != true {
      let launched = try launch(socketPath: socketPath)
      process = launched.process
      token = launched.token
    }

    for _ in 0..<100 {
      if FileManager.default.fileExists(atPath: socketPath) { return }
      if process?.isRunning == false { throw CoreClientError.coreUnavailable }
      try await Task.sleep(for: .milliseconds(50))
    }

    throw CoreClientError.coreUnavailable
  }

  func sessionToken(socketPath: String) async throws -> String {
    try await ensureRunning(socketPath: socketPath)
    guard let token else { throw CoreClientError.coreUnavailable }
    return token
  }

  func shutdown() {
    if let process, process.isRunning {
      process.terminate()
    }
    self.process = nil
    token = nil
  }

  private func launch(socketPath: String) throws -> (process: Process, token: String) {
    guard let resources = Bundle.main.resourceURL else {
      throw CoreClientError.coreUnavailable
    }

    let coreExecutable = resources.appendingPathComponent(
      "core/bin/frameshift_core",
      isDirectory: false
    )
    let renderer = resources.appendingPathComponent(
      "bin/frameshift-raster",
      isDirectory: false
    )
    let launcher = resources.appendingPathComponent(
      "bin/launch-bundled-core",
      isDirectory: false
    )
    guard FileManager.default.isExecutableFile(atPath: coreExecutable.path),
      FileManager.default.isExecutableFile(atPath: renderer.path),
      FileManager.default.isExecutableFile(atPath: launcher.path)
    else {
      throw CoreClientError.coreUnavailable
    }

    let socketURL = URL(fileURLWithPath: socketPath)
    let dataDirectory = socketURL.deletingLastPathComponent()
    do {
      try FileManager.default.createDirectory(
        at: dataDirectory,
        withIntermediateDirectories: true
      )
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: dataDirectory.path
      )
    } catch {
      throw CoreClientError.coreUnavailable
    }

    let configuredToken = ProcessInfo.processInfo.environment["FRAMESHIFT_IPC_TOKEN"]
    let token = configuredToken.flatMap { Self.validToken($0) ? $0 : nil } ?? Self.makeToken()
    let tokenURL = dataDirectory.appendingPathComponent(
      "ipc-bootstrap-\(UUID().uuidString.lowercased())",
      isDirectory: false
    )
    do {
      try Data(token.utf8).write(to: tokenURL, options: .withoutOverwriting)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: tokenURL.path
      )
    } catch {
      try? FileManager.default.removeItem(at: tokenURL)
      throw CoreClientError.coreUnavailable
    }

    var environment = ProcessInfo.processInfo.environment
    environment["FRAMESHIFT_DATA_DIR"] =
      environment["FRAMESHIFT_DATA_DIR"] ?? dataDirectory.path
    environment["FRAMESHIFT_SOCKET_PATH"] = socketPath
    environment["FRAMESHIFT_RENDERER_PATH"] = renderer.path
    environment["ERL_CRASH_DUMP"] = dataDirectory.appendingPathComponent("erl_crash.dump").path
    environment["ERL_CRASH_DUMP_SECONDS"] = "0"
    environment["FRAMESHIFT_CORE_PID_FILE"] =
      dataDirectory.appendingPathComponent("core.pid").path
    environment["FRAMESHIFT_IPC_TOKEN_FILE"] = tokenURL.path
    environment["RELEASE_DISTRIBUTION"] = "none"

    let child = Process()
    child.executableURL = launcher
    child.arguments = [String(getpid()), coreExecutable.path]
    child.environment = environment
    child.standardOutput = FileHandle.nullDevice
    child.standardError = FileHandle.nullDevice

    do {
      try child.run()
      return (child, token)
    } catch {
      try? FileManager.default.removeItem(at: tokenURL)
      throw CoreClientError.coreUnavailable
    }
  }

  private func loadExternalTokenIfNeeded() throws {
    if token != nil { return }
    guard let configured = ProcessInfo.processInfo.environment["FRAMESHIFT_IPC_TOKEN"],
      Self.validToken(configured)
    else {
      throw CoreClientError.coreUnavailable
    }
    token = configured
  }

  private static func makeToken() -> String {
    SymmetricKey(size: .bits256).withUnsafeBytes { bytes in
      bytes.map { String(format: "%02x", $0) }.joined()
    }
  }

  private static func validToken(_ candidate: String) -> Bool {
    candidate.utf8.count == 64
      && candidate.utf8.allSatisfy { byte in
        (48...57).contains(byte) || (97...102).contains(byte)
      }
  }
}

private struct WireRequest: Encodable, Sendable {
  let version: Int
  let requestID: String
  let auth: String
  let operation: String
  let command: CoreCommand?

  private enum CodingKeys: String, CodingKey {
    case version
    case requestID = "requestId"
    case auth
    case operation
    case command
  }

  init(auth: String, operation: String, command: CoreCommand? = nil) {
    version = 1
    requestID = UUID().uuidString.lowercased()
    self.auth = auth
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
