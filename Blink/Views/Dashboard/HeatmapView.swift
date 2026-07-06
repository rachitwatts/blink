import SwiftUI

struct HeatmapDay: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
    let eyeHealthGrade: String?
}

enum HeatmapMode: String, CaseIterable {
    case sessions = "Focus Sessions"
    case eyeHealth = "Eye Health"
}

struct HeatmapView: View {
    let days: [HeatmapDay]
    @Binding var mode: HeatmapMode

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity")
                    .font(.headline)
                Spacer()
                Picker("", selection: $mode) {
                    ForEach(HeatmapMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: 7), spacing: cellSpacing) {
                    ForEach(days) { day in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFor(day))
                            .frame(width: cellSize, height: cellSize)
                            .help(tooltipFor(day))
                    }
                }
            }

            HStack(spacing: 4) {
                Text("Less")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForLevel(level))
                        .frame(width: 10, height: 10)
                }

                Text("More")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.platformControlBackground)
        .cornerRadius(8)
    }

    private func colorFor(_ day: HeatmapDay) -> Color {
        switch mode {
        case .sessions:
            return colorForLevel(min(day.value, 4))
        case .eyeHealth:
            guard let grade = day.eyeHealthGrade else { return colorForLevel(0) }
            switch grade {
            case "A+", "A": return colorForLevel(4)
            case "A-": return colorForLevel(3)
            case "B+", "B": return colorForLevel(2)
            case "C": return colorForLevel(1)
            case "D": return .red.opacity(0.6)
            default: return colorForLevel(0)
            }
        }
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: return Color.platformSeparator.opacity(0.3)
        case 1: return .green.opacity(0.3)
        case 2: return .green.opacity(0.5)
        case 3: return .green.opacity(0.7)
        default: return .green
        }
    }

    private func tooltipFor(_ day: HeatmapDay) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        switch mode {
        case .sessions:
            return "\(formatter.string(from: day.date)): \(day.value) sessions"
        case .eyeHealth:
            return "\(formatter.string(from: day.date)): \(day.eyeHealthGrade ?? "No data")"
        }
    }
}
