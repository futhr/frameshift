import Foundation
import OSLog
import Observation

@MainActor
@Observable
public final class ShellModel {
  private static let logger = Logger(subsystem: "io.frameshift.app", category: "shell")
  public private(set) var snapshot: CoreSnapshot
  public private(set) var isBusy = false
  public private(set) var errorMessage: String?
  public var draftInstruction: String
  public private(set) var searchQuery = ""
  public private(set) var searchError: String?
  public private(set) var searchItems: [LibraryItem]?
  public private(set) var guideHandoff: GuideHandoff?

  private let client: any CoreClient
  private var searchRevision = 0

  public init(
    client: any CoreClient,
    initialSnapshot: CoreSnapshot = .disconnected
  ) {
    self.client = client
    snapshot = initialSnapshot
    draftInstruction = initialSnapshot.instruction
  }

  public func refresh() async {
    await perform { try await client.snapshot() }
  }

  public var visibleItems: [LibraryItem] {
    searchItems ?? snapshot.items
  }

  public func setSearchQuery(_ query: String) {
    searchQuery = query
    searchRevision += 1
    let revision = searchRevision

    guard !query.isEmpty else {
      searchItems = nil
      searchError = nil
      return
    }

    guard query.utf8.count <= 256 else {
      searchItems = []
      searchError = "Search is limited to 256 bytes."
      return
    }

    Task {
      try? await Task.sleep(for: .milliseconds(150))
      guard revision == searchRevision else { return }
      await loadSearch(query, revision: revision)
    }
  }

  public func submitSearch() async {
    await refreshSearch()
  }

  private func refreshSearch() async {
    guard !searchQuery.isEmpty, searchQuery.utf8.count <= 256 else { return }
    searchRevision += 1
    await loadSearch(searchQuery, revision: searchRevision)
  }

  private func loadSearch(_ query: String, revision: Int) async {
    do {
      let result = try await client.snapshot(query: query)
      guard revision == searchRevision else { return }
      searchItems = result.items
      searchError = nil
    } catch {
      guard revision == searchRevision else { return }
      searchItems = []
      searchError = "Library search is unavailable."
    }
  }

  public func selectTarget(_ targetID: String) async {
    await send(CoreCommand(kind: .selectTarget, targetID: targetID))
  }

  public func receiveGuideURL(_ url: URL) {
    guard let handoff = GuideHandoff.parse(url) else { return }
    guideHandoff = handoff
  }

  public func dismissGuideHandoff() {
    guideHandoff = nil
  }

  public var guideMatchingTargets: [FrameTarget] {
    guard let handoff = guideHandoff else { return [] }
    return snapshot.targets.filter { target in
      target.medium == handoff.medium
        && (handoff.profileID == nil || target.profileID == handoff.profileID)
    }
  }

  public func saveInstruction() async {
    await send(CoreCommand(kind: .updateInstruction, instruction: draftInstruction))
  }

  public func importFile(_ url: URL) async {
    await send(CoreCommand(kind: .importFile, importPath: url.path))
  }

  public func togglePin(_ itemID: String) async {
    guard let item = snapshot.items.first(where: { $0.id == itemID }) else { return }
    await send(CoreCommand(kind: .setPinned, itemID: itemID, isPinned: !item.isPinned))
  }

  public func remove(_ itemID: String) async {
    await send(CoreCommand(kind: .remove, itemID: itemID))
  }

  public func queue(_ itemID: String) async {
    guard let selectedTargetID = snapshot.selectedTargetID else { return }
    await send(
      CoreCommand(
        kind: .queue,
        targetID: selectedTargetID,
        itemID: itemID
      )
    )
  }

  public func loopPinned(dwellMs: Int?) async {
    guard let selectedTargetID = snapshot.selectedTargetID else { return }
    await send(CoreCommand(kind: .loopPinned, targetID: selectedTargetID, dwellMs: dwellMs))
  }

  public func reconcileDelivery() async {
    guard let selectedTargetID = snapshot.selectedTargetID else { return }
    await send(CoreCommand(kind: .reconcileDelivery, targetID: selectedTargetID))
  }

  public func dismissError() {
    errorMessage = nil
  }

  private func send(_ command: CoreCommand) async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }

    do {
      apply(try await client.send(command))
      errorMessage = nil
    } catch CoreClientError.commandOutcomeUnknown {
      do {
        apply(try await client.snapshot())
        errorMessage =
          "The core restarted before it could confirm the command. Current state was refreshed; review it before trying again."
      } catch {
        errorMessage =
          "The core restarted before it could confirm the command. Reconnect and review current state before trying again."
      }
    } catch CoreClientError.commandIDConflict {
      errorMessage = "The command identity was rejected. Refresh and try the operation again."
    } catch CoreClientError.deliveryOutcomeUnknown {
      do {
        apply(try await client.snapshot())
        errorMessage =
          "The frame did not confirm display. Its pending delivery is saved; check the frame before sending again."
      } catch {
        errorMessage =
          "The frame did not confirm display. Reconnect and check its delivery state before sending again."
      }
    } catch CoreClientError.credentialBrokerUnavailable {
      errorMessage =
        "Secure frame credentials are not available on this Mac. Direct send was not started."
    } catch CoreClientError.deliveryPending {
      errorMessage =
        "This frame already has a pending direct delivery. Confirm its display before sending another image."
    } catch CoreClientError.noPinnedArtwork {
      errorMessage = "Pin artwork in the library before starting a loop."
    } catch CoreClientError.intervalRequired {
      errorMessage = "Choose a loop interval for this frame."
    } catch CoreClientError.loopUnavailable {
      errorMessage = "Frame cannot cycle artwork offline. Check its pairing and transfer mode."
    } catch CoreClientError.loopStorageFull {
      errorMessage = "This frame cannot hold the pinned set. Remove pins or free frame storage."
    } catch CoreClientError.loopPending {
      errorMessage = "This loop is already queued. Wait for the frame to confirm it."
    } catch CoreClientError.loopAlreadyActive {
      errorMessage = "Loop is already on this frame. Change pins or interval to queue another."
    } catch let error as CoreClientError {
      Self.logger.error("core command failed: \(String(describing: error), privacy: .public)")
      errorMessage = "The core command could not be completed."
    } catch {
      errorMessage = "The core command could not be completed."
    }
    await refreshSearch()
  }

  private func perform(_ operation: () async throws -> CoreSnapshot) async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }

    do {
      apply(try await operation())
      errorMessage = nil
    } catch let error as CoreClientError {
      Self.logger.error("core refresh failed: \(String(describing: error), privacy: .public)")
      errorMessage = "The core command could not be completed."
    } catch {
      errorMessage = "The core command could not be completed."
    }
    await refreshSearch()
  }

  private func apply(_ next: CoreSnapshot) {
    snapshot = next
    draftInstruction = next.instruction
  }
}
