import Foundation
import Network

public enum FrameServiceResolutionError: Error, Sendable {
  case invalidService
  case unavailable
}

/// Resolves only a selected local Bonjour frame introduction to an HTTPS origin.
@MainActor
public final class FrameServiceResolver: NSObject, NetServiceDelegate {
  private var service: NetService?
  private var continuation: CheckedContinuation<String, Error>?

  public func resolve(_ endpoint: NWEndpoint) async throws -> String {
    guard continuation == nil,
      case .service(let name, let type, let domain, _) = endpoint,
      type == "_frameshift._tcp", domain == "local.",
      !name.isEmpty, name.utf8.count <= 63
    else { throw FrameServiceResolutionError.invalidService }

    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      let service = NetService(domain: domain, type: "\(type).", name: name)
      self.service = service
      service.delegate = self
      service.resolve(withTimeout: 5)
    }
  }

  nonisolated public func netServiceDidResolveAddress(_ sender: NetService) {
    Task { @MainActor in self.didResolve() }
  }

  nonisolated public func netService(
    _ sender: NetService, didNotResolve errorDict: [String: NSNumber]
  ) {
    Task { @MainActor in self.finish(.failure(FrameServiceResolutionError.unavailable)) }
  }

  nonisolated public func netServiceDidStop(_ sender: NetService) {
    Task { @MainActor in self.finish(.failure(FrameServiceResolutionError.unavailable)) }
  }

  private func didResolve() {
    guard let service,
      let hostName = service.hostName,
      let origin = Self.origin(hostName: hostName, port: service.port)
    else {
      finish(.failure(FrameServiceResolutionError.unavailable))
      return
    }
    finish(.success(origin))
  }

  private func finish(_ result: Result<String, Error>) {
    guard let continuation else { return }
    self.continuation = nil
    service?.delegate = nil
    service?.stop()
    service = nil
    continuation.resume(with: result)
  }

  public static func origin(hostName: String, port: Int) -> String? {
    guard port > 0, port <= 65_535, hostName.utf8.count <= 253 else { return nil }
    let normalized =
      hostName.lowercased().hasSuffix(".")
      ? String(hostName.dropLast()).lowercased() : hostName.lowercased()
    let labels = normalized.split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count >= 2, labels.last == "local",
      labels.dropLast().allSatisfy({ label in
        (1...63).contains(label.utf8.count)
          && label.range(of: #"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$"#, options: .regularExpression)
            != nil
      })
    else { return nil }
    return "https://\(normalized):\(port)"
  }
}
