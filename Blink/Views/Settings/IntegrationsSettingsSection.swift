import SwiftUI
#if os(macOS)
import EventKit
#endif

struct IntegrationsSettingsSection: View {
    @ObservedObject var settings: Settings
    #if os(macOS)
    @ObservedObject private var calendarMonitor = CalendarMonitor.shared
    #endif

    private var leadTimeBinding: Binding<Double> {
        Binding(
            get: { Double(settings.calendarLeadTimeMinutes) },
            set: { settings.calendarLeadTimeMinutes = Int($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Integrations")
                .font(.title2)
                .fontWeight(.semibold)

            // MARK: - Call Detection

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Detect active calls", isOn: $settings.callDetectionEnabled)
                    .toggleStyle(.switch)

                Text("During audio or video calls, Blink shows a subtle \"look away\" reminder instead of the full break overlay. Screen sharing fully suppresses breaks until you stop sharing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if os(macOS)
            Divider()

            // MARK: - Calendar Integration

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Calendar integration", isOn: $settings.calendarIntegrationEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: settings.calendarIntegrationEnabled) { _, enabled in
                        if enabled {
                            requestCalendarAccess()
                        }
                    }

                Text("Shifts breaks earlier when a meeting is about to start, so you take your break before joining.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.calendarIntegrationEnabled {
                    calendarDetails
                }
            }
            #endif
        }
    }

    #if os(macOS)
    @ViewBuilder
    private var calendarDetails: some View {
        let status = calendarMonitor.authorizationStatus

        if status == .denied || status == .restricted {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Calendar access denied. Grant access in System Settings → Privacy & Security → Calendars.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if status == .fullAccess {
            VStack(alignment: .leading, spacing: 12) {
                LabeledSlider(
                    label: "Shift break if meeting starts within",
                    value: leadTimeBinding,
                    in: 1...10,
                    step: 1,
                    unit: "min"
                )

                if !calendarMonitor.availableCalendars.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Calendars to watch")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Leave all unchecked to watch all calendars.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        let watchedIDs = parseWatchedIDs()
                        ForEach(calendarMonitor.availableCalendars, id: \.calendarIdentifier) { calendar in
                            Toggle(calendar.title, isOn: Binding(
                                get: { watchedIDs.contains(calendar.calendarIdentifier) },
                                set: { checked in
                                    toggleCalendar(calendar.calendarIdentifier, checked: checked)
                                }
                            ))
                            .toggleStyle(.checkbox)
                        }
                    }
                }
            }
        } else {
            Text("Requesting calendar access…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func requestCalendarAccess() {
        Task {
            let granted = await calendarMonitor.requestAccess()
            if granted {
                calendarMonitor.refreshCalendars()
                calendarMonitor.refreshEvents()
            } else {
                await MainActor.run {
                    settings.calendarIntegrationEnabled = false
                }
            }
        }
    }

    private func parseWatchedIDs() -> Set<String> {
        let raw = settings.watchedCalendarIdentifiers
        guard !raw.isEmpty else { return [] }
        return Set(raw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    private func toggleCalendar(_ id: String, checked: Bool) {
        var ids = parseWatchedIDs()
        if checked {
            ids.insert(id)
        } else {
            ids.remove(id)
        }
        settings.watchedCalendarIdentifiers = ids.sorted().joined(separator: ",")
    }
    #endif
}
