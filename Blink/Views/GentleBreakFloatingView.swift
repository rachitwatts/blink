import SwiftUI

struct GentleBreakFloatingView: View {

    @ObservedObject private var appState = AppState.shared

    @State private var lastEscTime: Date? = nil
    private let doubleEscWindow: TimeInterval = 0.5

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.08, blue: 0.16),
                            Color(red: 0.05, green: 0.05, blue: 0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 16) {
                Spacer()

                Text(formatTime(appState.breakRemainingSeconds))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(.white)

                phaseMessage
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                compactBreakContent

                Spacer()

                buttonRow

                Text("Esc = Snooze  •  Esc Esc = Skip")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .onReceive(NotificationCenter.default.publisher(for: .breakOverlayEscPressed)) { _ in
            handleEscKey()
        }
    }

    // MARK: - Phase Message

    private var phaseMessage: some View {
        Group {
            if appState.breakPhase == .floating {
                Text("Time for a break")
            } else {
                Text("Your eyes need this")
            }
        }
    }

    // MARK: - Compact Break Content

    @ViewBuilder
    private var compactBreakContent: some View {
        switch Settings.shared.breakContentMode {
        case .guided:
            if let exercise = appState.activeBreakExercise {
                VStack(spacing: 8) {
                    Image(systemName: exercise.sfSymbol)
                        .font(.system(size: 24))
                        .foregroundColor(.purple.opacity(0.8))
                    Text(exercise.instruction)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
        case .staticMessage:
            Text("Look away. Blink. Breathe.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        case .none:
            EmptyView()
        }
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        HStack(spacing: 12) {
            Button(action: { TimerEngine.shared.snoozeBreak() }) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Snooze")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button(action: { TimerEngine.shared.skipBreak() }) {
                HStack(spacing: 6) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("Skip")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Esc Handling

    private func handleEscKey() {
        let now = Date()

        if let lastTime = lastEscTime,
           now.timeIntervalSince(lastTime) < doubleEscWindow {
            lastEscTime = nil
            TimerEngine.shared.skipBreak()
        } else {
            lastEscTime = now
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleEscWindow) { [self] in
                if let storedTime = lastEscTime, storedTime == now {
                    lastEscTime = nil
                    TimerEngine.shared.snoozeBreak()
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
