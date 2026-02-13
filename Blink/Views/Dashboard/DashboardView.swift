import SwiftUI

/// Available tabs in the analytics dashboard
enum DashboardTab: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case allTime = "All Time"
}

/// Main dashboard container with tab bar
///
/// Provides navigation between Today, Week, Month, and All Time views.
/// Only Today is implemented in Phase 2; other tabs show placeholders.
struct DashboardView: View {
    @State private var selectedTab: DashboardTab = .today

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedTab == tab
                                    ? Color(nsColor: .controlBackgroundColor)
                                    : Color.clear
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            switch selectedTab {
            case .today:
                TodayView()
            case .week:
                WeekView()
            case .month:
                MonthView()
            case .allTime:
                PlaceholderTabView(title: "All Time", message: "Coming in Phase 4")
            }
        }
    }
}

/// Placeholder for tabs not yet implemented
struct PlaceholderTabView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
