import AppKit
import FrameshiftShell
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  let model: LoginSettingsModel
  let discovery: FrameDiscovery
  let pairing: PairingSettingsModel
  let shell: ShellModel

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
          HStack {
            VStack(alignment: .leading) {
              Text(frame.id)
              Text(
                frame.introduction.pairMode ? "Physical pair mode available" : "Not in pair mode"
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
            Spacer()
            if frame.introduction.pairMode {
              Button("Pair…") { choosePairingImage(for: frame) }
                .disabled(pairing.isBusy)
                .accessibilityLabel("Pair frame \(frame.id)")
            }
          }
          .accessibilityIdentifier("discovered-frame-\(frame.id)")
        }
        if pairing.isBusy {
          ProgressView("Pairing frame…")
        }
        if let status = pairing.statusMessage {
          Text(status)
            .font(.caption)
        }
        if let error = pairing.errorMessage {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
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

  private func choosePairingImage(for frame: DiscoveredFrame) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.message = "Choose an image of the physical QR label on \(frame.id)."
    panel.begin { response in
      guard response == .OK, let url = panel.url else { return }
      Task { @MainActor in
        let bootstrap: String
        do {
          bootstrap = try await Task.detached(priority: .userInitiated) {
            try PairingQRReader.read(url)
          }.value
        } catch {
          pairing.reportInvalidQR()
          return
        }
        guard confirmPhysicalQR(for: frame, imageURL: url) else { return }
        if await pairing.pair(frame: frame, bootstrap: bootstrap, discovery: discovery) {
          await shell.refresh()
        }
      }
    }
  }

  private func confirmPhysicalQR(for frame: DiscoveredFrame, imageURL: URL) -> Bool {
    let alert = NSAlert()
    alert.messageText = "Confirm the physical frame label"
    alert.informativeText =
      "Pair \(frame.id) using this QR label? Check that it is attached to the frame and physical pair mode is active."
    alert.addButton(withTitle: "Pair frame")
    alert.addButton(withTitle: "Cancel")
    if let image = NSImage(contentsOf: imageURL) {
      let preview = NSImageView(frame: NSRect(x: 0, y: 0, width: 160, height: 160))
      preview.image = image
      preview.imageScaling = .scaleProportionallyUpOrDown
      preview.setAccessibilityLabel("Selected physical pairing QR image")
      alert.accessoryView = preview
    }
    return alert.runModal() == .alertFirstButtonReturn
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
