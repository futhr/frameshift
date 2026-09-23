import Foundation
import FrameshiftShell
import Testing

@Suite("Shell value models")
struct ModelsTests {
  @Test("Frame media have stable human labels")
  func frameMediumLabels() {
    #expect(FrameMedium.paper.label == "Paper")
    #expect(FrameMedium.photo.label == "Photo")
    #expect(FrameMedium.pixel.label == "Pixel")
  }

  @Test("Selected target resolves only an exact durable identifier")
  func selectedTarget() {
    let paper = FrameTarget(
      id: "paper-1",
      name: "Hallway",
      medium: .paper,
      profileID: "urn:frameshift:profile:paper",
      state: .waitingForContact
    )
    let photo = FrameTarget(
      id: "photo-1",
      name: "Studio",
      medium: .photo,
      profileID: "urn:frameshift:profile:photo",
      state: .displayed
    )

    var snapshot = CoreSnapshot(
      targets: [paper, photo],
      selectedTargetID: photo.id,
      statusMessage: "Ready"
    )

    #expect(snapshot.selectedTarget == photo)

    snapshot.selectedTargetID = "missing"
    #expect(snapshot.selectedTarget == nil)
  }

  @Test("Commands preserve their identity and optional payload through Codable")
  func commandCodableRoundTrip() throws {
    let id = try #require(UUID(uuidString: "018f20d0-975c-7c4a-b38f-a2f9c6da1c4b"))
    let command = CoreCommand(
      id: id,
      kind: .queue,
      targetID: "frame-1",
      itemID: "sha256:fixture"
    )

    let encoded = try JSONEncoder().encode(command)
    let decoded = try JSONDecoder().decode(CoreCommand.self, from: encoded)

    #expect(decoded == command)
    #expect(decoded.id == id)
  }

  @Test("Profile timing and pending loop survive the core snapshot boundary")
  func playlistSnapshotRoundTrip() throws {
    let source = Data(
      """
      {"targets":[{"id":"paper-1","name":"Hallway","medium":"paper","profileID":"paper-v1","state":"waitingForContact","minimumDwellMs":180000,"recommendedDwellMs":21600000,"recommendationBasis":"provisional-profile","recommendationRevision":"frameshift-paper-e6-v1","playlist":{"status":"pending","revision":"sha256:fixture","entryCount":2,"dwellMs":21600000}}],"selectedTargetID":"paper-1","instruction":"","items":[],"generationAvailability":"notConfigured","statusMessage":"Waiting for frame"}
      """.utf8
    )

    let snapshot = try JSONDecoder().decode(CoreSnapshot.self, from: source)
    #expect(snapshot.selectedTarget?.minimumDwellMs == 180_000)
    #expect(snapshot.selectedTarget?.recommendedDwellMs == 21_600_000)
    #expect(snapshot.selectedTarget?.playlist?.status == .pending)

    let command = CoreCommand(kind: .loopPinned, targetID: "paper-1", dwellMs: 21_600_000)
    let decoded = try JSONDecoder().decode(CoreCommand.self, from: JSONEncoder().encode(command))
    #expect(decoded == command)
  }

  @Test("Disconnected state never invents device or generation availability")
  func disconnectedState() {
    let snapshot = CoreSnapshot.disconnected

    #expect(snapshot.targets.isEmpty)
    #expect(snapshot.selectedTargetID == nil)
    #expect(snapshot.generationAvailability == .notConfigured)
  }
}
