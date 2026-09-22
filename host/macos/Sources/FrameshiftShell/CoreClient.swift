import CryptoKit
import Foundation

public protocol CoreClient: Sendable {
  func snapshot() async throws -> CoreSnapshot
  func send(_ command: CoreCommand) async throws -> CoreSnapshot
}

public enum CoreClientError: Error, Equatable, Sendable {
  case importTooLarge
  case importUnreadable
  case invalidCommand
  case itemNotFound
  case targetNotFound
}

public actor PreviewCoreClient: CoreClient {
  private let maximumImportBytes = 128 * 1024 * 1024
  private var current: CoreSnapshot

  public init(snapshot: CoreSnapshot = .researchPreview) {
    current = snapshot
  }

  public func snapshot() -> CoreSnapshot {
    current
  }

  public func send(_ command: CoreCommand) throws -> CoreSnapshot {
    switch command.kind {
    case .selectTarget:
      try selectTarget(command.targetID)
    case .updateInstruction:
      guard let instruction = command.instruction else {
        throw CoreClientError.invalidCommand
      }
      current.instruction = instruction
      current.statusMessage = "Instruction saved locally"
    case .importFile:
      try importFile(command.importPath)
    case .togglePin:
      try updateItem(command.itemID) { $0.isPinned.toggle() }
      current.statusMessage = "Pin updated"
    case .remove:
      try removeItem(command.itemID)
    case .queue:
      try queueItem(command.itemID, targetID: command.targetID)
    }
    return current
  }

  private func selectTarget(_ targetID: String?) throws {
    guard let targetID, current.targets.contains(where: { $0.id == targetID }) else {
      throw CoreClientError.targetNotFound
    }
    current.selectedTargetID = targetID
    current.statusMessage = "Preview target selected"
  }

  private func importFile(_ path: String?) throws {
    guard let path, !path.isEmpty else {
      throw CoreClientError.invalidCommand
    }
    let url = URL(fileURLWithPath: path)
    let values: URLResourceValues
    let bytes: Data

    do {
      values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      guard values.isRegularFile == true else { throw CoreClientError.importUnreadable }
      guard let fileSize = values.fileSize, fileSize <= maximumImportBytes else {
        throw CoreClientError.importTooLarge
      }
      bytes = try Data(contentsOf: url, options: .mappedIfSafe)
    } catch let error as CoreClientError {
      throw error
    } catch {
      throw CoreClientError.importUnreadable
    }

    let title = url.deletingPathExtension().lastPathComponent
    let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    if current.items.contains(where: { $0.digest == "sha256:\(digest)" }) {
      current.statusMessage = "Matching content already exists in preview mode"
      return
    }
    current.items.insert(
      LibraryItem(
        id: "import-\(commandSafeID(digest))",
        title: title.isEmpty ? "Imported image" : title,
        digest: "sha256:\(digest)"
      ),
      at: 0
    )
    current.statusMessage = "Import recorded in preview mode"
  }

  private func removeItem(_ itemID: String?) throws {
    guard let itemID, current.items.contains(where: { $0.id == itemID }) else {
      throw CoreClientError.itemNotFound
    }
    current.items.removeAll(where: { $0.id == itemID })
    current.statusMessage = "Item removed from preview library"
  }

  private func queueItem(_ itemID: String?, targetID: String?) throws {
    guard let targetID, current.targets.contains(where: { $0.id == targetID }) else {
      throw CoreClientError.targetNotFound
    }
    try updateItem(itemID) { $0.queuedTargetID = targetID }
    current.statusMessage = "Queued for simulated next contact"
  }

  private func updateItem(
    _ itemID: String?,
    update: (inout LibraryItem) -> Void
  ) throws {
    guard let itemID, let index = current.items.firstIndex(where: { $0.id == itemID }) else {
      throw CoreClientError.itemNotFound
    }
    update(&current.items[index])
  }

  private func commandSafeID(_ digest: String) -> String {
    String(digest.prefix(16))
  }
}

extension CoreSnapshot {
  public static let researchPreview = CoreSnapshot(
    targets: [
      FrameTarget(
        id: "preview-paper",
        name: "Paper Preview",
        medium: .paper,
        profileID: "urn:frameshift:experimental:paper-preview-v1",
        state: .preview
      ),
      FrameTarget(
        id: "preview-photo",
        name: "Photo Preview",
        medium: .photo,
        profileID: "urn:frameshift:experimental:photo-rgb24-v1",
        state: .preview
      ),
      FrameTarget(
        id: "preview-pixel",
        name: "Pixel Preview",
        medium: .pixel,
        profileID: "urn:frameshift:experimental:pixel-rgb24-v1",
        state: .preview
      ),
    ],
    selectedTargetID: "preview-paper",
    generationAvailability: .notConfigured,
    statusMessage: "Research preview • no paired frame"
  )
}
