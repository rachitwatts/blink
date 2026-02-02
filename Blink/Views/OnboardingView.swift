import SwiftUI

/// First-launch onboarding view
///
/// Shows a welcome message with key feature highlights.
/// Displayed once on first launch, then never again.
struct OnboardingView: View {

    // MARK: - State

    @ObservedObject private var settings = Settings.shared

    /// Callback when onboarding is completed
    var onComplete: () -> Void = {}

    // MARK: - Body

    var body: some View {
        VStack(spacing: 28) {
            // App icon/logo area
            Image(systemName: "eye")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .padding(.top, 20)

            // Welcome text
            VStack(spacing: 8) {
                Text("Welcome to Blink")
                    .font(.system(size: 28, weight: .semibold))

                Text("Reduce eye strain with regular breaks")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            // Feature highlights
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "clock.fill",
                    title: "25/5 Rhythm",
                    description: "Work for 25 minutes, then take a 5-minute break"
                )

                FeatureRow(
                    icon: "display",
                    title: "Gentle Reminders",
                    description: "Full-screen overlay reminds you to look away"
                )

                FeatureRow(
                    icon: "keyboard",
                    title: "Easy Controls",
                    description: "Press Esc to snooze, double-Esc to skip"
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            // Get Started button
            Button(action: {
                settings.hasCompletedOnboarding = true
                onComplete()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 30)
            .padding(.bottom, 24)
        }
        .frame(width: 380, height: 480)
    }
}

// MARK: - Feature Row

/// A single feature highlight row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
