import Foundation

public struct GuideHandoff: Equatable, Sendable {
  public let medium: FrameMedium
  public let profileID: String?

  public static func parse(_ url: URL) -> GuideHandoff? {
    let text = url.absoluteString
    guard text.utf8.count <= 512, text.hasPrefix("frameshift://setup?"),
      let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
      parts.scheme == "frameshift", parts.host == "setup", parts.path.isEmpty,
      parts.user == nil, parts.password == nil, parts.port == nil,
      parts.fragment == nil, let items = parts.queryItems,
      (2...3).contains(items.count)
    else { return nil }

    let names = items.map(\.name)
    guard Set(names).count == items.count,
      Set(names).isSubset(of: ["v", "class", "profile"]),
      let version = items.first(where: { $0.name == "v" })?.value,
      version == "1",
      let className = items.first(where: { $0.name == "class" })?.value,
      let medium = FrameMedium(rawValue: className)
    else { return nil }

    let profile = items.first(where: { $0.name == "profile" })?.value
    if names.contains("profile") {
      guard let profile, validProfile(profile) else { return nil }
    }
    return GuideHandoff(medium: medium, profileID: profile)
  }

  private static func validProfile(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    guard !bytes.isEmpty, bytes.count <= 128 else { return false }
    return bytes.allSatisfy { byte in
      (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte)
        || [46, 95, 58, 45].contains(byte)
    }
  }
}
