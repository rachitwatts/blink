import Foundation

struct EyeHealthInsight: Identifiable, Codable {
    let id: String
    let category: Category
    let severity: Severity
    let title: String
    let description: String
    let icon: String

    enum Category: String, Codable { case pattern, suggestion }
    enum Severity: String, Codable, Comparable {
        case high, medium, low

        private var sortOrder: Int {
            switch self {
            case .high: return 0
            case .medium: return 1
            case .low: return 2
            }
        }

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }
}
