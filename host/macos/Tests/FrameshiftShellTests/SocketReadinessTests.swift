import Darwin
import Foundation
import Testing

@testable import FrameshiftShell

@Suite("Unix socket readiness")
struct SocketReadinessTests {
  @Test("a leftover socket file is not treated as a listening core")
  func staleSocket() throws {
    let path = "/tmp/frameshift-stale-\(UUID().uuidString).sock"
    let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    #expect(descriptor >= 0)
    defer {
      _ = Darwin.close(descriptor)
      _ = Darwin.unlink(path)
    }

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    withUnsafeMutableBytes(of: &address.sun_path) { destination in
      destination.copyBytes(from: Array(path.utf8) + [0])
    }

    let bound = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    #expect(bound == 0)
    #expect(FileManager.default.fileExists(atPath: path))
    #expect(!UnixSocket.isAccepting(path: path))

    #expect(Darwin.listen(descriptor, 1) == 0)
    #expect(UnixSocket.isAccepting(path: path))
  }
}
