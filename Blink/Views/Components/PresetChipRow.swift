import SwiftUI

/// Horizontal row of preset value chips with an optional Custom input
struct PresetChipRow: View {
    let label: String
    let presets: [Int]
    @Binding var value: Int
    let unit: String
    let range: ClosedRange<Int>

    @State private var isCustom: Bool = false
    @State private var customText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    ChipButton(
                        title: "\(preset)",
                        isSelected: !isCustom && value == preset
                    ) {
                        isCustom = false
                        value = preset
                    }
                }

                ChipButton(
                    title: "Custom",
                    isSelected: isCustom
                ) {
                    isCustom = true
                    customText = "\(value)"
                }
            }

            // Inline custom input
            if isCustom {
                HStack {
                    TextField("", text: $customText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .onSubmit {
                            if let num = Int(customText), range.contains(num) {
                                value = num
                            } else {
                                customText = "\(value)"
                            }
                        }
                    Text(unit)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
            }
        }
        .onAppear {
            isCustom = !presets.contains(value)
            customText = "\(value)"
        }
        .onChange(of: value) { _, newValue in
            isCustom = !presets.contains(newValue)
            customText = "\(newValue)"
        }
    }
}

/// Individual chip button with Liquid Glass styling
struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.2)
                        : Color.primary.opacity(0.05)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.clear,
                            lineWidth: 1.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
