import SwiftUI

/// A single entry in the session log
struct SessionLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let icon: String
    let description: String
}

/// Scrollable session log showing chronological events
///
/// Displays timestamps, icons, and descriptions for each session event.
/// Shows an empty state message when no sessions have been recorded.
struct SessionLogView: View {
    let entries: [SessionLogEntry]

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Session Log")
                .font(.headline)
                .padding(.bottom, 8)

            if entries.isEmpty {
                Text("No sessions yet today")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(entries) { entry in
                            HStack(spacing: 8) {
                                Text(timeFormatter.string(from: entry.timestamp))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 45, alignment: .leading)

                                Text(entry.icon)

                                Text(entry.description)
                                    .font(.callout)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
