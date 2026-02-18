import SwiftUI

/// Large thumbnail cards for display mode selection
struct ThumbnailPicker: View {
    @Binding var selection: DisplayMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu bar shows")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                ThumbnailCard(
                    mode: .elapsed,
                    mockTime: "12:34",
                    isSelected: selection == .elapsed
                ) {
                    selection = .elapsed
                }

                ThumbnailCard(
                    mode: .remaining,
                    mockTime: "17:26",
                    isSelected: selection == .remaining
                ) {
                    selection = .remaining
                }
            }
        }
    }
}

/// Individual thumbnail card with mock menu bar icon
struct ThumbnailCard: View {
    let mode: DisplayMode
    let mockTime: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Mock menu bar area
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 80, height: 50)
                    .overlay {
                        Text(mockTime)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                    }

                Text(mode == .elapsed ? "Elapsed" : "Remaining")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
