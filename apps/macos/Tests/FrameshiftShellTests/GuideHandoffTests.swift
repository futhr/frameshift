import Foundation
import FrameshiftShell
import Testing

@Suite("Browser guide handoff")
@MainActor
struct GuideHandoffTests {
  @Test("A bounded class and profile are parsed as a hint")
  func parsesChoice() throws {
    let url = try #require(
      URL(string: "frameshift://setup?v=1&class=photo&profile=urn:frameshift:profile:photo")
    )
    let choice = try #require(GuideHandoff.parse(url))
    #expect(choice.medium == .photo)
    #expect(choice.profileID == "urn:frameshift:profile:photo")

    let paper = try #require(URL(string: "frameshift://setup?v=1&class=paper"))
    #expect(GuideHandoff.parse(paper)?.profileID == nil)
  }

  @Test("Unknown, duplicate, secret, and malformed inputs are rejected")
  func rejectsUnsafeURLs() {
    let invalid = [
      "https://setup?v=1&class=paper",
      "Frameshift://setup?v=1&class=paper",
      "frameshift://elsewhere?v=1&class=paper",
      "frameshift://setup/path?v=1&class=paper",
      "frameshift://user@setup?v=1&class=paper",
      "frameshift://setup:443?v=1&class=paper",
      "frameshift://setup?v=1&class=paper#fragment",
      "frameshift://setup?v=2&class=paper",
      "frameshift://setup?v=1&class=unknown",
      "frameshift://setup?v=1&class=paper&class=photo",
      "frameshift://setup?v=1&class=paper&token=secret",
      "frameshift://setup?v=1&class=paper&profile=",
      "frameshift://setup?v=1&class=paper&profile=private/path",
      "frameshift://setup?v=1&class=paper&profile=%0A",
      "frameshift://setup?v=1&class=paper&profile=\(String(repeating: "a", count: 129))",
      "frameshift://setup?v=1&class=paper&profile=\(String(repeating: "a", count: 500))",
    ]
    for text in invalid {
      if let url = URL(string: text) {
        #expect(GuideHandoff.parse(url) == nil, "Accepted \(text)")
      }
    }
  }

  @Test("A guide URL never changes selected target without an explicit command")
  func leavesTargetSelectionAlone() throws {
    let paper = FrameTarget(
      id: "paper-1", name: "Hallway", medium: .paper,
      profileID: "paper-v1", state: .waitingForContact
    )
    let photo = FrameTarget(
      id: "photo-1", name: "Studio", medium: .photo,
      profileID: "photo-rgb24", state: .displayed
    )
    let snapshot = CoreSnapshot(
      targets: [paper, photo], selectedTargetID: nil, statusMessage: "Ready"
    )
    let model = ShellModel(client: LocalCoreClient(), initialSnapshot: snapshot)
    let url = try #require(
      URL(string: "frameshift://setup?v=1&class=photo&profile=photo-rgb24")
    )
    model.receiveGuideURL(url)

    #expect(model.guideMatchingTargets.map(\.id) == ["photo-1"])
    #expect(model.snapshot.selectedTargetID == nil)

    let invalid = try #require(URL(string: "frameshift://setup?v=1&class=paper&token=secret"))
    model.receiveGuideURL(invalid)
    #expect(model.guideHandoff?.medium == .photo)

    model.dismissGuideHandoff()
    #expect(model.guideHandoff == nil)
  }
}
