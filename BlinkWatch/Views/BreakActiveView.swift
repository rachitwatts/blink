import SwiftUI

/// Full-screen break countdown view.
///
/// Shown when a break is active (`timerState == .breakRunning`).
/// Displays a "Take a Break" heading, large monospaced countdown,
/// circular progress ring, and Snooze/Skip action buttons.
struct BreakActiveView: View {
    @ObservedObject var appState: WatchAppState
    let onSnooze: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("Take a Break")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.green)

            // Break countdown with progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)

                // Progress ring (fills as break progresses)
                Circle()
                    .trim(from: 0, to: appState.breakProgress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: appState.breakProgress)

                // Countdown text
                VStack(spacing: 2) {
                    Text(appState.displayTime)
                        .font(.system(size: 32, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(.white)

                    Text("Look away")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)

            // Snooze and Skip controls
            HStack(spacing: 12) {
                Button(action: { onSnooze() }) {
                    Text("Snooze")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button(action: { onSkip() }) {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
    }
}
