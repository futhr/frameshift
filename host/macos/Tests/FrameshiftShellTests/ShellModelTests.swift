import Foundation
import FrameshiftShell
import Testing

@Suite("Authoritative shell state")
@MainActor
struct ShellModelTests {
  @Test("Successful commands replace the complete snapshot")
  func appliesCommandSnapshot() async {
    let client = RecordingClient()
    let model = ShellModel(client: client)
    model.draftInstruction = "A quiet geometric still"

    await model.saveInstruction()

    #expect(model.snapshot.instruction == "A quiet geometric still")
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
}

private struct PendingDeliveryClient: CoreClient {
  func snapshot() -> CoreSnapshot { .disconnected }
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

  func send(_: CoreCommand) throws -> CoreSnapshot {
    sends += 1
    throw CoreClientError.deliveryOutcomeUnknown
  }

  func sendCount() -> Int { sends }
}

private struct MissingCredentialClient: CoreClient {
  func snapshot() -> CoreSnapshot { .disconnected }
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

  func send(_: CoreCommand) throws -> CoreSnapshot {
    throw CoreClientError.commandOutcomeUnknown
  }
}

private struct FailingClient: CoreClient {
  func snapshot() throws -> CoreSnapshot {
    throw CoreClientError.coreUnavailable
  }

  func send(_: CoreCommand) throws -> CoreSnapshot {
    throw CoreClientError.protocolFailure
  }
}
