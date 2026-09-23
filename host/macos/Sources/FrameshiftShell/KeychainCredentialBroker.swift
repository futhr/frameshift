import Darwin
import Foundation

/// A private, authenticated one-request-per-connection signing endpoint for the bundled core.
public final class KeychainCredentialBroker: @unchecked Sendable {
  private static let maximumPacketBytes = 128 * 1024
  private let listener: Int32
  private let socketPath: String
  private let token: Data
  private let store = KeychainIdentityStore()
  private let lock = NSLock()
  private var stopped = false

  public static func start(socketPath: String, token: String) throws -> KeychainCredentialBroker {
    let broker = try KeychainCredentialBroker(socketPath: socketPath, token: token)
    Thread.detachNewThread { broker.acceptConnections() }
    return broker
  }

  private init(socketPath: String, token: String) throws {
    guard token.utf8.count == 64, !FileManager.default.fileExists(atPath: socketPath) else {
      throw CoreClientError.coreUnavailable
    }

    var address = sockaddr_un()
    let pathBytes = Array(socketPath.utf8) + [0]
    guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
      throw CoreClientError.coreUnavailable
    }
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    withUnsafeMutableBytes(of: &address.sun_path) { destination in
      destination.copyBytes(from: pathBytes)
    }

    let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else { throw CoreClientError.coreUnavailable }

    let bound = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard bound == 0 else {
      Darwin.close(descriptor)
      throw CoreClientError.coreUnavailable
    }
    guard Darwin.chmod(socketPath, 0o600) == 0, Darwin.listen(descriptor, 8) == 0 else {
      Darwin.close(descriptor)
      Darwin.unlink(socketPath)
      throw CoreClientError.coreUnavailable
    }

    listener = descriptor
    self.socketPath = socketPath
    self.token = Data(token.utf8)
  }

  public func stop() {
    lock.lock()
    defer { lock.unlock() }
    guard !stopped else { return }
    stopped = true
    _ = Darwin.shutdown(listener, SHUT_RDWR)
    _ = Darwin.close(listener)
    _ = Darwin.unlink(socketPath)
  }

  private func acceptConnections() {
    while true {
      let connection = Darwin.accept(listener, nil, nil)
      if connection < 0 { return }
      handle(connection)
      _ = Darwin.close(connection)
    }
  }

  private func handle(_ connection: Int32) {
    var timeout = timeval(tv_sec: 5, tv_usec: 0)
    let timeoutSize = socklen_t(MemoryLayout.size(ofValue: timeout))
    var noSignal: Int32 = 1
    guard setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO, &timeout, timeoutSize) == 0,
      setsockopt(connection, SOL_SOCKET, SO_SNDTIMEO, &timeout, timeoutSize) == 0,
      setsockopt(
        connection,
        SOL_SOCKET,
        SO_NOSIGPIPE,
        &noSignal,
        socklen_t(MemoryLayout.size(ofValue: noSignal))
      ) == 0
    else { return }

    do {
      let prefix = try readExactly(connection, count: 4)
      let length = prefix.reduce(0) { ($0 << 8) | Int($1) }
      guard length > 0, length <= Self.maximumPacketBytes else { return }
      let body = try readExactly(connection, count: length)
      let request = try JSONDecoder().decode(BrokerRequest.self, from: body)
      let response = process(request)
      let encoded = try JSONEncoder().encode(response)
      guard encoded.count <= Self.maximumPacketBytes else { return }
      var lengthPrefix = UInt32(encoded.count).bigEndian
      try withUnsafeBytes(of: &lengthPrefix) { try writeAll(connection, data: Data($0)) }
      try writeAll(connection, data: encoded)
    } catch {
      // Invalid or incomplete requests never expose Keychain or parser details.
    }
  }

  private func process(_ request: BrokerRequest) -> BrokerResponse {
    guard constantTimeEqual(Data(request.auth.utf8), token) else { return .failure }

    do {
      switch request.operation {
      case "resolve":
        let identity = try store.describe(reference: request.reference)
        return BrokerResponse(
          ok: true,
          certificate: identity.certificate.base64EncodedString(),
          algorithm: identity.algorithm,
          signature: nil
        )

      case "sign":
        guard let scheme = request.scheme, let encodedDigest = request.digest,
          let digest = Data(base64Encoded: encodedDigest)
        else { return .failure }
        let signature = try store.sign(reference: request.reference, scheme: scheme, digest: digest)
        return BrokerResponse(
          ok: true,
          certificate: nil,
          algorithm: nil,
          signature: signature.base64EncodedString()
        )

      default:
        return .failure
      }
    } catch {
      return .failure
    }
  }

  private func constantTimeEqual(_ left: Data, _ right: Data) -> Bool {
    guard left.count == right.count else { return false }
    return zip(left, right).reduce(UInt8.zero) { $0 | ($1.0 ^ $1.1) } == 0
  }

  private func readExactly(_ descriptor: Int32, count: Int) throws -> Data {
    var data = Data(count: count)
    var offset = 0
    while offset < count {
      let received = data.withUnsafeMutableBytes { buffer in
        Darwin.read(descriptor, buffer.baseAddress!.advanced(by: offset), count - offset)
      }
      guard received > 0 else { throw CoreClientError.coreUnavailable }
      offset += received
    }
    return data
  }

  private func writeAll(_ descriptor: Int32, data: Data) throws {
    var offset = 0
    while offset < data.count {
      let written = data.withUnsafeBytes { buffer in
        Darwin.write(descriptor, buffer.baseAddress!.advanced(by: offset), data.count - offset)
      }
      guard written > 0 else { throw CoreClientError.coreUnavailable }
      offset += written
    }
  }
}

private struct BrokerRequest: Decodable {
  let auth: String
  let operation: String
  let reference: String
  let scheme: String?
  let digest: String?
}

private struct BrokerResponse: Encodable {
  let ok: Bool
  let certificate: String?
  let algorithm: String?
  let signature: String?

  static let failure = BrokerResponse(ok: false, certificate: nil, algorithm: nil, signature: nil)
}
