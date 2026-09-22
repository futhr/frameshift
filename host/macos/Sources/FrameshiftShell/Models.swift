import Foundation

public enum FrameMedium: String, Codable, CaseIterable, Sendable {
  case paper
  case photo
  case pixel

  public var label: String {
    switch self {
    case .paper: "Paper"
    case .photo: "Photo"
    case .pixel: "Pixel"
    }
  }
}

public enum FrameConnectionState: String, Codable, Sendable {
  case waitingForContact
  case displayed
  case failed
}

public struct FrameTarget: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let medium: FrameMedium
  public let profileID: String
  public var state: FrameConnectionState

  public init(
    id: String,
    name: String,
    medium: FrameMedium,
    profileID: String,
    state: FrameConnectionState
  ) {
    self.id = id
    self.name = name
    self.medium = medium
    self.profileID = profileID
    self.state = state
  }
}

public struct LibraryItem: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let digest: String
  public var isPinned: Bool
  public var queuedTargetID: String?

  public init(
    id: String,
    title: String,
    digest: String,
    isPinned: Bool = false,
    queuedTargetID: String? = nil
  ) {
    self.id = id
    self.title = title
    self.digest = digest
    self.isPinned = isPinned
    self.queuedTargetID = queuedTargetID
  }
}

public enum GenerationAvailability: String, Codable, Sendable {
  case notConfigured
  case available
}

public struct CoreSnapshot: Codable, Equatable, Sendable {
  public var targets: [FrameTarget]
  public var selectedTargetID: String?
  public var instruction: String
  public var items: [LibraryItem]
  public var generationAvailability: GenerationAvailability
  public var statusMessage: String

  public init(
    targets: [FrameTarget],
    selectedTargetID: String?,
    instruction: String = "",
    items: [LibraryItem] = [],
    generationAvailability: GenerationAvailability = .notConfigured,
    statusMessage: String
  ) {
    self.targets = targets
    self.selectedTargetID = selectedTargetID
    self.instruction = instruction
    self.items = items
    self.generationAvailability = generationAvailability
    self.statusMessage = statusMessage
  }

  public var selectedTarget: FrameTarget? {
    guard let selectedTargetID else { return nil }
    return targets.first(where: { $0.id == selectedTargetID })
  }
}

extension CoreSnapshot {
  public static let disconnected = CoreSnapshot(
    targets: [],
    selectedTargetID: nil,
    generationAvailability: .notConfigured,
    statusMessage: "Connecting to the Frameshift core…"
  )
}

public struct CoreCommand: Codable, Equatable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case selectTarget
    case updateInstruction
    case importFile
    case setPinned
    case remove
    case queue
  }

  public let id: UUID
  public let kind: Kind
  public let targetID: String?
  public let itemID: String?
  public let instruction: String?
  public let importPath: String?
  public let isPinned: Bool?
  public let importWidth: Int?
  public let importHeight: Int?
  public let importMediaType: String?
  public let importOrientation: Int?
  public let importColorProfile: String?
  public let importCanonicalPath: String?
  public let importCanonicalDigest: String?

  public init(
    id: UUID = UUID(),
    kind: Kind,
    targetID: String? = nil,
    itemID: String? = nil,
    instruction: String? = nil,
    importPath: String? = nil,
    isPinned: Bool? = nil,
    importWidth: Int? = nil,
    importHeight: Int? = nil,
    importMediaType: String? = nil,
    importOrientation: Int? = nil,
    importColorProfile: String? = nil,
    importCanonicalPath: String? = nil,
    importCanonicalDigest: String? = nil
  ) {
    self.id = id
    self.kind = kind
    self.targetID = targetID
    self.itemID = itemID
    self.instruction = instruction
    self.importPath = importPath
    self.isPinned = isPinned
    self.importWidth = importWidth
    self.importHeight = importHeight
    self.importMediaType = importMediaType
    self.importOrientation = importOrientation
    self.importColorProfile = importColorProfile
    self.importCanonicalPath = importCanonicalPath
    self.importCanonicalDigest = importCanonicalDigest
  }

  func withDecodedImport(_ decoded: DecodedImport) -> CoreCommand {
    let metadata = decoded.metadata
    return CoreCommand(
      id: id,
      kind: kind,
      targetID: targetID,
      itemID: itemID,
      instruction: instruction,
      importPath: importPath,
      isPinned: isPinned,
      importWidth: metadata.width,
      importHeight: metadata.height,
      importMediaType: metadata.mediaType,
      importOrientation: metadata.orientation,
      importColorProfile: metadata.colorProfile,
      importCanonicalPath: decoded.canonicalURL.path,
      importCanonicalDigest: decoded.canonicalDigest
    )
  }
}

package struct ImportMetadata: Sendable {
  package let width: Int
  package let height: Int
  package let mediaType: String
  package let orientation: Int
  package let colorProfile: String?
}
