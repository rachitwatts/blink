import SwiftUI

struct VisionTimerView: View {

    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var timerEngine = TimerEngine.shared
    @ObservedObject private var settings = Settings.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if appState.isOverlayVisible {
                breakView
            } else {
                timerView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isOverlayVisible)
    }

    // MARK: - Timer View (Work State)

    private var timerView: some View {
        VStack(spacing: 40) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: appState.workProgress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: appState.workProgress)

                VStack(spacing: 4) {
                    Text(appState.displayTime)
                        .font(.system(size: 52, weight: .light, design: .monospaced))

                    Text(stateLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Button {
                    timerEngine.togglePause()
                } label: {
                    Image(systemName: appState.timerState == .workPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                }
                .disabled(appState.timerState == .breakRunning || appState.timerState == .snoozeRunning)
                .help(appState.timerState == .workPaused ? "Resume" : "Pause")

                Button {
                    timerEngine.startBreakNow()
                } label: {
                    Image(systemName: "eye.fill")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                }
                .disabled(appState.timerState == .breakRunning)
                .help("Take a break")

                Button {
                    timerEngine.restartSession()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                }
                .help("Restart session")

                Button {
                    openWindow(id: "volumetric-timer")
                    dismissWindow(id: "main-timer")
                } label: {
                    Image(systemName: "cube")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                }
                .help("Open 3D timer")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Break View

    private var breakView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "eye")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Take a Break")
                .font(.title)
                .fontWeight(.semibold)

            Text(TimeFormatting.formatTime(appState.breakRemainingSeconds))
                .font(.system(size: 52, weight: .light, design: .monospaced))

            if let exercise = appState.activeBreakExercise {
                VStack(spacing: 8) {
                    Text(exercise.title)
                        .font(.headline)
                    Text(exercise.instruction)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .padding(.top, 8)
            }

            HStack(spacing: 16) {
                Button {
                    timerEngine.snoozeBreak()
                } label: {
                    Label("Snooze", systemImage: "clock.arrow.circlepath")
                }

                Button {
                    timerEngine.skipBreak()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Helpers

    private var progressColor: Color {
        let progress = appState.workProgress
        if progress < 0.7 { return .blue }
        if progress < 0.9 { return .orange }
        return .red
    }

    private var stateLabel: String {
        switch appState.timerState {
        case .workRunning: return "Working"
        case .workPaused: return "Paused"
        case .breakRunning: return "Break"
        case .snoozeRunning: return "Snoozed"
        }
    }
}
