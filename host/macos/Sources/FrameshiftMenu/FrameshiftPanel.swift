import AppKit
import FrameshiftShell
import SwiftUI
import UniformTypeIdentifiers

struct FrameshiftPanel: View {
  let model: ShellModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      targetPicker
      instructionEditor
      actionRow
      status
      library
    }
    .padding(16)
    .frame(width: 420, height: 560)
    .task { await model.refresh() }
    .alert(
      "Frameshift could not complete that action",
      isPresented: Binding(
        get: { model.errorMessage != nil },
        set: { if !$0 { model.dismissError() } }
      )
    ) {
      Button("OK") { model.dismissError() }
    } message: {
      Text(model.errorMessage ?? "Unknown error")
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Frameshift")
          .font(.title2.weight(.semibold))
        Text("Still artwork, prepared for one frame")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "circle.grid.cross")
        .foregroundStyle(.secondary)
        .accessibilityLabel("Frameshift core")
    }
  }

  private var targetPicker: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("Target")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
      if let selectedTargetID = model.snapshot.selectedTargetID {
        Picker(
          "Target frame",
          selection: Binding(
            get: { selectedTargetID },
            set: { targetID in Task { await model.selectTarget(targetID) } }
          )
        ) {
          ForEach(model.snapshot.targets) { target in
            Text("\(target.medium.label) — \(target.name)").tag(target.id)
          }
        }
        .labelsHidden()
        .accessibilityIdentifier("target-picker")
      } else {
        LabeledContent("Frame", value: "No paired frame")
          .foregroundStyle(.secondary)
      }
      if model.snapshot.selectedTarget?.directDelivery?.status == .pending {
        HStack {
          Label("Direct delivery pending confirmation", systemImage: "clock.arrow.circlepath")
            .font(.caption)
            .foregroundStyle(.orange)
            .accessibilityIdentifier("direct-delivery-pending")
          Spacer()
          Button("Check frame") { Task { await model.reconcileDelivery() } }
            .disabled(model.isBusy)
        }
      }
    }
  }

  private var instructionEditor: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text("Instruction")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
        Spacer()
        if model.snapshot.generationAvailability == .notConfigured {
          Text("No generator configured")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      ZStack(alignment: .topLeading) {
        TextEditor(
          text: Binding(
            get: { model.draftInstruction },
            set: { model.draftInstruction = $0 }
          )
        )
        .font(.body)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .accessibilityLabel("Instruction")
        .accessibilityIdentifier("instruction-editor")

        if model.draftInstruction.isEmpty {
          Text("Describe the still image you want to prepare")
            .foregroundStyle(.tertiary)
            .padding(.leading, 10)
            .padding(.top, 8)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
      }
      .frame(height: 104)
      .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
      .overlay {
        RoundedRectangle(cornerRadius: 7)
          .strokeBorder(.quaternary, lineWidth: 1)
      }
    }
  }

  private var actionRow: some View {
    HStack {
      Button {
        chooseImage()
      } label: {
        Label("Import image", systemImage: "square.and.arrow.down")
      }
      .keyboardShortcut("i", modifiers: .command)

      Button("Save instruction") {
        Task { await model.saveInstruction() }
      }
      .disabled(model.isBusy)

      Spacer()

      if model.isBusy {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel("Working")
      }
    }
  }

  private func chooseImage() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    guard panel.runModal() == .OK, let url = panel.url else { return }
    Task { await model.importFile(url) }
  }

  private var status: some View {
    HStack(spacing: 7) {
      Circle()
        .fill(.orange)
        .frame(width: 7, height: 7)
      Text(model.snapshot.statusMessage)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("core-status")
  }

  @ViewBuilder
  private var library: some View {
    if model.snapshot.items.isEmpty {
      ContentUnavailableView {
        Label("No artwork yet", systemImage: "photo")
      } description: {
        Text("Import a still image. Generation stays disabled until a provider is configured.")
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        LazyVStack(spacing: 10) {
          ForEach(model.snapshot.items) { item in
            ResultCard(
              item: item,
              targetName: model.snapshot.selectedTarget?.name ?? "selected target",
              canQueue: model.snapshot.selectedTarget != nil
                && model.snapshot.selectedTarget?.directDelivery?.status != .pending,
              queue: { Task { await model.queue(item.id) } },
              togglePin: { Task { await model.togglePin(item.id) } },
              remove: { Task { await model.remove(item.id) } }
            )
          }
        }
      }
    }
  }
}

private struct ResultCard: View {
  let item: FrameshiftShell.LibraryItem
  let targetName: String
  let canQueue: Bool
  let queue: () -> Void
  let togglePin: () -> Void
  let remove: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 8)
        .fill(.quaternary)
        .frame(width: 74, height: 58)
        .overlay {
          Image(systemName: "photo")
            .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.headline)
          .lineLimit(1)
        Text(item.queuedTargetID == nil ? "Ready to queue" : "Queued for \(targetName)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button(action: queue) {
        Image(systemName: "paperplane")
      }
      .buttonStyle(.borderless)
      .disabled(!canQueue)
      .help("Queue this still for \(targetName)")
      .accessibilityLabel("Queue \(item.title)")

      Button(action: togglePin) {
        Image(systemName: item.isPinned ? "pin.fill" : "pin")
      }
      .buttonStyle(.borderless)
      .help(item.isPinned ? "Unpin" : "Pin")
      .accessibilityLabel(item.isPinned ? "Unpin \(item.title)" : "Pin \(item.title)")

      Button(role: .destructive, action: remove) {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
      .help("Remove from the library")
      .accessibilityLabel("Remove \(item.title)")
    }
    .padding(10)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 11))
    .accessibilityElement(children: .contain)
  }
}
