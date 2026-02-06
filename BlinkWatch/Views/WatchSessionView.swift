import SwiftUI

/// Main work session view for the watch
///
/// Displays a circular progress ring with the timer at center,
/// current state label, and action buttons.
struct WatchSessionView: View {
    @ObservedObject var appState = WatchAppState.shared
    @ObservedObject var engine = WatchTimerEngine.shared

    var body: some View {
        VStack(spacing: 8) {
            // Circular progress ring with timer
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)

                // Progress ring
                Circle()
                    .trim(from: 0, to: appState.workProgress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: appState.workProgress)

                // Timer text
                VStack(spacing: 2) {
                    Text(appState.displayTime)
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)

                    Text(stateLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(stateLabelColor)
                }
            }
            .padding(.horizontal, 8)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: { engine.togglePause() }) {
                    Image(systemName: appState.timerState == .workPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.white)

                Button(action: { engine.restartSession() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.white)

                Button(action: { engine.startBreakNow() }) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.purple.opacity(0.8))
            }
        }
    }

    // MARK: - Computed Properties

    private var progressColor: Color {
        switch appState.timerState {
        case .workRunning:
            // Transition from green to orange as work progresses
            return appState.workProgress > 0.8 ? .orange : .green
        case .workPaused:
            return .gray
        default:
            return .purple
        }
    }

    private var stateLabel: String {
        switch appState.timerState {
        case .workRunning: return "Working"
        case .workPaused: return "Paused"
        case .breakRunning: return "Break"
        case .snoozeRunning: return "Snoozed"
        }
    }

    private var stateLabelColor: Color {
        switch appState.timerState {
        case .workRunning: return .green
        case .workPaused: return .gray
        case .breakRunning: return .purple
        case .snoozeRunning: return .orange
        }
    }
}
