import Foundation
import FrameshiftShell
import Testing

@Suite("Authoritative shell state")
@MainActor
struct ShellModelTests {
  @Test("A multiline instruction survives command and snapshot replacement")
  func appliesCommandSnapshot() async {
    let client = RecordingClient()
    let model = ShellModel(client: client)
    model.draftInstruction = "A quiet shoreline\nSoft morning light"

    await model.saveInstruction()

    #expect(model.snapshot.instruction == "A quiet shoreline\nSoft morning light")
    #expect(model.errorMessage == nil)
    #expect(await client.commandKinds() == [.updateInstruction])
  }

  @Test("Unknown mutation outcomes reconcile instead of replaying")
  func reconcilesUnknownOutcome() async {
    let model = ShellModel(client: UnknownOutcomeClient())

    await model.saveInstruction()

    #expect(model.snapshot.instruction == "Reconciled state")
    #expect(model.errorMessage?.contains("review it before trying again") == true)
  }

  @Test("Unexpected errors do not expose command payloads")
  func redactsUnexpectedErrors() async {
    let model = ShellModel(client: FailingClient())

    await model.selectTarget("private-target-name")

    #expect(model.errorMessage == "The core command could not be completed.")
    #expect(model.errorMessage?.contains("private-target-name") == false)
  }

  @Test("Unknown direct delivery refreshes durable pending state without replay")
  func reconcilesPendingDirectDelivery() async {
    let client = DirectDeliveryOutcomeClient()
    let model = ShellModel(client: client)

    await model.queue("artwork-1")

    #expect(await client.sendCount() == 0)
    // A queue command requires a selected target; install the authoritative snapshot first.
    await model.refresh()
    await model.queue("artwork-1")

    #expect(await client.sendCount() == 1)
    #expect(model.snapshot.selectedTarget?.directDelivery?.status == .pending)
    #expect(model.errorMessage?.contains("pending delivery is saved") == true)
  }

  @Test("Missing secure credentials are reported before direct send")
  func reportsMissingCredentialBroker() async {
    let model = ShellModel(client: MissingCredentialClient())
    await model.saveInstruction()
    #expect(model.errorMessage?.contains("Secure frame credentials") == true)
  }

  @Test("An unresolved direct intent is not presented as a generic failure")
  func reportsPendingDelivery() async {
    let model = ShellModel(client: PendingDeliveryClient())
    await model.saveInstruction()
    #expect(model.errorMessage?.contains("already has a pending direct delivery") == true)
  }

  @Test("Check frame sends a reconciliation command without selecting artwork")
  func requestsDirectReconciliation() async {
    let client = DirectDeliveryOutcomeClient()
    let model = ShellModel(client: client)
    await model.refresh()
    await model.reconcileDelivery()
    #expect(await client.sendCount() == 1)
    #expect(model.snapshot.selectedTarget?.directDelivery?.status == .pending)
  }

  @Test("A loop without pinned artwork explains the next action")
  func reportsMissingLoopPins() async {
    let target = FrameTarget(
      id: "paper-1",
      name: "Hallway",
      medium: .paper,
      profileID: "paper-profile",
      state: .waitingForContact
    )
    let initial = CoreSnapshot(
      targets: [target],
      selectedTargetID: target.id,
      statusMessage: "Ready"
    )
    let model = ShellModel(client: MissingLoopPinsClient(), initialSnapshot: initial)

    await model.loopPinned(dwellMs: 21_600_000)

    #expect(model.errorMessage == "Pin artwork in the library before starting a loop.")
  }

  @Test("Search displays matching cards and refreshes after removal")
  func searchesAuthoritativeLibrary() async {
    let initial = CoreSnapshot(
      targets: [],
      selectedTargetID: nil,
      items: [
        LibraryItem(id: "blue", title: "Blue study", digest: "blue"),
        LibraryItem(id: "warm", title: "Warm study", digest: "warm"),
      ],
      statusMessage: "Ready"
    )
    let model = ShellModel(client: SearchClient(snapshot: initial), initialSnapshot: initial)

    model.setSearchQuery("Warm")
    await model.submitSearch()
    #expect(model.visibleItems.map(\.id) == ["warm"])
    #expect(model.snapshot.items.count == 2)

    await model.remove("warm")
    #expect(model.visibleItems.isEmpty)

    model.setSearchQuery("")
    #expect(model.visibleItems.map(\.id) == ["blue"])
  }
}

private actor SearchClient: CoreClient {
  private var current: CoreSnapshot

  init(snapshot: CoreSnapshot) {
    current = snapshot
  }

  func snapshot() -> CoreSnapshot { current }

  func snapshot(query: String) -> CoreSnapshot {
    var result = current
    result.items = current.items.filter { $0.title.localizedCaseInsensitiveContains(query) }
    return result
  }

  func send(_ command: CoreCommand) -> CoreSnapshot {
    if command.kind == .remove {
      current.items.removeAll { $0.id == command.itemID }
    }
    return current
  }
}

private struct MissingLoopPinsClient: CoreClient {
  func snapshot() -> CoreSnapshot { .disconnected }
  func snapshot(query _: String) -> CoreSnapshot { .disconnected }
  func send(_: CoreCommand) throws -> CoreSnapshot { throw CoreClientError.noPinnedArtwork }
}

private struct PendingDeliveryClient: CoreClient {
  func snapshot() -> CoreSnapshot { .disconnected }
  func snapshot(query _: String) -> CoreSnapshot { .disconnected }
  func send(_: CoreCommand) throws -> CoreSnapshot {
    throw CoreClientError.deliveryPending
  }
}

private actor DirectDeliveryOutcomeClient: CoreClient {
  private var sends = 0

  func snapshot() throws -> CoreSnapshot {
    let data = Data(
      """
      {"targets":[{"id":"frame-1","name":"Study","medium":"photo",\
      "profileID":"profile-1","state":"waitingForContact",\
      "directDelivery":{"status":"pending","revision":1,"desiredDigest":"sha256:artifact"}}],\
      "selectedTargetID":"frame-1","instruction":"","items":[],\
      "generationAvailability":"notConfigured","statusMessage":"Ready"}
      """.utf8)
    return try JSONDecoder().decode(CoreSnapshot.self, from: data)
  }

  func snapshot(query _: String) throws -> CoreSnapshot { try snapshot() }

  func send(_: CoreCommand) throws -> CoreSnapshot {
    sends += 1
    throw CoreClientError.deliveryOutcomeUnknown
  }

  func sendCount() -> Int { sends }
}

private struct MissingCredentialClient: CoreClient {
  func snapshot() -> CoreSnapshot { .disconnected }
  func snapshot(query _: String) -> CoreSnapshot { .disconnected }
  func send(_: CoreCommand) throws -> CoreSnapshot {
    throw CoreClientError.credentialBrokerUnavailable
  }
}

private actor RecordingClient: CoreClient {
  private var commands: [CoreCommand] = []
  private var current = CoreSnapshot.disconnected

  func snapshot() -> CoreSnapshot {
    current
  }

  func snapshot(query _: String) -> CoreSnapshot { current }

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

private struct UnknownOutcomeClient: CoreClient {
  func snapshot() -> CoreSnapshot {
    CoreSnapshot(
      targets: [],
      selectedTargetID: nil,
      instruction: "Reconciled state",
      statusMessage: "Ready"
    )
  }

  func snapshot(query _: String) -> CoreSnapshot { snapshot() }

  func send(_: CoreCommand) throws -> CoreSnapshot {
    throw CoreClientError.commandOutcomeUnknown
  }
}

private struct FailingClient: CoreClient {
  func snapshot() throws -> CoreSnapshot {
    throw CoreClientError.coreUnavailable
  }

  func snapshot(query _: String) throws -> CoreSnapshot { try snapshot() }

  func send(_: CoreCommand) throws -> CoreSnapshot {
    throw CoreClientError.protocolFailure
  }
}
