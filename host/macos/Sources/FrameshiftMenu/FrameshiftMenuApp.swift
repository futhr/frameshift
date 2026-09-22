import FrameshiftShell
import SwiftUI

@main
struct FrameshiftMenuApp: App {
  private let model = ShellModel(client: PreviewCoreClient())

  var body: some Scene {
    MenuBarExtra("Frameshift", systemImage: "photo.on.rectangle.angled") {
      FrameshiftPanel(model: model)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
    }
  }
}
