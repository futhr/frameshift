import Foundation

public enum DiagnosticsClient {
  private static let maximumRequestBytes = 8_192
  private static let maximumResponseBytes = 256 * 1024

  public static func defaultSocketPath() -> String {
    if let configured = ProcessInfo.processInfo.environment["FRAMESHIFT_DIAGNOSTICS_SOCKET_PATH"],
      !configured.isEmpty
    {
      return URL(fileURLWithPath: configured).standardizedFileURL.path
    }

    return URL(fileURLWithPath: LocalCoreClient.defaultSocketPath())
      .deletingLastPathComponent()
      .appendingPathComponent("d.sock")
      .path
  }

  public static func query(
    _ operation: String,
    cursor: Int? = nil,
    limit: Int = 50,
    socketPath: String = defaultSocketPath()
  ) throws -> Data {
    guard ["health", "metrics", "audit"].contains(operation),
      (1...100).contains(limit),
      cursor.map({ $0 >= 0 }) ?? true
    else {
      throw CoreClientError.invalidCommand
    }

    let requestID = UUID().uuidString.lowercased()
    var request: [String: Any] = [
      "version": 1,
      "requestId": requestID,
      "operation": operation,
    ]

    if operation != "health" {
      request["limit"] = limit
      if let cursor { request["cursor"] = cursor }
    }

    let payload = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
    guard payload.count <= maximumRequestBytes else { throw CoreClientError.invalidCommand }

    let response = try UnixSocket.exchange(
      path: socketPath,
      payload: payload,
      maximumResponseBytes: maximumResponseBytes
    )

    guard let document = try JSONSerialization.jsonObject(with: response) as? [String: Any],
      document["version"] as? Int == 1,
      document["requestId"] as? String == requestID,
      document["ok"] as? Bool == true,
      document["diagnostics"] != nil
    else {
      throw CoreClientError.protocolFailure
    }

    return response
  }
}
