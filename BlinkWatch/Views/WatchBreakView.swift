import SwiftUI

/// Break countdown view for the watch
///
/// Shown when a break is triggered. Displays a countdown timer
/// with snooze and skip controls. Uses the watch's haptic engine
/// for notifications.
struct WatchBreakView: View {
    @ObservedObject var appState = WatchAppState.shared
    @ObservedObject var engine = WatchTimerEngine.shared

    var body: some View {
        VStack(spacing: 6) {
            // Break countdown
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)

                // Progress ring (fills as break progresses)
                Circle()
                    .trim(from: 0, to: appState.breakProgress)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: appState.breakProgress)

                // Countdown
                VStack(spacing: 2) {
                    Text(appState.displayTime)
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)

                    Text("Look away")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.purple.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)

            // Controls
            HStack(spacing: 12) {
                Button(action: { engine.snoozeBreak() }) {
                    Text("Snooze")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button(action: { engine.skipBreak() }) {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
    }
}
