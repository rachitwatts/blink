import Foundation

@MainActor
final class BreakContentProvider {

    static let shared = BreakContentProvider()

    private let settings = Settings.shared

    private var lastExercise: BreakExercise?

    private init() {}

    func selectExercise() -> BreakExercise? {
        guard settings.breakContentMode == .guided else { return nil }

        var pool: [BreakExercise] = []
        for exercise in BreakExercise.allCases {
            for _ in 0..<exercise.selectionWeight {
                pool.append(exercise)
            }
        }

        // Remove last-shown exercise to prevent consecutive repeats
        if let last = lastExercise {
            pool.removeAll { $0 == last }
        }

        guard let selected = pool.randomElement() else { return nil }
        lastExercise = selected
        return selected
    }

    func reset() {
        lastExercise = nil
    }
}
