import Foundation
import FrameshiftShell

private struct ProbeFailure: Error {}

@main
private struct FrameshiftIPCProbe {
  static func main() async throws {
    let client = LocalCoreClient()
    let initial = try await client.snapshot()
    guard initial.targets.isEmpty else { throw ProbeFailure() }

    let marker = "release-smoke-\(UUID().uuidString.lowercased())"
    let updated = try await client.send(
      CoreCommand(kind: .updateInstruction, instruction: marker)
    )
    guard updated.instruction == marker else { throw ProbeFailure() }

    let refreshed = try await client.snapshot()
    guard refreshed.instruction == marker else { throw ProbeFailure() }
    print("Frameshift Swift-to-Elixir IPC probe passed")
  }
}
