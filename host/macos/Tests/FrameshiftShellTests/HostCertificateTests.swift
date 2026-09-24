import Foundation
import Security
import Testing

@testable import FrameshiftShell

@Suite("Host TLS certificate")
struct HostCertificateTests {
  @Test("A P-256 key produces a self-issued client and server certificate")
  func signsValidCertificate() throws {
    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
    ]
    var error: Unmanaged<CFError>?
    let privateKey = try #require(SecKeyCreateRandomKey(attributes as CFDictionary, &error))
    let certificate = try HostCertificate.issue(privateKey: privateKey)
    let encoded = SecCertificateCopyData(certificate) as Data
    #expect(encoded.count > 200 && encoded.count < 2_048)

    let policy = SecPolicyCreateBasicX509()
    var trust: SecTrust?
    #expect(SecTrustCreateWithCertificates(certificate, policy, &trust) == errSecSuccess)
    let checked = try #require(trust)
    #expect(SecTrustSetAnchorCertificates(checked, [certificate] as CFArray) == errSecSuccess)
    #expect(SecTrustSetAnchorCertificatesOnly(checked, true) == errSecSuccess)
    #expect(SecTrustEvaluateWithError(checked, nil))

    let certificateKey = try #require(SecCertificateCopyKey(certificate))
    let expectedKey = try #require(SecKeyCopyPublicKey(privateKey))
    #expect(
      SecKeyCopyExternalRepresentation(certificateKey, nil) as Data?
        == SecKeyCopyExternalRepresentation(expectedKey, nil) as Data?
    )
  }

  @Test("The installed Keychain host identity is stable across lookup")
  func storesHostIdentityWhenExplicitlyRequested() throws {
    guard ProcessInfo.processInfo.environment["FRAMESHIFT_KEYCHAIN_TESTS"] == "1" else { return }
    let store = KeychainIdentityStore()
    let first = try store.ensureHostIdentity()
    let second = try store.ensureHostIdentity()
    #expect(first == second)
    #expect(try store.describe(reference: first).algorithm == "ecdsa")
  }
}
