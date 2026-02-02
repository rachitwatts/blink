import SwiftUI

/// Full-screen break overlay content
///
/// Shows countdown timer, calming message, and snooze/skip buttons.
/// Uses a dark gradient background with soft purple glow.
struct BreakOverlayView: View {

    // MARK: - State

    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var timerEngine = TimerEngine.shared

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

            // Content: Timer, message, buttons
            VStack(spacing: 40) {
                Spacer()

                // Large countdown timer
                countdownTimer

                // Calming message
                messageText

                Spacer()

                // Snooze and Skip buttons
                buttonRow

                // Keyboard hints
                hintText

                Spacer()
                    .frame(height: 60)
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
                    Color(red: 0.05, green: 0.05, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft purple glow in center
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Timer Display

    private var countdownTimer: some View {
        Text(formatTime(appState.breakRemainingSeconds))
            .font(.system(size: 80, weight: .light, design: .monospaced))
            .foregroundColor(.white)
            .accessibilityLabel("Time remaining: \(formatTimeAccessible(appState.breakRemainingSeconds))")
    }

    // MARK: - Message

    private var messageText: some View {
        Text("Look away. Blink. Breathe.")
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(.white.opacity(0.7))
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        HStack(spacing: 30) {
            // Snooze button
            Button(action: {
                performSnooze()
            }) {
                Text("Snooze 5 min")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Snooze for 5 minutes")
            .accessibilityHint("Hides overlay temporarily, will return after 5 minutes")

            // Skip button
            Button(action: {
                performSkip()
            }) {
                Text("Skip")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip break")
            .accessibilityHint("Ends break immediately and starts new work session")
        }
    }

    // MARK: - Hints

    private var hintText: some View {
        Text("Esc = Snooze 5 min  •  Esc Esc = Skip")
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.4))
    }

    // MARK: - Actions

    /// Snooze the break with optional animation
    private func performSnooze() {
        if reduceMotion {
            timerEngine.snoozeBreak()
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                timerEngine.snoozeBreak()
            }
        }
    }

    /// Skip the break with optional animation
    private func performSkip() {
        if reduceMotion {
            timerEngine.skipBreak()
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                timerEngine.skipBreak()
            }
        }
    }

    /// Handle Esc key press - implements double-Esc detection
    func handleEscKey() {
        let now = Date()

        if let lastTime = lastEscTime,
           now.timeIntervalSince(lastTime) < doubleEscWindow {
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
