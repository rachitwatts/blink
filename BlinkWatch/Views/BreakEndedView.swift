import SwiftUI

/// Shown when the break countdown reaches zero.
///
/// Displays a laptop icon, "Break's Over" heading, and a dismiss button.
/// The parent view is responsible for starting escalating haptics when
/// this view appears and stopping them when the user taps Dismiss.
struct BreakEndedView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Break's Over")
                .font(.headline)

            Text("Back to work!")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Dismiss") { onDismiss() }
                .buttonStyle(.borderedProminent)
        }
    }
}
