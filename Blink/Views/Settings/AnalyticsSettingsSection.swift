import SwiftUI

/// Analytics section: info + reset button with confirmation
struct AnalyticsSettingsSection: View {
    @State private var showResetConfirmation = false
    @State private var resetConfirmationText = ""
    @State private var showResetError = false
    @State private var resetErrorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analytics")
                .font(.title2)
                .fontWeight(.semibold)

            // Info callout
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(.secondary)
                Text("Analytics data is stored locally on this Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Reset button
            Button("Reset All Analytics Data...") {
                showResetConfirmation = true
            }
            .foregroundStyle(.red)
        }
        .sheet(isPresented: $showResetConfirmation) {
            ResetConfirmationSheet(
                confirmationText: $resetConfirmationText,
                isPresented: $showResetConfirmation,
                onError: { message in
                    resetErrorMessage = message
                    showResetError = true
                }
            )
        }
        .alert("Reset Failed", isPresented: $showResetError) {
            Button("OK") {}
        } message: {
            Text(resetErrorMessage)
        }
    }
}

/// Confirmation sheet with Liquid Glass styling
private struct ResetConfirmationSheet: View {
    @Binding var confirmationText: String
    @Binding var isPresented: Bool
    let onError: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)

            Text("Reset Analytics Data")
                .font(.headline)

            Text("This will permanently delete all your analytics history. This action cannot be undone.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Type RESET to confirm:")
                .font(.caption)

            TextField("", text: $confirmationText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)

            HStack(spacing: 12) {
                Button("Cancel") {
                    confirmationText = ""
                    isPresented = false
                }

                Button("Delete All Data") {
                    if confirmationText == "RESET" {
                        do {
                            try AnalyticsService.shared.resetAllData()
                            confirmationText = ""
                            isPresented = false
                        } catch {
                            onError(error.localizedDescription)
                        }
                    }
                }
                .disabled(confirmationText != "RESET")
                .foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(width: 350)
        .background(.ultraThinMaterial)
    }
}
