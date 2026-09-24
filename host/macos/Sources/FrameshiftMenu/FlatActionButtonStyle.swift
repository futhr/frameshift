import SwiftUI

struct FlatActionButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.callout.weight(.medium))
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(
        .primary.opacity(configuration.isPressed ? 0.12 : 0.05),
        in: RoundedRectangle(cornerRadius: 7)
      )
      .opacity(isEnabled ? 1 : 0.45)
      .contentShape(RoundedRectangle(cornerRadius: 7))
  }
}
