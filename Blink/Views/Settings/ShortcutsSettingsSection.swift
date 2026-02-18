import SwiftUI
import AppKit

/// Keyboard shortcuts section: read-only display + permission status
struct ShortcutsSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shortcuts")
                .font(.title2)
                .fontWeight(.semibold)

            // Shortcuts grid
            VStack(alignment: .leading, spacing: 12) {
                ShortcutRow(action: "Pause/Resume", keys: "⌘⇧B")
                ShortcutRow(action: "Restart Session", keys: "⌘⇧R")
            }

            Divider()

            // Permission status
            if isAccessibilityEnabled() {
                Label("Shortcuts enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "Accessibility permission required",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    .font(.subheadline)

                    Button("Enable Shortcuts") {
                        requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func isAccessibilityEnabled() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)

        if granted {
            HotkeyManager.shared.startListening()
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

/// Single shortcut row with action label and key combo
private struct ShortcutRow: View {
    let action: String
    let keys: String

    var body: some View {
        HStack {
            Text(action)
                .foregroundStyle(.primary)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
