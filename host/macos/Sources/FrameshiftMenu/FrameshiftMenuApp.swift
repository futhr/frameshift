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
    MenuBarExtra {
      FrameshiftPanel(model: ShellSession.model)
        .modifier(DockIconAppearance())
    } label: {
      Image(nsImage: MenuBarIcon.image)
        .accessibilityLabel("Frameshift")
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
    }
  }
}

@MainActor
private enum MenuBarIcon {
  static let image: NSImage = {
    let image = NSImage(size: NSSize(width: 18, height: 18))

    for suffix in ["", "@2x", "@3x"] {
      guard let url = Bundle.main.url(forResource: "FrameshiftMenu\(suffix)", withExtension: "png"),
        let data = try? Data(contentsOf: url),
        let representation = NSBitmapImageRep(data: data)
      else { continue }
      representation.size = NSSize(width: 18, height: 18)
      image.addRepresentation(representation)
    }

    if image.representations.isEmpty {
      return NSImage(
        systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: "Frameshift")!
    }

    image.isTemplate = true
    return image
  }()
}

private struct DockIconAppearance: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .onAppear { DockIcon.apply(colorScheme) }
      .onChange(of: colorScheme) { _, appearance in DockIcon.apply(appearance) }
  }
}

@MainActor
private enum DockIcon {
  static func apply(_ appearance: ColorScheme) {
    let name = appearance == .dark ? "FrameshiftDark" : "FrameshiftLight"
    guard let url = Bundle.main.url(forResource: name, withExtension: "icns"),
      let image = NSImage(contentsOf: url)
    else { return }
    NSApplication.shared.applicationIconImage = image
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
          .modifier(DockIconAppearance())
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
