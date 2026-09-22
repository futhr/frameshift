import SwiftUI

struct SettingsView: View {
  var body: some View {
    Form {
      LabeledContent("Core connection", value: "Local Unix socket")
      LabeledContent("Generation provider", value: "Not configured")
      Text(
        "Frame pairing and generation providers are configured independently; the local library remains available without either."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
    }
    .padding(20)
    .frame(width: 440)
  }
}
