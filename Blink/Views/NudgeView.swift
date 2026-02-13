import SwiftUI

/// Small floating panel view for micro-nudges
///
/// Displays an icon, title, and message with a dismiss action.
/// Styled as a rounded, glassy card matching the app's soothing aesthetic.
struct NudgeView: View {

    let nudgeType: NudgeType
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: nudgeType.iconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.purple.opacity(0.9))
                .frame(width: 36, height: 36)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(nudgeType.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text(nudgeType.message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss nudge")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nudgeType.title) reminder: \(nudgeType.message)")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ForEach(NudgeType.allCases) { type in
            NudgeView(nudgeType: type, onDismiss: {})
                .frame(width: 280, height: 90)
        }
    }
    .padding()
}
