import Foundation
import Security

enum HostCertificate {
  static func issue(privateKey: SecKey, now: Date = Date()) throws -> SecCertificate {
    guard let publicKey = SecKeyCopyPublicKey(privateKey),
      let publicBytes = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
      publicBytes.count == 65, publicBytes.first == 0x04,
      SecKeyIsAlgorithmSupported(privateKey, .sign, .ecdsaSignatureMessageX962SHA256)
    else { throw KeychainIdentityError.unsupportedKey }

    var serial = Data(count: 16)
    let randomResult = serial.withUnsafeMutableBytes { bytes in
      SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
    }
    guard randomResult == errSecSuccess else { throw KeychainIdentityError.signingFailed }

    let signatureAlgorithm = DER.sequence([
      DER.oid([0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02])
    ])
    let name = DER.sequence([
      DER.set([DER.sequence([DER.oid([0x55, 0x04, 0x03]), DER.utf8("Frameshift Host")])])
    ])
    let validFrom = now.addingTimeInterval(-86_400)
    let validUntil = now.addingTimeInterval(365 * 86_400)
    let validity = DER.sequence([DER.utcTime(validFrom), DER.utcTime(validUntil)])
    let publicKeyAlgorithm = DER.sequence([
      DER.oid([0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01]),
      DER.oid([0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07]),
    ])
    let subjectPublicKeyInfo = DER.sequence([publicKeyAlgorithm, DER.bitString(publicBytes)])
    let extensions = DER.tag(
      0xA3,
      DER.sequence([
        DER.extensionValue([0x55, 0x1D, 0x13], critical: true, DER.sequence([])),
        DER.extensionValue([0x55, 0x1D, 0x0F], critical: true, DER.tag(0x03, Data([0x07, 0x80]))),
        DER.extensionValue(
          [0x55, 0x1D, 0x25],
          critical: false,
          DER.sequence([
            DER.oid([0x2B, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x01]),
            DER.oid([0x2B, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x02]),
          ])
        ),
      ]))
    let tbs = DER.sequence([
      DER.tag(0xA0, DER.integer(Data([0x02]))),
      DER.integer(serial),
      signatureAlgorithm,
      name,
      validity,
      name,
      subjectPublicKeyInfo,
      extensions,
    ])

    var error: Unmanaged<CFError>?
    guard
      let signature = SecKeyCreateSignature(
        privateKey, .ecdsaSignatureMessageX962SHA256, tbs as CFData, &error
      ) as Data?
    else {
      error?.release()
      throw KeychainIdentityError.signingFailed
    }

    let encoded = DER.sequence([tbs, signatureAlgorithm, DER.bitString(signature)])
    guard let certificate = SecCertificateCreateWithData(nil, encoded as CFData) else {
      throw KeychainIdentityError.signingFailed
    }
    return certificate
  }
}

private enum DER {
  static func tag(_ tag: UInt8, _ content: Data) -> Data {
    var encoded = Data([tag])
    if content.count < 128 {
      encoded.append(UInt8(content.count))
    } else {
      var length = content.count
      var bytes: [UInt8] = []
      while length > 0 {
        bytes.insert(UInt8(length & 0xFF), at: 0)
        length >>= 8
      }
      encoded.append(0x80 | UInt8(bytes.count))
      encoded.append(contentsOf: bytes)
    }
    encoded.append(content)
    return encoded
  }

  static func sequence(_ members: [Data]) -> Data {
    tag(0x30, members.reduce(into: Data(), { $0.append($1) }))
  }
  static func set(_ members: [Data]) -> Data {
    tag(0x31, members.reduce(into: Data(), { $0.append($1) }))
  }
  static func oid(_ encodedValue: [UInt8]) -> Data { tag(0x06, Data(encodedValue)) }
  static func utf8(_ value: String) -> Data { tag(0x0C, Data(value.utf8)) }

  static func integer(_ value: Data) -> Data {
    var normalized = value
    if normalized.first.map({ $0 & 0x80 != 0 }) == true { normalized.insert(0, at: 0) }
    return tag(0x02, normalized)
  }

  static func bitString(_ value: Data) -> Data { tag(0x03, Data([0]) + value) }

  static func utcTime(_ date: Date) -> Data {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyMMddHHmmss'Z'"
    return tag(0x17, Data(formatter.string(from: date).utf8))
  }

  static func extensionValue(_ oidBytes: [UInt8], critical: Bool, _ value: Data) -> Data {
    var fields = [oid(oidBytes)]
    if critical { fields.append(tag(0x01, Data([0xFF]))) }
    fields.append(tag(0x04, value))
    return sequence(fields)
  }
}
