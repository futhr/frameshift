import Foundation
import Security

public enum KeychainIdentityError: Error, Sendable {
  case invalidReference
  case identityUnavailable
  case unsupportedKey
  case signingFailed
  case storageFailed
}

public struct KeychainIdentityDescription: Sendable {
  public let certificate: Data
  public let algorithm: String
}

/// Looks up a paired identity by persistent Keychain reference without exporting its private key.
public struct KeychainIdentityStore: Sendable {
  private static let hostIdentityService = "io.frameshift.host-identity.v1"
  private static let hostIdentityTag = Data("io.frameshift.host-key.v1".utf8)

  public init() {}

  /// Creates or reuses the local host identity without exporting its private key.
  public func ensureHostIdentity() throws -> String {
    if let existing = try storedHostReference() {
      let description = try describe(reference: existing)
      guard description.algorithm == "ecdsa" else { throw KeychainIdentityError.unsupportedKey }
      return existing
    }

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: Self.hostIdentityTag,
      ],
    ]
    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      error?.release()
      throw KeychainIdentityError.storageFailed
    }

    var storedCertificate: SecCertificate?
    var committed = false
    defer {
      if !committed {
        if let storedCertificate {
          SecItemDelete(
            [
              kSecClass as String: kSecClassCertificate,
              kSecValueRef as String: storedCertificate,
            ] as CFDictionary)
        }
        SecItemDelete(
          [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.hostIdentityTag,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
          ] as CFDictionary)
      }
    }

    let certificate = try HostCertificate.issue(privateKey: privateKey)
    let certificateQuery: [String: Any] = [
      kSecClass as String: kSecClassCertificate,
      kSecValueRef as String: certificate,
    ]
    guard SecItemAdd(certificateQuery as CFDictionary, nil) == errSecSuccess else {
      throw KeychainIdentityError.storageFailed
    }
    storedCertificate = certificate

    var identity: SecIdentity?
    guard SecIdentityCreateWithCertificate(nil, certificate, &identity) == errSecSuccess,
      let identity
    else { throw KeychainIdentityError.identityUnavailable }
    let reference = try persistentReference(for: identity)

    let referenceQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.hostIdentityService,
      kSecAttrAccount as String: "default",
      kSecValueData as String: Data(reference.utf8),
    ]
    guard SecItemAdd(referenceQuery as CFDictionary, nil) == errSecSuccess else {
      throw KeychainIdentityError.storageFailed
    }
    committed = true
    return reference
  }

  private func storedHostReference() throws -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.hostIdentityService,
      kSecAttrAccount as String: "default",
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess,
      let data = result as? Data,
      let reference = String(data: data, encoding: .utf8)
    else { throw KeychainIdentityError.identityUnavailable }
    return reference
  }

  /// Produces the opaque reference stored with a paired frame, never private-key bytes.
  public func persistentReference(for identity: SecIdentity) throws -> String {
    let query: [String: Any] = [
      kSecClass as String: kSecClassIdentity,
      kSecMatchItemList as String: [identity],
      kSecReturnPersistentRef as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data,
      !data.isEmpty,
      data.count <= 760
    else {
      throw KeychainIdentityError.identityUnavailable
    }

    return "keychain:"
      + data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  public func describe(reference: String) throws -> KeychainIdentityDescription {
    let identity = try lookup(reference: reference)
    var certificate: SecCertificate?
    guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
      let certificate
    else {
      throw KeychainIdentityError.identityUnavailable
    }

    let privateKey = try privateKey(for: identity)
    let attributes = SecKeyCopyAttributes(privateKey) as? [String: Any]
    let keyType = attributes?[kSecAttrKeyType as String] as? String

    let ecType = kSecAttrKeyTypeECSECPrimeRandom as String
    let rsaType = kSecAttrKeyTypeRSA as String
    let algorithm: String
    switch keyType {
    case ecType:
      algorithm = "ecdsa"
    case rsaType:
      algorithm = "rsa"
    default:
      throw KeychainIdentityError.unsupportedKey
    }

    return KeychainIdentityDescription(
      certificate: SecCertificateCopyData(certificate) as Data,
      algorithm: algorithm
    )
  }

  public func sign(reference: String, scheme: String, digest: Data) throws -> Data {
    let identity = try lookup(reference: reference)
    let privateKey = try privateKey(for: identity)
    guard let algorithm = Self.signingAlgorithm(for: scheme),
      digest.count == Self.digestLength(for: scheme),
      SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm)
    else {
      throw KeychainIdentityError.unsupportedKey
    }

    var error: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(privateKey, algorithm, digest as CFData, &error)
    else {
      error?.release()
      throw KeychainIdentityError.signingFailed
    }
    return signature as Data
  }

  private func lookup(reference: String) throws -> SecIdentity {
    guard reference.hasPrefix("keychain:"), reference.utf8.count <= 1_024 else {
      throw KeychainIdentityError.invalidReference
    }

    let encoded = String(reference.dropFirst("keychain:".count))
    let standard = encoded.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let padded = standard + String(repeating: "=", count: (4 - standard.count % 4) % 4)
    guard let persistentReference = Data(base64Encoded: padded),
      !persistentReference.isEmpty,
      persistentReference.count <= 760,
      persistentReference.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "") == encoded
    else {
      throw KeychainIdentityError.invalidReference
    }

    let query: [String: Any] = [
      kSecClass as String: kSecClassIdentity,
      kSecMatchItemList as String: [persistentReference],
      kSecReturnRef as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let item = result,
      CFGetTypeID(item) == SecIdentityGetTypeID()
    else {
      throw KeychainIdentityError.identityUnavailable
    }
    return item as! SecIdentity
  }

  private func privateKey(for identity: SecIdentity) throws -> SecKey {
    var privateKey: SecKey?
    guard SecIdentityCopyPrivateKey(identity, &privateKey) == errSecSuccess,
      let privateKey
    else {
      throw KeychainIdentityError.identityUnavailable
    }
    return privateKey
  }

  private static func digestLength(for scheme: String) -> Int {
    if scheme.hasSuffix("sha256") { return 32 }
    if scheme.hasSuffix("sha384") { return 48 }
    if scheme.hasSuffix("sha512") { return 64 }
    return 0
  }

  private static func signingAlgorithm(for scheme: String) -> SecKeyAlgorithm? {
    switch scheme {
    case "ecdsa-sha256": .ecdsaSignatureDigestX962SHA256
    case "ecdsa-sha384": .ecdsaSignatureDigestX962SHA384
    case "ecdsa-sha512": .ecdsaSignatureDigestX962SHA512
    case "rsa-pkcs1-sha256": .rsaSignatureDigestPKCS1v15SHA256
    case "rsa-pkcs1-sha384": .rsaSignatureDigestPKCS1v15SHA384
    case "rsa-pkcs1-sha512": .rsaSignatureDigestPKCS1v15SHA512
    case "rsa-pss-sha256": .rsaSignatureDigestPSSSHA256
    case "rsa-pss-sha384": .rsaSignatureDigestPSSSHA384
    case "rsa-pss-sha512": .rsaSignatureDigestPSSSHA512
    default: nil
    }
  }
}
