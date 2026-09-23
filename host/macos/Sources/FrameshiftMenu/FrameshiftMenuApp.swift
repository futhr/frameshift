import AppKit
import FrameshiftShell
import SwiftUI

@MainActor
private enum ShellSession {
  static let model = ShellModel(client: LocalCoreClient())
}

@main
struct FrameshiftMenuApp: App {
  @NSApplicationDelegateAdaptor(FrameshiftAppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra("Frameshift", systemImage: "photo.on.rectangle.angled") {
      FrameshiftPanel(model: ShellSession.model)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
    }
  }
}

@MainActor
private final class FrameshiftAppDelegate: NSObject, NSApplicationDelegate {
  private var mainWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    _ = notification
    showMainWindow()
    Task {
      _ = try? await LocalCoreClient().snapshot()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    _ = sender
    _ = hasVisibleWindows
    showMainWindow()
    return true
  }

  private func showMainWindow() {
    if mainWindow == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered,
        defer: false
      )
      window.title = "Frameshift"
      window.isReleasedWhenClosed = false
      window.contentView = NSHostingView(
        rootView: FrameshiftPanel(model: ShellSession.model)
      )
      window.center()
      mainWindow = window
    }

    mainWindow?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
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
