import SwiftUI

/// Full-screen break overlay content
///
/// Shows countdown timer, calming message, and snooze/skip buttons.
/// Uses a dark gradient background with soft purple glow.
/// Observes `AppState.breakRemainingSeconds` for the countdown display.
struct BreakOverlayView: View {

    // MARK: - State

    /// Shared app state - provides breakRemainingSeconds for countdown display
    @ObservedObject private var appState = AppState.shared

    /// Track last Esc press time for double-Esc detection
    @State private var lastEscTime: Date? = nil

    /// Window for double-Esc detection (500ms)
    private let doubleEscWindow: TimeInterval = 0.5

    /// Respect user's reduce motion preference
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background: Dark gradient
            backgroundGradient

            // Content: three equal zones — timer / exercise / buttons
            VStack(spacing: 0) {
                // Top zone: countdown timer
                VStack {
                    Spacer()
                    countdownTimerView
                    Spacer()
                }
                .frame(maxHeight: .infinity)

                // Center zone: exercise content
                VStack {
                    Spacer()
                    breakContent
                    Spacer()
                }
                .frame(maxHeight: .infinity)

                // Bottom zone: buttons and hints
                VStack(spacing: 16) {
                    Spacer()
                    buttonRow
                    hintText
                    Spacer()
                        .frame(height: 48)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .breakOverlayEscPressed)) { _ in
            handleEscKey()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft purple glow in center
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.clear,
                ],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Timer Display

    private var countdownTimerView: some View {
        Text(formatTime(appState.breakRemainingSeconds))
            .font(.system(size: 80, weight: .light, design: .monospaced))
            .foregroundColor(.white)
            .accessibilityLabel(
                "Time remaining: \(formatTimeAccessible(appState.breakRemainingSeconds))")
    }

    // MARK: - Break Content

    @ViewBuilder
    private var breakContent: some View {
        switch Settings.shared.breakContentMode {
        case .guided:
            if let exercise = appState.activeBreakExercise {
                BreakExerciseView(exercise: exercise)
            }
        case .staticMessage:
            Text("Look away. Blink. Breathe.")
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
        case .none:
            EmptyView()
        }
    }

    // MARK: - Buttons

    /// Fixed width for both buttons to ensure visual symmetry
    private let buttonWidth: CGFloat = 140

    private var buttonRow: some View {
        HStack(spacing: 20) {
            // Snooze button
            Button(action: {
                performSnooze()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Snooze")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: buttonWidth)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Snooze for 5 minutes")
            .accessibilityHint("Hides overlay temporarily, will return after 5 minutes")

            // Skip button
            Button(action: {
                performSkip()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("Skip")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .frame(width: buttonWidth)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip break")
            .accessibilityHint("Ends break immediately and starts new work session")
        }
    }

    // MARK: - Hints

    private var hintText: some View {
        Text("Esc = Snooze  •  Esc Esc = Skip")
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.4))
    }

    // MARK: - Actions

    /// Snooze the break
    private func performSnooze() {
        TimerEngine.shared.snoozeBreak()
    }

    /// Skip the break
    private func performSkip() {
        TimerEngine.shared.skipBreak()
    }

    /// Handle Esc key press - implements double-Esc detection
    func handleEscKey() {
        let now = Date()

        if let lastTime = lastEscTime,
            now.timeIntervalSince(lastTime) < doubleEscWindow
        {
            // Double Esc detected - Skip
            print("[BreakOverlay] Double Esc detected, skipping")
            lastEscTime = nil
            performSkip()
        } else {
            // First Esc - wait for potential second
            print("[BreakOverlay] First Esc detected, waiting for second...")
            lastEscTime = now

            // After the window passes, if no second Esc, snooze
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleEscWindow) { [self] in
                // Check if lastEscTime is still our time (no second Esc came)
                if let storedTime = lastEscTime, storedTime == now {
                    print("[BreakOverlay] No second Esc, snoozing")
                    lastEscTime = nil
                    performSnooze()
                }
            }
        }
    }

    // MARK: - Helpers

    /// Format seconds as "m:ss" for display
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format seconds for accessibility (spoken)
    private func formatTimeAccessible(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return "\(minutes) minutes and \(seconds) seconds"
        } else {
            return "\(seconds) seconds"
        }
    }
}

// MARK: - Preview

#Preview {
    BreakOverlayView()
        .frame(width: 800, height: 600)
}
