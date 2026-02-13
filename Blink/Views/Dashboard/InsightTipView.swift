import SwiftUI

/// A yellow-tinted banner that displays a contextual eye health tip
///
/// Shown below the session log when the eye health grade is C or below.
struct InsightTipView: View {
    let tip: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.title3)

            Text(tip)
                .font(.callout)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }
}
