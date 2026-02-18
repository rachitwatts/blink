import SwiftUI

/// General section: display mode thumbnails + launch at login
struct GeneralSettingsSection: View {
    @ObservedObject var settings: Settings

    private var displayModeBinding: Binding<DisplayMode> {
        Binding(
            get: { settings.displayMode },
            set: { settings.displayMode = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)

            // Display mode thumbnails (at top)
            ThumbnailPicker(selection: displayModeBinding)

            Divider()

            // Launch at login toggle
            Toggle("Launch Blink at login", isOn: $settings.launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: settings.launchAtLogin) { _, newValue in
                    LaunchAtLoginManager.shared.setEnabled(newValue)
                }
        }
    }
}
