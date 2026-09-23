import FrameshiftShell
import ServiceManagement
import SwiftUI

struct SettingsView: View {
  let model: LoginSettingsModel

  var body: some View {
    Form {
      LabeledContent("Core connection", value: "Local Unix socket")
      LabeledContent("Generation provider", value: "Not configured")
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
    .onAppear { model.refresh() }
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
