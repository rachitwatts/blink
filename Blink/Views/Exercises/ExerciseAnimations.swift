import SwiftUI

// MARK: - Palming

struct PalmingAnimation: View {
    @State private var glowPhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Warm radial glow that breathes
                let breathe = reduceMotion ? 0.5 : (sin(t * 0.8) * 0.5 + 0.5)
                let baseRadius: CGFloat = 40
                let maxRadius: CGFloat = 80

                for i in stride(from: 5, through: 0, by: -1) {
                    let fraction = CGFloat(i) / 5.0
                    let radius = baseRadius + (maxRadius - baseRadius) * fraction + CGFloat(breathe) * 15
                    let opacity = (1.0 - fraction) * 0.15 * (0.6 + breathe * 0.4)
                    let color = Color(
                        red: 1.0,
                        green: 0.7 + fraction * 0.15,
                        blue: 0.3 + fraction * 0.3
                    ).opacity(opacity)

                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color)
                    )
                }

                // Center warm core
                let coreRadius: CGFloat = 8 + CGFloat(breathe) * 4
                let coreRect = CGRect(
                    x: center.x - coreRadius,
                    y: center.y - coreRadius,
                    width: coreRadius * 2,
                    height: coreRadius * 2
                )
                context.fill(
                    Path(ellipseIn: coreRect),
                    with: .color(.orange.opacity(0.6 + breathe * 0.3))
                )
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - 20-20-20 Focus Shift

struct FocusShiftAnimation: View {
    @State private var phase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background concentric rings
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: CGFloat(40 + i * 35), height: CGFloat(40 + i * 35))
            }

            // Focus dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .white.opacity(0.3)],
                        center: .center,
                        startRadius: 0,
                        endRadius: phase == 0 ? 20 : 6
                    )
                )
                .frame(width: phase == 0 ? 40 : 12, height: phase == 0 ? 40 : 12)
                .blur(radius: phase == 0 ? 0 : 2)
                .scaleEffect(phase == 0 ? 1.0 : 0.4)
                .animation(reduceMotion ? .none : .easeInOut(duration: 2.5), value: phase)

            // Distance label
            Text(phase == 0 ? "near" : "far")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 65)
                .animation(reduceMotion ? .none : .easeInOut(duration: 1.0), value: phase)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            phase = phase == 0 ? 1 : 0
        }
    }
}

// MARK: - Slow Blinks

struct SlowBlinksAnimation: View {
    @State private var lidPosition: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()
    @State private var blinkPhase: Int = 0

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let eyeWidth: CGFloat = 100
                let eyeHeight: CGFloat = 40
                let lidClose = lidPosition

                // Draw eye white (almond shape)
                let eyePath = Path { path in
                    path.move(to: CGPoint(x: center.x - eyeWidth / 2, y: center.y))
                    path.addQuadCurve(
                        to: CGPoint(x: center.x + eyeWidth / 2, y: center.y),
                        control: CGPoint(x: center.x, y: center.y - eyeHeight)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: center.x - eyeWidth / 2, y: center.y),
                        control: CGPoint(x: center.x, y: center.y + eyeHeight)
                    )
                }

                context.fill(eyePath, with: .color(.white.opacity(0.15)))
                context.stroke(eyePath, with: .color(.white.opacity(0.5)), lineWidth: 2)

                // Iris
                let irisRadius: CGFloat = 14 * (1 - lidClose * 0.5)
                let irisRect = CGRect(
                    x: center.x - irisRadius,
                    y: center.y - irisRadius,
                    width: irisRadius * 2,
                    height: irisRadius * 2
                )
                context.fill(
                    Path(ellipseIn: irisRect),
                    with: .color(Color(red: 0.4, green: 0.5, blue: 0.8).opacity(1 - lidClose))
                )

                // Pupil
                let pupilRadius: CGFloat = 6 * (1 - lidClose * 0.5)
                let pupilRect = CGRect(
                    x: center.x - pupilRadius,
                    y: center.y - pupilRadius,
                    width: pupilRadius * 2,
                    height: pupilRadius * 2
                )
                context.fill(
                    Path(ellipseIn: pupilRect),
                    with: .color(.black.opacity(1 - lidClose))
                )

                // Upper eyelid (closes over eye)
                let lidPath = Path { path in
                    path.move(to: CGPoint(x: center.x - eyeWidth / 2, y: center.y))
                    path.addQuadCurve(
                        to: CGPoint(x: center.x + eyeWidth / 2, y: center.y),
                        control: CGPoint(x: center.x, y: center.y - eyeHeight)
                    )
                    let lidControl = center.y - eyeHeight + (eyeHeight * 2) * lidClose
                    path.addQuadCurve(
                        to: CGPoint(x: center.x - eyeWidth / 2, y: center.y),
                        control: CGPoint(x: center.x, y: lidControl)
                    )
                }
                context.fill(lidPath, with: .color(Color(red: 0.08, green: 0.06, blue: 0.15)))
                context.stroke(lidPath, with: .color(.white.opacity(0.5)), lineWidth: 2)
            }

            // Phase text
            Text(blinkPhase == 1 ? "close…" : blinkPhase == 2 ? "hold…" : "open")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 55)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            runBlinkCycle()
        }
        .onAppear { runBlinkCycle() }
    }

    private func runBlinkCycle() {
        let anim: Animation? = reduceMotion ? nil : .easeInOut(duration: 1.2)
        blinkPhase = 1
        withAnimation(anim) { lidPosition = 1.0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            blinkPhase = 2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            blinkPhase = 0
            withAnimation(anim) { lidPosition = 0.0 }
        }
    }
}

// MARK: - Eye Circles

struct EyeCirclesAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let speed: Double = reduceMotion ? 0 : 0.5
            let angle = t * speed * .pi * 2

            ZStack {
                // Orbit path
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                    .frame(width: 120, height: 120)

                // Trailing dots
                ForEach(0..<6, id: \.self) { i in
                    let trailAngle = angle - Double(i) * 0.15
                    let x = cos(trailAngle) * 60
                    let y = sin(trailAngle) * 60
                    Circle()
                        .fill(Color.white.opacity(0.5 - Double(i) * 0.08))
                        .frame(width: CGFloat(12 - i * 2), height: CGFloat(12 - i * 2))
                        .offset(x: x, y: y)
                }

                // Lead dot with glow
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .purple.opacity(0.6), radius: 8)
                    .offset(x: cos(angle) * 60, y: sin(angle) * 60)
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Figure Eight

struct FigureEightAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let speed: Double = reduceMotion ? 0 : 0.4

            ZStack {
                // Figure 8 path (lemniscate)
                InfinityShape()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                    .frame(width: 140, height: 70)

                // Trailing dots on lemniscate path
                ForEach(0..<5, id: \.self) { i in
                    let trailT = t * speed - Double(i) * 0.08
                    let pos = lemniscatePoint(t: trailT, width: 140, height: 70)
                    Circle()
                        .fill(Color.white.opacity(0.5 - Double(i) * 0.09))
                        .frame(width: CGFloat(10 - i * 2), height: CGFloat(10 - i * 2))
                        .offset(x: pos.x, y: pos.y)
                }

                // Lead dot
                let pos = lemniscatePoint(t: t * speed, width: 140, height: 70)
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .indigo.opacity(0.6), radius: 8)
                    .offset(x: pos.x, y: pos.y)
            }
        }
        .frame(width: 180, height: 180)
    }

    private func lemniscatePoint(t: Double, width: CGFloat, height: CGFloat) -> CGPoint {
        let angle = t * .pi * 2
        let denominator = 1 + sin(angle) * sin(angle)
        let x = cos(angle) / denominator * Double(width / 2)
        let y = sin(angle) * cos(angle) / denominator * Double(height / 2)
        return CGPoint(x: x, y: y)
    }
}

struct InfinityShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 100
        for i in 0...steps {
            let t = Double(i) / Double(steps) * .pi * 2
            let denom = 1 + sin(t) * sin(t)
            let x = rect.midX + cos(t) / denom * rect.width / 2
            let y = rect.midY + sin(t) * cos(t) / denom * rect.height / 2
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Near-Far Focus

struct NearFarFocusAnimation: View {
    @State private var isNear: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Far circle (background)
            Circle()
                .stroke(Color.white.opacity(isNear ? 0.1 : 0.5), lineWidth: isNear ? 1 : 2)
                .frame(width: 100, height: 100)
                .blur(radius: isNear ? 4 : 0)
                .animation(reduceMotion ? .none : .easeInOut(duration: 2.0), value: isNear)

            // Near circle (foreground)
            Circle()
                .stroke(Color.white.opacity(isNear ? 0.6 : 0.1), lineWidth: isNear ? 2.5 : 1)
                .frame(width: 40, height: 40)
                .blur(radius: isNear ? 0 : 3)
                .scaleEffect(isNear ? 1.0 : 0.8)
                .animation(reduceMotion ? .none : .easeInOut(duration: 2.0), value: isNear)

            // Center dot
            Circle()
                .fill(.white.opacity(isNear ? 0.7 : 0.15))
                .frame(width: 6, height: 6)
                .animation(reduceMotion ? .none : .easeInOut(duration: 2.0), value: isNear)

            // Label
            Text(isNear ? "near" : "far")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 70)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.5), value: isNear)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            isNear.toggle()
        }
    }
}

// MARK: - Eye Squeeze

struct EyeSqueezeAnimation: View {
    @State private var phase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Eye shape that squeezes and opens
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let squeezeAmount: CGFloat = phase == 1 ? 1.0 : 0.0
                let wideAmount: CGFloat = phase == 2 ? 1.0 : 0.0

                let eyeWidth: CGFloat = 90
                let baseHeight: CGFloat = 35
                let eyeHeight = baseHeight * (1 - squeezeAmount * 0.85) + wideAmount * 12
                let lineWidth: CGFloat = 2 + squeezeAmount * 2 - wideAmount * 0.5

                // Upper lid
                let upperPath = Path { path in
                    path.move(to: CGPoint(x: center.x - eyeWidth / 2, y: center.y))
                    path.addQuadCurve(
                        to: CGPoint(x: center.x + eyeWidth / 2, y: center.y),
                        control: CGPoint(x: center.x, y: center.y - eyeHeight)
                    )
                }

                // Lower lid
                let lowerPath = Path { path in
                    path.move(to: CGPoint(x: center.x - eyeWidth / 2, y: center.y))
                    path.addQuadCurve(
                        to: CGPoint(x: center.x + eyeWidth / 2, y: center.y),
                        control: CGPoint(x: center.x, y: center.y + eyeHeight)
                    )
                }

                let opacity = 0.5 + squeezeAmount * 0.3
                context.stroke(upperPath, with: .color(.white.opacity(opacity)), lineWidth: lineWidth)
                context.stroke(lowerPath, with: .color(.white.opacity(opacity)), lineWidth: lineWidth)

                // Iris (visible when not squeezed)
                if squeezeAmount < 0.5 {
                    let irisAlpha = 1 - squeezeAmount * 2
                    let irisRadius: CGFloat = 12 + wideAmount * 4
                    let irisRect = CGRect(
                        x: center.x - irisRadius,
                        y: center.y - irisRadius,
                        width: irisRadius * 2,
                        height: irisRadius * 2
                    )
                    context.fill(
                        Path(ellipseIn: irisRect),
                        with: .color(Color(red: 0.4, green: 0.5, blue: 0.8).opacity(irisAlpha))
                    )
                }
            }

            Text(phase == 1 ? "squeeze…" : phase == 2 ? "open wide" : "relax")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 55)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            runSqueezeCycle()
        }
        .onAppear { runSqueezeCycle() }
    }

    private func runSqueezeCycle() {
        let anim: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.6)
        withAnimation(anim) { phase = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(anim) { phase = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(anim) { phase = 0 }
        }
    }
}

// MARK: - Deep Eye Rest

struct DeepEyeRestAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Soft breathing glow
                let breathe = reduceMotion ? 0.5 : (sin(t * 0.6) * 0.5 + 0.5)

                // Moon
                let moonRadius: CGFloat = 16
                let moonRect = CGRect(
                    x: center.x - moonRadius,
                    y: center.y - 20 - moonRadius,
                    width: moonRadius * 2,
                    height: moonRadius * 2
                )
                context.fill(
                    Path(ellipseIn: moonRect),
                    with: .color(.white.opacity(0.3 + breathe * 0.2))
                )

                // Moon glow
                let glowRadius: CGFloat = 30 + breathe * 10
                let glowRect = CGRect(
                    x: center.x - glowRadius,
                    y: center.y - 20 - glowRadius,
                    width: glowRadius * 2,
                    height: glowRadius * 2
                )
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(.indigo.opacity(0.08 + breathe * 0.05))
                )

                // Floating particles (stars)
                for i in 0..<8 {
                    let seed = Double(i) * 1.7
                    let px = center.x + CGFloat(cos(seed * 3.1 + t * 0.2) * 60)
                    let py = center.y + CGFloat(sin(seed * 2.3 + t * 0.15) * 50)
                    let starAlpha = reduceMotion ? 0.3 : (sin(t * 0.8 + seed) * 0.2 + 0.3)
                    let starSize: CGFloat = reduceMotion ? 2 : CGFloat(1.5 + sin(t + seed) * 1)
                    let rect = CGRect(x: px - starSize, y: py - starSize, width: starSize * 2, height: starSize * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(starAlpha)))
                }
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Deep Breathing (4-4-6)

struct DeepBreathingAnimation: View {
    @State private var breathPhase: BreathPhase = .inhale
    @State private var circleScale: CGFloat = 0.4
    @State private var phaseTimer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum BreathPhase: String {
        case inhale, holdIn, exhale

        var label: String {
            switch self {
            case .inhale: return "breathe in"
            case .holdIn: return "hold"
            case .exhale: return "breathe out"
            }
        }

        var duration: TimeInterval {
            switch self {
            case .inhale: return 4
            case .holdIn: return 4
            case .exhale: return 6
            }
        }

        var next: BreathPhase {
            switch self {
            case .inhale: return .holdIn
            case .holdIn: return .exhale
            case .exhale: return .inhale
            }
        }
    }

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                .frame(width: 140, height: 140)

            // Breathing circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.indigo.opacity(0.4),
                            Color.purple.opacity(0.15),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .scaleEffect(circleScale)

            // Inner circle border
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                .frame(width: 140, height: 140)
                .scaleEffect(circleScale)

            // Phase label
            Text(breathPhase.label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.5), value: breathPhase)
        }
        .frame(width: 180, height: 180)
        .onAppear { startBreathCycle() }
        .onDisappear { phaseTimer?.invalidate() }
    }

    private func startBreathCycle() {
        transitionTo(.inhale)
    }

    private func transitionTo(_ phase: BreathPhase) {
        breathPhase = phase
        let targetScale: CGFloat
        switch phase {
        case .inhale: targetScale = 1.0
        case .holdIn: targetScale = 1.0
        case .exhale: targetScale = 0.4
        }

        withAnimation(reduceMotion ? .none : .easeInOut(duration: phase.duration)) {
            circleScale = targetScale
        }

        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: phase.duration, repeats: false) { _ in
            DispatchQueue.main.async {
                transitionTo(phase.next)
            }
        }
    }
}

// MARK: - Box Breathing (4-4-4-4)

struct BoxBreathingAnimation: View {
    @State private var boxPhase: Int = 0
    @State private var dotProgress: CGFloat = 0
    @State private var phaseTimer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let phaseDuration: TimeInterval = 4.0
    private let boxSize: CGFloat = 100
    private let labels = ["breathe in", "hold", "breathe out", "hold"]

    var body: some View {
        ZStack {
            // Box outline
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                .frame(width: boxSize, height: boxSize)

            // Completed edges
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let half = boxSize / 2
                let corners = [
                    CGPoint(x: center.x - half, y: center.y + half),   // bottom-left (start)
                    CGPoint(x: center.x - half, y: center.y - half),   // top-left
                    CGPoint(x: center.x + half, y: center.y - half),   // top-right
                    CGPoint(x: center.x + half, y: center.y + half),   // bottom-right
                ]

                // Draw completed edges
                for i in 0..<boxPhase {
                    let from = corners[i % 4]
                    let to = corners[(i + 1) % 4]
                    var path = Path()
                    path.move(to: from)
                    path.addLine(to: to)
                    context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 2)
                }

                // Draw current edge progress
                let from = corners[boxPhase % 4]
                let to = corners[(boxPhase + 1) % 4]
                let current = CGPoint(
                    x: from.x + (to.x - from.x) * dotProgress,
                    y: from.y + (to.y - from.y) * dotProgress
                )
                var progressPath = Path()
                progressPath.move(to: from)
                progressPath.addLine(to: current)
                context.stroke(progressPath, with: .color(.white.opacity(0.5)), lineWidth: 2)

                // Dot
                let dotRect = CGRect(x: current.x - 6, y: current.y - 6, width: 12, height: 12)
                context.fill(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.8)))

                // Dot glow
                let glowRect = CGRect(x: current.x - 12, y: current.y - 12, width: 24, height: 24)
                context.fill(Path(ellipseIn: glowRect), with: .color(.indigo.opacity(0.3)))
            }

            // Phase label
            Text(labels[boxPhase % 4])
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(width: 180, height: 180)
        .onAppear { startBoxCycle() }
        .onDisappear { phaseTimer?.invalidate() }
    }

    private func startBoxCycle() {
        runPhase()
    }

    private func runPhase() {
        dotProgress = 0
        withAnimation(reduceMotion ? .none : .linear(duration: phaseDuration)) {
            dotProgress = 1.0
        }

        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: phaseDuration, repeats: false) { _ in
            DispatchQueue.main.async {
                boxPhase = (boxPhase + 1) % 4
                runPhase()
            }
        }
    }
}

// MARK: - Neck Rolls

struct NeckRollsAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let speed: Double = reduceMotion ? 0 : 0.35

            ZStack {
                // Direction circle
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                    .frame(width: 100, height: 100)

                // Direction arrow along path
                let angle = t * speed * .pi * 2
                let arrowAngle = angle + .pi / 2

                // Trail
                ForEach(0..<8, id: \.self) { i in
                    let trailAngle = angle - Double(i) * 0.1
                    let x = cos(trailAngle) * 50
                    let y = sin(trailAngle) * 50
                    Circle()
                        .fill(Color.white.opacity(0.3 - Double(i) * 0.035))
                        .frame(width: CGFloat(8 - i), height: CGFloat(8 - i))
                        .offset(x: x, y: y)
                }

                // Lead indicator
                Circle()
                    .fill(.white.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .shadow(color: .purple.opacity(0.4), radius: 6)
                    .offset(x: cos(angle) * 50, y: sin(angle) * 50)

                // Small arrow indicator
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white.opacity(0.25))
                    .rotationEffect(.radians(arrowAngle))
                    .offset(x: cos(angle) * 50, y: sin(angle) * 50)
                    .opacity(0)
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Shoulder Shrugs

struct ShoulderShrugsAnimation: View {
    @State private var isUp: Bool = false
    @State private var phase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Simple shoulder representation
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let shoulderOffset: CGFloat = isUp ? -15 : 0

                // Head
                let headRadius: CGFloat = 14
                let headRect = CGRect(
                    x: center.x - headRadius,
                    y: center.y - 40 - headRadius,
                    width: headRadius * 2,
                    height: headRadius * 2
                )
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.4)), lineWidth: 1.5)

                // Neck
                var neckPath = Path()
                neckPath.move(to: CGPoint(x: center.x, y: center.y - 26))
                neckPath.addLine(to: CGPoint(x: center.x, y: center.y - 10))
                context.stroke(neckPath, with: .color(.white.opacity(0.4)), lineWidth: 1.5)

                // Left shoulder
                var leftPath = Path()
                leftPath.move(to: CGPoint(x: center.x - 4, y: center.y - 8 + shoulderOffset))
                leftPath.addQuadCurve(
                    to: CGPoint(x: center.x - 55, y: center.y + 5 + shoulderOffset),
                    control: CGPoint(x: center.x - 30, y: center.y - 12 + shoulderOffset)
                )
                context.stroke(leftPath, with: .color(.white.opacity(0.5)), lineWidth: 2.5)

                // Right shoulder
                var rightPath = Path()
                rightPath.move(to: CGPoint(x: center.x + 4, y: center.y - 8 + shoulderOffset))
                rightPath.addQuadCurve(
                    to: CGPoint(x: center.x + 55, y: center.y + 5 + shoulderOffset),
                    control: CGPoint(x: center.x + 30, y: center.y - 12 + shoulderOffset)
                )
                context.stroke(rightPath, with: .color(.white.opacity(0.5)), lineWidth: 2.5)

                // Up arrows when raising
                if isUp {
                    let arrowAlpha = 0.3
                    for side in [-1.0, 1.0] {
                        let ax = center.x + CGFloat(side) * 40
                        let ay = center.y - 20 + shoulderOffset
                        var arrow = Path()
                        arrow.move(to: CGPoint(x: ax, y: ay + 8))
                        arrow.addLine(to: CGPoint(x: ax, y: ay))
                        arrow.move(to: CGPoint(x: ax - 4, y: ay + 4))
                        arrow.addLine(to: CGPoint(x: ax, y: ay))
                        arrow.addLine(to: CGPoint(x: ax + 4, y: ay + 4))
                        context.stroke(arrow, with: .color(.white.opacity(arrowAlpha)), lineWidth: 1)
                    }
                }
            }

            Text(phase == 1 ? "raise…" : phase == 2 ? "hold…" : "release")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 60)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            runShrugCycle()
        }
        .onAppear { runShrugCycle() }
    }

    private func runShrugCycle() {
        let anim: Animation? = reduceMotion ? nil : .easeOut(duration: 0.8)
        phase = 1
        withAnimation(anim) { isUp = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            phase = 2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            phase = 0
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.6)) { isUp = false }
        }
    }
}

// MARK: - Wrist Stretches

struct WristStretchesAnimation: View {
    @State private var stretchPhase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let fingerBend: CGFloat = stretchPhase == 1 ? -20 : stretchPhase == 2 ? 20 : 0

                // Forearm
                var arm = Path()
                arm.move(to: CGPoint(x: center.x - 50, y: center.y + 10))
                arm.addLine(to: CGPoint(x: center.x + 10, y: center.y + 10))
                arm.addLine(to: CGPoint(x: center.x + 10, y: center.y - 10))
                arm.addLine(to: CGPoint(x: center.x - 50, y: center.y - 10))
                context.stroke(arm, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

                // Hand/fingers
                let fingerBase = CGPoint(x: center.x + 10, y: center.y)
                let fingerTip = CGPoint(x: center.x + 45, y: center.y + fingerBend)

                // Palm
                var palm = Path()
                palm.move(to: CGPoint(x: center.x + 10, y: center.y - 12))
                palm.addLine(to: CGPoint(x: center.x + 25, y: center.y - 12 + fingerBend * 0.3))
                palm.addLine(to: CGPoint(x: center.x + 25, y: center.y + 12 + fingerBend * 0.3))
                palm.addLine(to: CGPoint(x: center.x + 10, y: center.y + 12))
                context.stroke(palm, with: .color(.white.opacity(0.4)), lineWidth: 1.5)

                // Fingers
                for i in -1...1 {
                    let yOff = CGFloat(i) * 8
                    var finger = Path()
                    finger.move(to: CGPoint(x: fingerBase.x + 15, y: fingerBase.y + yOff + fingerBend * 0.3))
                    finger.addLine(to: CGPoint(x: fingerTip.x, y: fingerTip.y + yOff))
                    context.stroke(finger, with: .color(.white.opacity(0.5)), lineWidth: 2)
                }

                // Stretch arrow
                if stretchPhase != 0 {
                    let arrowY = center.y + (stretchPhase == 1 ? -35 : 35)
                    let arrowDir: CGFloat = stretchPhase == 1 ? -1 : 1
                    var arrow = Path()
                    arrow.move(to: CGPoint(x: center.x + 35, y: center.y + arrowDir * 10))
                    arrow.addLine(to: CGPoint(x: center.x + 35, y: arrowY))
                    context.stroke(arrow, with: .color(.white.opacity(0.25)), lineWidth: 1)
                }
            }

            Text(stretchPhase == 1 ? "pull back…" : stretchPhase == 2 ? "push down…" : "relax")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 60)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            runStretchCycle()
        }
        .onAppear { runStretchCycle() }
    }

    private func runStretchCycle() {
        let anim: Animation? = reduceMotion ? nil : .easeInOut(duration: 1.0)
        withAnimation(anim) { stretchPhase = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(anim) { stretchPhase = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(anim) { stretchPhase = 0 }
        }
    }
}

// MARK: - Temple Massage

struct TempleMassageAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let speed: Double = reduceMotion ? 0 : 1.0

            ZStack {
                // Head outline
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 80, height: 80)

                // Left temple circle
                let leftAngle = t * speed
                let massageRadius: CGFloat = 6
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 10, height: 10)
                    .offset(
                        x: -52 + cos(leftAngle) * massageRadius,
                        y: -8 + sin(leftAngle) * massageRadius
                    )

                // Left pressure rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        .frame(
                            width: CGFloat(14 + i * 8),
                            height: CGFloat(14 + i * 8)
                        )
                        .offset(x: -52, y: -8)
                }

                // Right temple circle
                let rightAngle = t * speed + .pi
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 10, height: 10)
                    .offset(
                        x: 52 + cos(rightAngle) * massageRadius,
                        y: -8 + sin(rightAngle) * massageRadius
                    )

                // Right pressure rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        .frame(
                            width: CGFloat(14 + i * 8),
                            height: CGFloat(14 + i * 8)
                        )
                        .offset(x: 52, y: -8)
                }
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Jaw Release

struct JawReleaseAnimation: View {
    @State private var isOpen: Bool = false
    @State private var phase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let openAmount: CGFloat = isOpen ? 1.0 : 0.0

                // Head outline (upper)
                let headPath = Path { path in
                    path.addArc(
                        center: CGPoint(x: center.x, y: center.y - 15),
                        radius: 35,
                        startAngle: .degrees(200),
                        endAngle: .degrees(340),
                        clockwise: false
                    )
                }
                context.stroke(headPath, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

                // Jaw (moves down when open)
                let jawDrop = openAmount * 18
                let jawPath = Path { path in
                    path.addArc(
                        center: CGPoint(x: center.x, y: center.y - 5 + jawDrop),
                        radius: 30,
                        startAngle: .degrees(20),
                        endAngle: .degrees(160),
                        clockwise: false
                    )
                }
                context.stroke(jawPath, with: .color(.white.opacity(0.4)), lineWidth: 2)

                // Mouth opening
                let mouthHeight: CGFloat = 4 + openAmount * 20
                let mouthWidth: CGFloat = 20 + openAmount * 5
                let mouthRect = CGRect(
                    x: center.x - mouthWidth / 2,
                    y: center.y - 2 + jawDrop * 0.3,
                    width: mouthWidth,
                    height: mouthHeight
                )
                context.fill(
                    Path(roundedRect: mouthRect, cornerRadius: mouthHeight / 2),
                    with: .color(.white.opacity(0.08 + openAmount * 0.1))
                )
                context.stroke(
                    Path(roundedRect: mouthRect, cornerRadius: mouthHeight / 2),
                    with: .color(.white.opacity(0.3)),
                    lineWidth: 1
                )
            }

            Text(phase == 1 ? "open wide…" : phase == 2 ? "stretch…" : "relax")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 60)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            runJawCycle()
        }
        .onAppear { runJawCycle() }
    }

    private func runJawCycle() {
        phase = 1
        withAnimation(reduceMotion ? nil : .easeOut(duration: 1.0)) { isOpen = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { phase = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            phase = 0
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.5)) { isOpen = false }
        }
    }
}

// MARK: - Spinal Twist

struct SpinalTwistAnimation: View {
    @State private var twistSide: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let twistAmount: CGFloat = twistSide == 1 ? -12 : twistSide == 2 ? 12 : 0

                // Spine (vertical line, slightly curved with twist)
                var spine = Path()
                spine.move(to: CGPoint(x: center.x, y: center.y - 50))
                spine.addQuadCurve(
                    to: CGPoint(x: center.x, y: center.y + 50),
                    control: CGPoint(x: center.x + twistAmount, y: center.y)
                )
                context.stroke(spine, with: .color(.white.opacity(0.4)), lineWidth: 2)

                // Vertebrae dots
                for i in 0..<6 {
                    let t = CGFloat(i) / 5.0
                    let y = center.y - 50 + t * 100
                    let curveX = twistAmount * 4 * t * (1 - t)
                    let dotRect = CGRect(
                        x: center.x + curveX - 3,
                        y: y - 3,
                        width: 6,
                        height: 6
                    )
                    context.fill(
                        Path(ellipseIn: dotRect),
                        with: .color(.white.opacity(0.3))
                    )
                }

                // Shoulder line
                let shoulderTwist = twistAmount * 1.5
                var shoulders = Path()
                shoulders.move(to: CGPoint(x: center.x - 40 + shoulderTwist * 0.3, y: center.y - 30))
                shoulders.addLine(to: CGPoint(x: center.x + 40 + shoulderTwist * 0.7, y: center.y - 30))
                context.stroke(shoulders, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

                // Direction arrow
                if twistSide != 0 {
                    let arrowPath = Path { p in
                        p.addArc(
                            center: CGPoint(x: center.x, y: center.y - 30),
                            radius: 25,
                            startAngle: .degrees(twistSide == 1 ? -10 : 190),
                            endAngle: .degrees(twistSide == 1 ? -60 : 240),
                            clockwise: twistSide == 1
                        )
                    }
                    context.stroke(arrowPath, with: .color(.white.opacity(0.2)), lineWidth: 1)
                }
            }

            Text(twistSide == 1 ? "twist left…" : twistSide == 2 ? "twist right…" : "center")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 65)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            runTwistCycle()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { runTwistCycle() }
        }
    }

    private func runTwistCycle() {
        let anim: Animation? = reduceMotion ? nil : .easeInOut(duration: 1.2)
        withAnimation(anim) { twistSide = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(anim) { twistSide = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(anim) { twistSide = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation(anim) { twistSide = 0 }
        }
    }
}

// MARK: - Hand Massage

struct HandMassageAnimation: View {
    @State private var activeFingerIndex: Int = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Five finger dots in an arc
            ForEach(0..<5, id: \.self) { i in
                let angle = Double(i - 2) * 0.3 - .pi / 2
                let radius: CGFloat = 50
                let x = cos(angle) * radius
                let y = sin(angle) * radius - 10

                let isActive = i == activeFingerIndex
                let size: CGFloat = isActive ? 18 : 12

                Circle()
                    .fill(Color.white.opacity(isActive ? 0.7 : 0.2))
                    .frame(width: size, height: size)
                    .shadow(color: isActive ? .purple.opacity(0.5) : .clear, radius: isActive ? 8 : 0)
                    .offset(x: x, y: y)
                    .animation(reduceMotion ? .none : .easeOut(duration: 0.3), value: isActive)

                // Finger line
                let lineEnd = CGPoint(x: cos(angle) * (radius - 20), y: sin(angle) * (radius - 20) - 10)
                Path { path in
                    path.move(to: CGPoint(x: 90 + x, y: 100 + y))
                    path.addLine(to: CGPoint(x: 90 + lineEnd.x, y: 100 + lineEnd.y))
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }

            // Palm circle
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: 40, height: 40)
                .offset(y: 10)

            // Squeeze indicator
            if activeFingerIndex >= 0 {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 30, height: 30)
                    .scaleEffect(activeFingerIndex >= 0 ? 1.2 : 0.8)
                    .offset(y: 10)
                    .animation(reduceMotion ? .none : .easeOut(duration: 0.3), value: activeFingerIndex)
            }
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            withAnimation {
                activeFingerIndex = (activeFingerIndex + 1) % 5
            }
        }
    }
}

// MARK: - Chest Opener

struct ChestOpenerAnimation: View {
    @State private var isOpen: Bool = false
    @State private var phase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let spread: CGFloat = isOpen ? 60 : 25

                // Left arm
                var leftArm = Path()
                leftArm.move(to: CGPoint(x: center.x - 5, y: center.y - 5))
                leftArm.addLine(to: CGPoint(x: center.x - spread, y: center.y - 20))
                leftArm.addLine(to: CGPoint(x: center.x - spread - 10, y: center.y - 35))
                context.stroke(leftArm, with: .color(.white.opacity(0.4)), lineWidth: 2)

                // Right arm
                var rightArm = Path()
                rightArm.move(to: CGPoint(x: center.x + 5, y: center.y - 5))
                rightArm.addLine(to: CGPoint(x: center.x + spread, y: center.y - 20))
                rightArm.addLine(to: CGPoint(x: center.x + spread + 10, y: center.y - 35))
                context.stroke(rightArm, with: .color(.white.opacity(0.4)), lineWidth: 2)

                // Torso
                var torso = Path()
                torso.move(to: CGPoint(x: center.x, y: center.y - 10))
                torso.addLine(to: CGPoint(x: center.x, y: center.y + 40))
                context.stroke(torso, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

                // Head
                let headRect = CGRect(x: center.x - 10, y: center.y - 35, width: 20, height: 20)
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.3)), lineWidth: 1.5)

                // Chest glow when open
                if isOpen {
                    let glowRadius: CGFloat = 20
                    let glowRect = CGRect(
                        x: center.x - glowRadius,
                        y: center.y - 10 - glowRadius,
                        width: glowRadius * 2,
                        height: glowRadius * 2
                    )
                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .color(.indigo.opacity(0.15))
                    )
                }
            }

            Text(phase == 1 ? "open…" : phase == 2 ? "hold & breathe" : "relax")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 65)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            runChestCycle()
        }
        .onAppear { runChestCycle() }
    }

    private func runChestCycle() {
        phase = 1
        withAnimation(reduceMotion ? nil : .easeOut(duration: 1.2)) { isOpen = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { phase = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            phase = 0
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.6)) { isOpen = false }
        }
    }
}

// MARK: - Side Neck Stretch

struct SideNeckStretchAnimation: View {
    @State private var tiltSide: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let tiltAngle: CGFloat = tiltSide == 1 ? -0.35 : tiltSide == 2 ? 0.35 : 0

                // Shoulders (fixed)
                var shoulders = Path()
                shoulders.move(to: CGPoint(x: center.x - 45, y: center.y + 15))
                shoulders.addLine(to: CGPoint(x: center.x + 45, y: center.y + 15))
                context.stroke(shoulders, with: .color(.white.opacity(0.3)), lineWidth: 2)

                // Neck (tilts)
                let neckTop = CGPoint(
                    x: center.x + sin(tiltAngle) * 25,
                    y: center.y - 20
                )
                var neck = Path()
                neck.move(to: CGPoint(x: center.x, y: center.y + 10))
                neck.addLine(to: neckTop)
                context.stroke(neck, with: .color(.white.opacity(0.4)), lineWidth: 2)

                // Head (tilts with neck)
                let headCenter = CGPoint(
                    x: neckTop.x + sin(tiltAngle) * 16,
                    y: neckTop.y - 16
                )
                let headRect = CGRect(
                    x: headCenter.x - 14,
                    y: headCenter.y - 14,
                    width: 28,
                    height: 28
                )
                context.stroke(
                    Path(ellipseIn: headRect),
                    with: .color(.white.opacity(0.35)),
                    lineWidth: 1.5
                )

                // Stretch indicator line
                if tiltSide != 0 {
                    let stretchSide: CGFloat = tiltSide == 1 ? 1 : -1
                    let startY = center.y - 5
                    var stretchLine = Path()
                    stretchLine.move(to: CGPoint(x: center.x + stretchSide * 10, y: startY))
                    stretchLine.addLine(to: CGPoint(x: center.x + stretchSide * 10, y: startY - 25))
                    context.stroke(
                        stretchLine,
                        with: .color(.indigo.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 2, dash: [4, 3])
                    )
                }
            }

            Text(tiltSide == 1 ? "left side…" : tiltSide == 2 ? "right side…" : "center")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 65)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            runTiltCycle()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { runTiltCycle() }
        }
    }

    private func runTiltCycle() {
        let anim: Animation? = reduceMotion ? nil : .easeInOut(duration: 1.0)
        withAnimation(anim) { tiltSide = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(anim) { tiltSide = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(anim) { tiltSide = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(anim) { tiltSide = 0 }
        }
    }
}

// MARK: - Ankle Circles

struct AnkleCirclesAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let speed: Double = reduceMotion ? 0 : 0.5

            ZStack {
                // Leg line
                Path { path in
                    path.move(to: CGPoint(x: 90, y: 30))
                    path.addLine(to: CGPoint(x: 90, y: 90))
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 2)

                // Ankle joint
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .offset(y: 0)

                // Rotation path
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 60, height: 60)
                    .offset(y: 20)

                // Foot (rotating)
                let angle = t * speed * .pi * 2
                let footTip = CGPoint(
                    x: cos(angle) * 30,
                    y: 20 + sin(angle) * 30
                )

                // Foot line
                Path { path in
                    path.move(to: CGPoint(x: 90, y: 110))
                    path.addLine(to: CGPoint(x: 90 + footTip.x, y: 90 + footTip.y))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 2)

                // Foot tip dot
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .shadow(color: .purple.opacity(0.4), radius: 4)
                    .offset(x: footTip.x, y: footTip.y + 20)
            }
        }
        .frame(width: 180, height: 180)
    }
}
