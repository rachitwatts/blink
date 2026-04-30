import SwiftUI
import AppKit

/// Settings view with sidebar navigation and Liquid Glass styling
struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var selectedSection: SettingsSection? = .timer

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(180)
        } detail: {
            // Detail pane
            ScrollView {
                detailContent
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.ultraThinMaterial)
            .animation(.easeInOut(duration: 0.15), value: selectedSection)
        }
        .frame(width: 700, height: 480)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .timer:
            TimerSettingsSection(settings: settings)
        case .general:
            GeneralSettingsSection(settings: settings)
        case .nudges:
            NudgesSettingsSection(settings: settings)
        case .integrations:
            IntegrationsSettingsSection(settings: settings)
        case .advanced:
            AdvancedSettingsSection(settings: settings)
        case .shortcuts:
            ShortcutsSettingsSection()
        case .analytics:
            AnalyticsSettingsSection()
        case .none:
            TimerSettingsSection(settings: settings)
        }
    }
}

#Preview {
    SettingsView()
}
