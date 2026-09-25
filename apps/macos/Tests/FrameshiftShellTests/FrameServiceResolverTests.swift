import Foundation
import FrameshiftShell
import Network
import Testing

@Suite("Selected frame service resolution")
@MainActor
struct FrameServiceResolverTests {
  @Test("Only bounded local DNS names form a pairing origin")
  func admitsLocalOrigin() {
    #expect(
      FrameServiceResolver.origin(hostName: "Frame-1.local.", port: 443)
        == "https://frame-1.local:443")
    #expect(FrameServiceResolver.origin(hostName: "frame.example.com", port: 443) == nil)
    #expect(FrameServiceResolver.origin(hostName: "frame..local", port: 443) == nil)
    #expect(FrameServiceResolver.origin(hostName: "-frame.local", port: 443) == nil)
    #expect(FrameServiceResolver.origin(hostName: "frame.local", port: 0) == nil)
  }

  @Test("A non-frame Bonjour endpoint is refused before lookup")
  func refusesWrongService() async {
    let endpoint = NWEndpoint.service(
      name: "other", type: "_other._tcp", domain: "local.", interface: nil
    )
    do {
      _ = try await FrameServiceResolver().resolve(endpoint)
      Issue.record("Resolved a non-frame service")
    } catch FrameServiceResolutionError.invalidService {
      // Expected.
    } catch {
      Issue.record("Unexpected resolution error")
    }
  }

  @Test("A local advertised service resolves to its bounded origin")
  func resolvesLiveBonjourWhenExplicitlyRequested() async throws {
    guard ProcessInfo.processInfo.environment["FRAMESHIFT_BONJOUR_TESTS"] == "1" else { return }
    let endpoint = NWEndpoint.service(
      name: "FrameshiftProbe", type: "_frameshift._tcp", domain: "local.", interface: nil
    )
    let origin = try await FrameServiceResolver().resolve(endpoint)
    #expect(origin.hasPrefix("https://"))
    #expect(origin.hasSuffix(":54321"))
  }
}
