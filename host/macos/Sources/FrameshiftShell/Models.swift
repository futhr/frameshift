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
  case preview
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
  public var selectedTargetID: String
  public var instruction: String
  public var items: [LibraryItem]
  public var generationAvailability: GenerationAvailability
  public var statusMessage: String

  public init(
    targets: [FrameTarget],
    selectedTargetID: String,
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
    targets.first(where: { $0.id == selectedTargetID })
  }
}

public struct CoreCommand: Codable, Equatable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case selectTarget
    case updateInstruction
    case importFile
    case togglePin
    case remove
    case queue
  }

  public let id: UUID
  public let kind: Kind
  public let targetID: String?
  public let itemID: String?
  public let instruction: String?
  public let importPath: String?

  public init(
    id: UUID = UUID(),
    kind: Kind,
    targetID: String? = nil,
    itemID: String? = nil,
    instruction: String? = nil,
    importPath: String? = nil
  ) {
    self.id = id
    self.kind = kind
    self.targetID = targetID
    self.itemID = itemID
    self.instruction = instruction
    self.importPath = importPath
  }
}
