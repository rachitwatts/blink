import SwiftUI

struct InCallNudgeView: View {
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye")
                .font(.system(size: 14, weight: .medium))
            Text("Look away from the screen")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }
        }
    }

    func fadeOut(after seconds: Double, completion: @escaping () -> Void) -> some View {
        self.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                withAnimation(.easeOut(duration: 0.5)) {
                    completion()
                }
            }
        }
    }
}
