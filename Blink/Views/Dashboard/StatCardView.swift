import SwiftUI

/// Reusable stat card component for the dashboard
///
/// Displays a large numeric value with a label and optional sublabel.
/// Used in TodayView to show focus time, session count, etc.
struct StatCardView: View {
    let value: String
    let label: String
    let sublabel: String?

    init(value: String, label: String, sublabel: String? = nil) {
        self.value = value
        self.label = label
        self.sublabel = sublabel
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            if let sublabel = sublabel {
                Text(sublabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 100, maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.platformControlBackground)
        .cornerRadius(8)
    }
}
