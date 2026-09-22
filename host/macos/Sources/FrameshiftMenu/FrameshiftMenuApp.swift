import AppKit
import FrameshiftShell
import SwiftUI

@main
struct FrameshiftMenuApp: App {
  @NSApplicationDelegateAdaptor(FrameshiftAppDelegate.self) private var appDelegate
  private let model = ShellModel(client: LocalCoreClient())

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

@MainActor
private final class FrameshiftAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    _ = notification
    Task {
      _ = try? await LocalCoreClient().snapshot()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    _ = notification
    let stopped = DispatchSemaphore(value: 0)
    Task {
      await LocalCoreClient.shutdownBundledCore()
      stopped.signal()
    }
    _ = stopped.wait(timeout: .now() + 1)
  }
}
