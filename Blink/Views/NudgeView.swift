import SwiftUI

/// Slide-in nudge panel shown during work sessions
///
/// Displays a micro nudge message with icon and progress bar.
/// Uses a dark gradient background with off-white text — always dark,
/// regardless of system appearance.
/// Auto-dismisses after 6 seconds. Click to dismiss early.
/// Right-click to pause nudges for the session.
///
/// Two modes:
/// - **Preview mode**: Pass nudgeType and optionally initialProgress for Xcode previews
/// - **Runtime mode**: Timer auto-depletes progress over 6 seconds, hover pauses
struct NudgeView: View {

    // MARK: - Properties

    /// The nudge type to display
    let nudgeType: NudgeType

    /// Progress for auto-dismiss bar (1.0 -> 0.0 over 6 seconds)
    @State private var progress: Double

    /// Whether mouse is hovering (pauses auto-dismiss)
    @State private var isHovering: Bool = false

    /// Timer for auto-dismiss countdown
    @State private var dismissTimer: Timer? = nil

    /// Duration before auto-dismiss
    private let dismissDuration: TimeInterval = 6.0

    /// Update interval for progress bar (60fps)
    private let progressUpdateInterval: TimeInterval = 1.0 / 60.0

    /// Whether this view is in preview mode (no timer, no dismiss)
    private let isPreview: Bool

    // MARK: - Colors

    private let offWhite = Color(white: 0.9)
    private let offWhiteSecondary = Color(white: 0.65)
    private let progressColor = Color(red: 0.45, green: 0.55, blue: 0.95)

    // MARK: - Initialization

    /// Runtime initializer — reads from AppState, manages its own timer
    init(nudgeType: NudgeType) {
        self.nudgeType = nudgeType
        self._progress = State(initialValue: 1.0)
        self.isPreview = false
    }

    /// Preview initializer — static display with fixed progress
    init(nudgeType: NudgeType, progress: Double) {
        self.nudgeType = nudgeType
        self._progress = State(initialValue: progress)
        self.isPreview = true
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 12) {
                // Icon
                Image(systemName: nudgeType.sfSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(offWhiteSecondary)
                    .frame(width: 24, alignment: .center)

                // Message
                Text(nudgeType.displayMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(offWhite)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            // Progress bar
            GeometryReader { geometry in
                Rectangle()
                    .fill(progressColor.opacity(0.7))
                    .frame(width: geometry.size.width * max(0, progress), height: 2.5)
                    .animation(.linear, value: progress)
            }
            .frame(height: 2.5)
        }
        .frame(width: 300)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.18),
                    Color(red: 0.08, green: 0.08, blue: 0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture {
            guard !isPreview else { return }
            dismissWithMethod("click")
        }
        .contextMenu {
            if !isPreview {
                Button("Pause nudges for this session") {
                    dismissWithMethod("pause")
                    NudgeScheduler.shared.pauseNudgesForSession()
                }
            }
        }
        .onHover { hovering in
            guard !isPreview else { return }
            isHovering = hovering
        }
        .onAppear {
            guard !isPreview else { return }
            startDismissTimer()
        }
        .onDisappear {
            guard !isPreview else { return }
            stopDismissTimer()
        }
    }

    // MARK: - Timer Management

    private func startDismissTimer() {
        progress = 1.0
        dismissTimer = Timer.scheduledTimer(withTimeInterval: progressUpdateInterval, repeats: true) { _ in
            Task { @MainActor in
                guard !isHovering else { return }

                let decrement = progressUpdateInterval / dismissDuration
                progress = max(0, progress - decrement)

                if progress <= 0 {
                    dismissWithMethod("auto")
                }
            }
        }
    }

    private func stopDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    private func dismissWithMethod(_ method: String) {
        stopDismissTimer()
        AnalyticsService.shared.recordNudgeDismissed(type: nudgeType, method: method)
        NudgeScheduler.shared.dismissNudge()
    }
}

// MARK: - Previews

#Preview("Blink Nudge") {
    NudgeView(nudgeType: .blink, progress: 0.75)
        .padding(40)
}

#Preview("Posture Nudge") {
    NudgeView(nudgeType: .posture, progress: 0.5)
        .padding(40)
}

#Preview("Neck Stretch Nudge") {
    NudgeView(nudgeType: .neckStretch, progress: 0.25)
        .padding(40)
}

#Preview("All Nudge Types") {
    VStack(spacing: 20) {
        NudgeView(nudgeType: .blink, progress: 1.0)
        NudgeView(nudgeType: .posture, progress: 0.6)
        NudgeView(nudgeType: .neckStretch, progress: 0.2)
    }
    .padding(40)
}

#Preview("Progress States") {
    VStack(spacing: 16) {
        NudgeView(nudgeType: .blink, progress: 1.0)
        NudgeView(nudgeType: .blink, progress: 0.5)
        NudgeView(nudgeType: .blink, progress: 0.1)
        NudgeView(nudgeType: .blink, progress: 0.0)
    }
    .padding(40)
}
