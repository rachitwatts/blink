import SwiftUI

/// Horizontal slider with inline trailing value label
struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let formatter: (Double) -> String

    init(
        label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        unit: String = "",
        formatter: @escaping (Double) -> String = { "\(Int($0))" }
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.formatter = formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Slider(value: $value, in: range, step: step)

                Text("\(formatter(value))\(unit)")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 50, alignment: .trailing)
            }
        }
    }
}
