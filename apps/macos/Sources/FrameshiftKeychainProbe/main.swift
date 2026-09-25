import Darwin
import Foundation
import FrameshiftShell

/// Local integration fixture: keep the real Keychain broker available to an Elixir TLS test.
@main
private struct FrameshiftKeychainProbe {
  static func main() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let path = environment["FRAMESHIFT_CREDENTIAL_SOCKET"],
      let token = environment["FRAMESHIFT_IPC_TOKEN"],
      let runFile = environment["FRAMESHIFT_PROBE_RUN_FILE"]
    else { throw ProbeError.missingConfiguration }

    let store = KeychainIdentityStore.temporaryProbeStore()
    let reference = try store.ensureHostIdentity()
    defer { store.removeTemporaryProbeIdentity() }
    let broker = try KeychainCredentialBroker.start(socketPath: path, token: token, store: store)
    defer { broker.stop() }
    print(reference)
    fflush(stdout)
    while FileManager.default.fileExists(atPath: runFile) {
      Thread.sleep(forTimeInterval: 0.1)
    }
  }
}

private enum ProbeError: Error {
  case missingConfiguration
}
