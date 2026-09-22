import Foundation
import Observation

@MainActor
@Observable
public final class ShellModel {
  public private(set) var snapshot: CoreSnapshot
  public private(set) var isBusy = false
  public private(set) var errorMessage: String?
  public var draftInstruction: String

  private let client: any CoreClient

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

  public func selectTarget(_ targetID: String) async {
    await send(CoreCommand(kind: .selectTarget, targetID: targetID))
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
    } catch {
      errorMessage = "The core command could not be completed."
    }
  }

  private func perform(_ operation: () async throws -> CoreSnapshot) async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }

    do {
      apply(try await operation())
      errorMessage = nil
    } catch {
      errorMessage = "The core command could not be completed."
    }
  }

  private func apply(_ next: CoreSnapshot) {
    snapshot = next
    draftInstruction = next.instruction
  }
}
