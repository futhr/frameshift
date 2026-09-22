import SwiftUI

struct SettingsView: View {
  var body: some View {
    Form {
      LabeledContent("Core connection", value: "Preview only")
      LabeledContent("Generation provider", value: "Not configured")
      Text(
        "Pairing, credentials, background launch, and provider adapters are not enabled in this research slice."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
    }
    .padding(20)
    .frame(width: 440)
  }
}
