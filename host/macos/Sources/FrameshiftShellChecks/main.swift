import Foundation
import FrameshiftShell

private struct CheckFailure: Error, CustomStringConvertible {
  let description: String
}

@main
private struct FrameshiftShellChecks {
  static func main() async throws {
    try await checkItemLifecycle()
    try await checkExperimentalTargets()
    try await checkInvalidIdentities()
    try await checkShellModel()
    try await checkRedactedErrors()
    print("Frameshift shell checks passed")
  }

  private static func checkItemLifecycle() async throws {
    let client = PreviewCoreClient()
    let fixtureDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "frameshift-shell-checks-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: fixtureDirectory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: fixtureDirectory) }

    let firstURL = fixtureDirectory.appendingPathComponent("quiet-study.png")
    let duplicateURL = fixtureDirectory.appendingPathComponent("duplicate.png")
    let fixture = Data([1, 2, 3, 4, 5, 6])
    try fixture.write(to: firstURL, options: .atomic)
    try fixture.write(to: duplicateURL, options: .atomic)

    var snapshot = try await client.send(
      CoreCommand(kind: .importFile, importPath: firstURL.path)
    )
    let item = try require(snapshot.items.first, "manual import did not create an item")
    try expect(item.title == "quiet-study", "manual import title changed")
    try expect(item.digest.hasPrefix("sha256:"), "manual import digest is not content addressed")

    snapshot = try await client.send(
      CoreCommand(kind: .importFile, importPath: duplicateURL.path)
    )
    try expect(snapshot.items.count == 1, "identical import bytes were duplicated")

    snapshot = try await client.send(CoreCommand(kind: .togglePin, itemID: item.id))
    try expect(snapshot.items.first?.isPinned == true, "pin command did not update the snapshot")

    snapshot = try await client.send(
      CoreCommand(
        kind: .queue,
        targetID: snapshot.selectedTargetID,
        itemID: item.id
      )
    )
    try expect(
      snapshot.items.first?.queuedTargetID == "preview-paper",
      "queue command targeted the wrong preview frame"
    )

    snapshot = try await client.send(CoreCommand(kind: .remove, itemID: item.id))
    try expect(snapshot.items.isEmpty, "remove command left the item active")
  }

  private static func checkExperimentalTargets() async throws {
    let snapshot = await PreviewCoreClient().snapshot()
    try expect(snapshot.targets.count == 3, "preview must expose the three reference media")
    try expect(
      snapshot.targets.allSatisfy { $0.profileID.contains(":experimental:") },
      "preview profiles must remain explicitly experimental"
    )
    try expect(
      snapshot.generationAvailability == .notConfigured,
      "generation must not appear available without a provider"
    )
  }

  private static func checkInvalidIdentities() async throws {
    let client = PreviewCoreClient()

    do {
      _ = try await client.send(CoreCommand(kind: .selectTarget, targetID: "missing"))
      throw CheckFailure(description: "missing target was accepted")
    } catch CoreClientError.targetNotFound {
      // Expected.
    }

    do {
      _ = try await client.send(CoreCommand(kind: .togglePin, itemID: "missing"))
      throw CheckFailure(description: "missing item was accepted")
    } catch CoreClientError.itemNotFound {
      // Expected.
    }
  }

  @MainActor
  private static func checkShellModel() async throws {
    let recorder = RecordingClient()
    let model = ShellModel(client: recorder)
    model.draftInstruction = "A quiet geometric still"
    await model.saveInstruction()

    try expect(
      model.snapshot.instruction == "A quiet geometric still",
      "shell did not apply the returned core snapshot"
    )
    let commandKinds = await recorder.commandKinds()
    try expect(commandKinds == [.updateInstruction], "shell bypassed the command client")
  }

  @MainActor
  private static func checkRedactedErrors() async throws {
    let model = ShellModel(client: FailingClient())
    await model.selectTarget("private-target-name")
    try expect(
      model.errorMessage == "The core command could not be completed.",
      "shell error copy changed"
    )
    try expect(
      model.errorMessage?.contains("private-target-name") == false,
      "shell error exposed command data"
    )
  }

  private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure(description: message) }
  }

  private static func require<Value>(_ value: Value?, _ message: String) throws -> Value {
    guard let value else { throw CheckFailure(description: message) }
    return value
  }
}

private actor RecordingClient: CoreClient {
  private var commands: [CoreCommand] = []
  private var current = CoreSnapshot.researchPreview

  func snapshot() -> CoreSnapshot {
    current
  }

  func send(_ command: CoreCommand) -> CoreSnapshot {
    commands.append(command)
    if command.kind == .updateInstruction {
      current.instruction = command.instruction ?? ""
    }
    return current
  }

  func commandKinds() -> [CoreCommand.Kind] {
    commands.map(\.kind)
  }
}

private struct FailingClient: CoreClient {
  func snapshot() async throws -> CoreSnapshot {
    throw CoreClientError.invalidCommand
  }

  func send(_ command: CoreCommand) async throws -> CoreSnapshot {
    _ = command
    throw CoreClientError.invalidCommand
  }
}
