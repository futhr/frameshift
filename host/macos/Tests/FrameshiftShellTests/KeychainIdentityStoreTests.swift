import Foundation
import FrameshiftShell
import Testing

@Suite("Keychain identity boundary")
struct KeychainIdentityStoreTests {
  @Test("Malformed persistent references are rejected before Keychain access")
  func rejectsMalformedReference() {
    let store = KeychainIdentityStore()

    #expect(throws: KeychainIdentityError.self) {
      try store.describe(reference: "frame-identity")
    }
    #expect(throws: KeychainIdentityError.self) {
      try store.describe(reference: "keychain:not-valid-***")
    }
    #expect(throws: KeychainIdentityError.self) {
      try store.sign(reference: "keychain:", scheme: "ecdsa-sha256", digest: Data(count: 32))
    }
    #expect(throws: KeychainIdentityError.self) {
      try store.describe(reference: "keychain:AA==")
    }
    #expect(throws: KeychainIdentityError.self) {
      try store.describe(reference: "keychain:" + String(repeating: "A", count: 1_025))
    }
  }
}
