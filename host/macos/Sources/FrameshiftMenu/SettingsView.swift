import FrameshiftShell
import ServiceManagement
import SwiftUI

struct SettingsView: View {
  let model: LoginSettingsModel
  let discovery: FrameDiscovery

  var body: some View {
    Form {
      LabeledContent("Core connection", value: "Local Unix socket")
      LabeledContent("Generation provider", value: "Not configured")
      Section("Nearby frames") {
        switch discovery.state {
        case .idle, .searching:
          Text("Searching for frames on this network…")
        case .unavailable:
          Text("Frame discovery is unavailable. Check Local Network access in macOS Settings.")
        case .tooManyResults:
          Text("Too many frame advertisements to show safely.")
        case .ready:
          if discovery.frames.isEmpty {
            Text("No compatible frame advertisements found.")
          }
        }

        ForEach(discovery.frames) { frame in
          LabeledContent(frame.id) {
            Text(frame.introduction.pairMode ? "Physical pair mode available" : "Not in pair mode")
          }
          .accessibilityIdentifier("discovered-frame-\(frame.id)")
        }
        Text(
          "Nearby advertisements are unverified. Pairing checks the frame’s physical QR identity."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Toggle(
        "Launch at Login",
        isOn: Binding(
          get: { model.isEnabled },
          set: { model.setEnabled($0) }
        )
      )
      .accessibilityIdentifier("launch-at-login")
      Text(model.statusText)
        .font(.caption)
        .foregroundStyle(.secondary)
      if model.requiresApproval {
        Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
      }
      if let errorMessage = model.errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }
      Text(
        "Frame pairing and generation providers are configured independently; the local library remains available without either."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
    }
    .padding(20)
    .frame(width: 440)
    .onAppear {
      model.refresh()
      discovery.start()
    }
    .onDisappear { discovery.stop() }
  }
}

@MainActor
final class SystemLoginItemService: LoginItemService {
  var status: LoginItemStatus {
    switch SMAppService.mainApp.status {
    case .enabled: .enabled
    case .requiresApproval: .requiresApproval
    case .notRegistered: .notRegistered
    case .notFound: .unavailable
    @unknown default: .unavailable
    }
  }

  func register() throws {
    try SMAppService.mainApp.register()
  }

  func unregister() throws {
    try SMAppService.mainApp.unregister()
  }
}
