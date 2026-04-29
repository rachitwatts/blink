import SwiftUI

// MARK: - Dramatic Sigh

struct DramaticSighAnimation: View {
    @State private var phase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Expanding exhale clouds
            ForEach(0..<5, id: \.self) { i in
                let delay = Double(i) * 0.15
                let spread = phase == 1 ? CGFloat(20 + i * 18) : 0
                let yOff = phase == 1 ? CGFloat(-10 - i * 6) : 0

                Circle()
                    .fill(Color.white.opacity(phase == 1 ? 0.12 - Double(i) * 0.02 : 0))
                    .frame(width: CGFloat(20 + i * 10), height: CGFloat(20 + i * 10))
                    .offset(x: spread, y: yOff)
                    .animation(
                        reduceMotion ? .none :
                            .easeOut(duration: 1.5).delay(delay),
                        value: phase
                    )
            }

            // Face
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Head
                let headRect = CGRect(x: center.x - 25, y: center.y - 25, width: 50, height: 50)
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.3)), lineWidth: 1.5)

                // Eyes (closed for sigh)
                let eyeY = center.y - 8
                for side in [-1.0, 1.0] {
                    let eyeX = center.x + side * 10
                    var eyePath = Path()
                    eyePath.move(to: CGPoint(x: eyeX - 5, y: eyeY))
                    eyePath.addQuadCurve(
                        to: CGPoint(x: eyeX + 5, y: eyeY),
                        control: CGPoint(x: eyeX, y: eyeY + 3)
                    )
                    context.stroke(eyePath, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
                }

                // Mouth (open for sigh)
                let mouthWidth: CGFloat = phase == 1 ? 14 : 8
                let mouthHeight: CGFloat = phase == 1 ? 10 : 4
                let mouthRect = CGRect(
                    x: center.x - mouthWidth / 2,
                    y: center.y + 8,
                    width: mouthWidth,
                    height: mouthHeight
                )
                context.fill(
                    Path(ellipseIn: mouthRect),
                    with: .color(.white.opacity(0.15))
                )
                context.stroke(
                    Path(ellipseIn: mouthRect),
                    with: .color(.white.opacity(0.35)),
                    lineWidth: 1
                )
            }

            // "siiiiigh" text that fades in
            if phase == 1 {
                Text("siiiiigh")
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .italic()
                    .foregroundColor(.white.opacity(0.3))
                    .offset(x: 45, y: -20)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) { phase = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(reduceMotion ? .none : .easeIn(duration: 0.5)) { phase = 0 }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) { phase = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(reduceMotion ? .none : .easeIn(duration: 0.5)) { phase = 0 }
                }
            }
        }
    }
}

// MARK: - Cat Stretch

struct CatStretchAnimation: View {
    @State private var isArched: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let archAmount: CGFloat = isArched ? -30 : 0

                // Cat body (arching back)
                var body = Path()
                body.move(to: CGPoint(x: center.x - 50, y: center.y + 10))
                body.addQuadCurve(
                    to: CGPoint(x: center.x + 50, y: center.y + 10),
                    control: CGPoint(x: center.x, y: center.y + archAmount)
                )
                context.stroke(body, with: .color(.white.opacity(0.5)), lineWidth: 2.5)

                // Front legs
                var frontLegs = Path()
                frontLegs.move(to: CGPoint(x: center.x - 40, y: center.y + 10))
                frontLegs.addLine(to: CGPoint(x: center.x - 45, y: center.y + 35))
                frontLegs.move(to: CGPoint(x: center.x - 32, y: center.y + 12))
                frontLegs.addLine(to: CGPoint(x: center.x - 35, y: center.y + 35))
                context.stroke(frontLegs, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Back legs
                var backLegs = Path()
                backLegs.move(to: CGPoint(x: center.x + 40, y: center.y + 10))
                backLegs.addLine(to: CGPoint(x: center.x + 45, y: center.y + 35))
                backLegs.move(to: CGPoint(x: center.x + 32, y: center.y + 12))
                backLegs.addLine(to: CGPoint(x: center.x + 35, y: center.y + 35))
                context.stroke(backLegs, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Head
                let headY = center.y + (isArched ? -5 : 5)
                let headRect = CGRect(x: center.x - 58, y: headY - 8, width: 16, height: 14)
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.4)), lineWidth: 1.5)

                // Ears
                var ears = Path()
                ears.move(to: CGPoint(x: center.x - 55, y: headY - 7))
                ears.addLine(to: CGPoint(x: center.x - 57, y: headY - 15))
                ears.addLine(to: CGPoint(x: center.x - 52, y: headY - 8))
                ears.move(to: CGPoint(x: center.x - 48, y: headY - 7))
                ears.addLine(to: CGPoint(x: center.x - 46, y: headY - 15))
                ears.addLine(to: CGPoint(x: center.x - 50, y: headY - 8))
                context.stroke(ears, with: .color(.white.opacity(0.4)), lineWidth: 1)

                // Tail (curving up when arched)
                let tailCurve: CGFloat = isArched ? -25 : -5
                var tail = Path()
                tail.move(to: CGPoint(x: center.x + 50, y: center.y + 10))
                tail.addQuadCurve(
                    to: CGPoint(x: center.x + 65, y: center.y + tailCurve),
                    control: CGPoint(x: center.x + 62, y: center.y + 10)
                )
                context.stroke(tail, with: .color(.white.opacity(0.35)), lineWidth: 1.5)
            }

            Text(isArched ? "hissss" : "mrrow~")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 55)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 1.0)) { isArched.toggle() }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 1.0)) { isArched = true }
            }
        }
    }
}

// MARK: - Invisible Piano

struct InvisiblePianoAnimation: View {
    @State private var activeKey: Int = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    @State private var sequence: [Int] = []
    @State private var seqIndex: Int = 0

    private let melodyPattern = [0, 2, 4, 3, 1, 4, 2, 0, 3, 1, 4, 2, 1, 3, 0]

    var body: some View {
        ZStack {
            // Piano keys
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let isActive = i == activeKey
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(isActive ? 0.35 : 0.08))
                        .frame(width: 18, height: 60)
                        .offset(y: isActive ? 3 : 0)
                        .shadow(color: isActive ? .purple.opacity(0.5) : .clear, radius: isActive ? 6 : 0)
                        .animation(reduceMotion ? .none : .easeOut(duration: 0.1), value: isActive)
                }
            }

            // Musical notes floating up
            if activeKey >= 0 {
                let noteX = CGFloat(activeKey - 3) * 22
                Text(["♪", "♫", "♩", "♬", "♪", "♫", "♩"][activeKey])
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.3))
                    .offset(x: noteX, y: -50)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 10)),
                        removal: .opacity.combined(with: .offset(y: -20))
                    ))
                    .id("note-\(activeKey)-\(seqIndex)")
            }
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.15)) {
                activeKey = melodyPattern[seqIndex % melodyPattern.count]
                seqIndex += 1
            }
        }
    }
}

// MARK: - Power Pose

struct PowerPoseAnimation: View {
    @State private var isPowered: Bool = false
    @State private var glowPulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Power glow
            if isPowered {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.15), .orange.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(glowPulse ? 1.1 : 0.9)
                    .animation(
                        reduceMotion ? .none :
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: glowPulse
                    )
            }

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let armSpread: CGFloat = isPowered ? 55 : 15

                // Head
                let headRect = CGRect(x: center.x - 10, y: center.y - 45, width: 20, height: 20)
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.4)), lineWidth: 1.5)

                // Torso
                var torso = Path()
                torso.move(to: CGPoint(x: center.x, y: center.y - 25))
                torso.addLine(to: CGPoint(x: center.x, y: center.y + 20))
                context.stroke(torso, with: .color(.white.opacity(0.35)), lineWidth: 2)

                // Arms on hips (power pose) or down
                let armY = center.y - 15
                let hipY = center.y + 10

                // Left arm
                var leftArm = Path()
                leftArm.move(to: CGPoint(x: center.x - 3, y: armY))
                if isPowered {
                    leftArm.addLine(to: CGPoint(x: center.x - armSpread, y: armY + 5))
                    leftArm.addLine(to: CGPoint(x: center.x - 15, y: hipY))
                } else {
                    leftArm.addLine(to: CGPoint(x: center.x - armSpread, y: center.y + 25))
                }
                context.stroke(leftArm, with: .color(.white.opacity(0.4)), lineWidth: 2)

                // Right arm
                var rightArm = Path()
                rightArm.move(to: CGPoint(x: center.x + 3, y: armY))
                if isPowered {
                    rightArm.addLine(to: CGPoint(x: center.x + armSpread, y: armY + 5))
                    rightArm.addLine(to: CGPoint(x: center.x + 15, y: hipY))
                } else {
                    rightArm.addLine(to: CGPoint(x: center.x + armSpread, y: center.y + 25))
                }
                context.stroke(rightArm, with: .color(.white.opacity(0.4)), lineWidth: 2)

                // Legs
                var legs = Path()
                legs.move(to: CGPoint(x: center.x, y: center.y + 20))
                legs.addLine(to: CGPoint(x: center.x - 18, y: center.y + 55))
                legs.move(to: CGPoint(x: center.x, y: center.y + 20))
                legs.addLine(to: CGPoint(x: center.x + 18, y: center.y + 55))
                context.stroke(legs, with: .color(.white.opacity(0.3)), lineWidth: 1.5)
            }
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.8)) { isPowered.toggle() }
            if !isPowered { glowPulse = false }
            else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { glowPulse = true }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(reduceMotion ? .none : .easeOut(duration: 0.8)) { isPowered = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { glowPulse = true }
            }
        }
    }
}

// MARK: - Face Scrunch

struct FaceScrunchAnimation: View {
    @State private var phase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let scrunch: CGFloat = phase == 1 ? 1.0 : 0.0

                // Head
                let headSize: CGFloat = 50 - scrunch * 4
                let headRect = CGRect(
                    x: center.x - headSize / 2, y: center.y - headSize / 2,
                    width: headSize, height: headSize
                )
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Eyes
                let eyeSpacing: CGFloat = 12 - scrunch * 4
                let eyeY = center.y - 5
                for side in [-1.0, 1.0] {
                    let eyeX = center.x + side * eyeSpacing
                    if scrunch > 0.5 {
                        // Scrunched: X shapes
                        let s: CGFloat = 3
                        var x1 = Path()
                        x1.move(to: CGPoint(x: eyeX - s, y: eyeY - s))
                        x1.addLine(to: CGPoint(x: eyeX + s, y: eyeY + s))
                        var x2 = Path()
                        x2.move(to: CGPoint(x: eyeX + s, y: eyeY - s))
                        x2.addLine(to: CGPoint(x: eyeX - s, y: eyeY + s))
                        context.stroke(x1, with: .color(.white.opacity(0.5)), lineWidth: 2)
                        context.stroke(x2, with: .color(.white.opacity(0.5)), lineWidth: 2)
                    } else {
                        // Open: circles
                        let eyeRect = CGRect(x: eyeX - 4, y: eyeY - 4, width: 8, height: 8)
                        context.fill(Path(ellipseIn: eyeRect), with: .color(.white.opacity(0.4)))
                    }
                }

                // Wrinkle lines when scrunched
                if scrunch > 0.5 {
                    for i in 0..<3 {
                        let wy = center.y - 16 + CGFloat(i) * 3
                        var wrinkle = Path()
                        wrinkle.move(to: CGPoint(x: center.x - 8, y: wy))
                        wrinkle.addLine(to: CGPoint(x: center.x + 8, y: wy))
                        context.stroke(wrinkle, with: .color(.white.opacity(0.2)), lineWidth: 0.5)
                    }
                }

                // Mouth
                let mouthY = center.y + 10 - scrunch * 3
                let mouthWidth: CGFloat = 12 - scrunch * 6
                var mouth = Path()
                if scrunch > 0.5 {
                    // Puckered
                    let pucker = CGRect(x: center.x - 3, y: mouthY - 3, width: 6, height: 6)
                    context.stroke(Path(ellipseIn: pucker), with: .color(.white.opacity(0.35)), lineWidth: 1.5)
                } else {
                    // Relaxed smile
                    mouth.move(to: CGPoint(x: center.x - mouthWidth, y: mouthY))
                    mouth.addQuadCurve(
                        to: CGPoint(x: center.x + mouthWidth, y: mouthY),
                        control: CGPoint(x: center.x, y: mouthY + 6)
                    )
                    context.stroke(mouth, with: .color(.white.opacity(0.35)), lineWidth: 1.5)
                }
            }

            Text(phase == 1 ? "scrunch!" : "ahhh~")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 55)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.3)) { phase = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) { phase = 0 }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(reduceMotion ? .none : .easeOut(duration: 0.3)) { phase = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) { phase = 0 }
                }
            }
        }
    }
}

// MARK: - T-Rex Arms

struct TRexArmsAnimation: View {
    @State private var wigglePhase: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let wiggle = reduceMotion ? 0.0 : sin(t * 8) * 6

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Head
                let headRect = CGRect(x: center.x - 14, y: center.y - 50, width: 28, height: 28)
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Tiny eyes
                for side in [-1.0, 1.0] {
                    let dotRect = CGRect(x: center.x + side * 5 - 2, y: center.y - 40, width: 4, height: 4)
                    context.fill(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.4)))
                }

                // Open mouth (rawr)
                let mouthRect = CGRect(x: center.x - 5, y: center.y - 32, width: 10, height: 6)
                context.fill(
                    Path(roundedRect: mouthRect, cornerRadius: 2),
                    with: .color(.white.opacity(0.15))
                )

                // Torso
                var torso = Path()
                torso.move(to: CGPoint(x: center.x, y: center.y - 22))
                torso.addLine(to: CGPoint(x: center.x, y: center.y + 25))
                context.stroke(torso, with: .color(.white.opacity(0.3)), lineWidth: 2)

                // Tiny T-Rex arms (wiggling!)
                let armY = center.y - 10
                for side in [-1.0, 1.0] {
                    let armWiggle = CGFloat(wiggle * side)
                    var arm = Path()
                    arm.move(to: CGPoint(x: center.x + side * 4, y: armY))
                    arm.addLine(to: CGPoint(x: center.x + side * 18, y: armY + 5 + armWiggle))
                    arm.addLine(to: CGPoint(x: center.x + side * 22, y: armY - 2 + armWiggle))
                    context.stroke(arm, with: .color(.white.opacity(0.5)), lineWidth: 2)

                    // Tiny claw
                    let clawX = center.x + side * 22
                    let clawY = armY - 2 + armWiggle
                    var claw = Path()
                    claw.move(to: CGPoint(x: clawX, y: clawY))
                    claw.addLine(to: CGPoint(x: clawX + side * 3, y: clawY - 3))
                    claw.move(to: CGPoint(x: clawX, y: clawY))
                    claw.addLine(to: CGPoint(x: clawX + side * 4, y: clawY))
                    context.stroke(claw, with: .color(.white.opacity(0.35)), lineWidth: 1)
                }

                // Legs (wider stance)
                var legs = Path()
                legs.move(to: CGPoint(x: center.x, y: center.y + 25))
                legs.addLine(to: CGPoint(x: center.x - 20, y: center.y + 55))
                legs.move(to: CGPoint(x: center.x, y: center.y + 25))
                legs.addLine(to: CGPoint(x: center.x + 20, y: center.y + 55))
                context.stroke(legs, with: .color(.white.opacity(0.3)), lineWidth: 1.5)
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Shoulder Shimmy

struct ShoulderShimmyAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let speed: Double = reduceMotion ? 0 : 4.0
            let leftY = sin(t * speed) * 10
            let rightY = sin(t * speed + .pi) * 10

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Head
                let headRect = CGRect(x: center.x - 12, y: center.y - 40, width: 24, height: 24)
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Neck
                var neck = Path()
                neck.move(to: CGPoint(x: center.x, y: center.y - 16))
                neck.addLine(to: CGPoint(x: center.x, y: center.y - 5))
                context.stroke(neck, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

                // Left shoulder + arm
                var left = Path()
                left.move(to: CGPoint(x: center.x - 4, y: center.y - 3 + CGFloat(leftY)))
                left.addQuadCurve(
                    to: CGPoint(x: center.x - 50, y: center.y + 5 + CGFloat(leftY)),
                    control: CGPoint(x: center.x - 28, y: center.y - 8 + CGFloat(leftY))
                )
                context.stroke(left, with: .color(.white.opacity(0.45)), lineWidth: 2.5)

                // Right shoulder + arm
                var right = Path()
                right.move(to: CGPoint(x: center.x + 4, y: center.y - 3 + CGFloat(rightY)))
                right.addQuadCurve(
                    to: CGPoint(x: center.x + 50, y: center.y + 5 + CGFloat(rightY)),
                    control: CGPoint(x: center.x + 28, y: center.y - 8 + CGFloat(rightY))
                )
                context.stroke(right, with: .color(.white.opacity(0.45)), lineWidth: 2.5)

                // Sparkle dots
                for i in 0..<4 {
                    let sparkleT = t * 2.0 + Double(i) * 1.5
                    let sx = center.x + CGFloat(cos(sparkleT) * 55)
                    let sy = center.y - 20 + CGFloat(sin(sparkleT * 0.7) * 25)
                    let sparkleAlpha = reduceMotion ? 0.2 : (sin(sparkleT * 3) * 0.15 + 0.2)
                    let sparkleRect = CGRect(x: sx - 2, y: sy - 2, width: 4, height: 4)
                    context.fill(
                        Path(ellipseIn: sparkleRect),
                        with: .color(.white.opacity(sparkleAlpha))
                    )
                }
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Existential Stare

struct ExistentialStareAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // The Void — expanding/contracting concentric circles
                let voidBreath = reduceMotion ? 0.5 : (sin(t * 0.4) * 0.5 + 0.5)
                for i in 0..<8 {
                    let baseRadius = CGFloat(10 + i * 10)
                    let radius = baseRadius + CGFloat(voidBreath) * 5
                    let alpha = max(0, 0.12 - Double(i) * 0.015)
                    let rect = CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(.purple.opacity(alpha)),
                        lineWidth: 0.8
                    )
                }

                // Central eye
                let eyeWidth: CGFloat = 50
                let eyeHeight: CGFloat = 20

                // Eye shape
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
                context.fill(eyePath, with: .color(.white.opacity(0.08)))
                context.stroke(eyePath, with: .color(.white.opacity(0.4)), lineWidth: 1.5)

                // Pupil (slowly drifts)
                let pupilDrift = reduceMotion ? 0.0 : sin(t * 0.3) * 3
                let pupilRadius: CGFloat = 8
                let pupilRect = CGRect(
                    x: center.x - pupilRadius + CGFloat(pupilDrift),
                    y: center.y - pupilRadius,
                    width: pupilRadius * 2,
                    height: pupilRadius * 2
                )
                context.fill(Path(ellipseIn: pupilRect), with: .color(.white.opacity(0.5)))

                // Inner pupil
                let innerRect = CGRect(
                    x: center.x - 3 + CGFloat(pupilDrift),
                    y: center.y - 3,
                    width: 6, height: 6
                )
                context.fill(Path(ellipseIn: innerRect), with: .color(Color(red: 0.05, green: 0.05, blue: 0.12)))
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Desk Drumroll

struct DeskDrumrollAnimation: View {
    @State private var hitSide: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Desk surface
                var desk = Path()
                desk.move(to: CGPoint(x: center.x - 70, y: center.y + 15))
                desk.addLine(to: CGPoint(x: center.x + 70, y: center.y + 15))
                context.stroke(desk, with: .color(.white.opacity(0.25)), lineWidth: 2)

                // Left stick
                let leftDown = hitSide == 1
                var leftStick = Path()
                let leftBase = CGPoint(x: center.x - 25, y: center.y - 20)
                let leftTip = CGPoint(
                    x: leftBase.x - 15,
                    y: leftBase.y + 35 + (leftDown ? 0 : -8)
                )
                leftStick.move(to: leftBase)
                leftStick.addLine(to: leftTip)
                context.stroke(leftStick, with: .color(.white.opacity(0.45)), lineWidth: 2.5)

                // Right stick
                let rightDown = hitSide == 2
                var rightStick = Path()
                let rightBase = CGPoint(x: center.x + 25, y: center.y - 20)
                let rightTip = CGPoint(
                    x: rightBase.x + 15,
                    y: rightBase.y + 35 + (rightDown ? 0 : -8)
                )
                rightStick.move(to: rightBase)
                rightStick.addLine(to: rightTip)
                context.stroke(rightStick, with: .color(.white.opacity(0.45)), lineWidth: 2.5)

                // Impact ring on hit
                if leftDown || rightDown {
                    let impactX = leftDown ? leftTip.x : rightTip.x
                    let impactY = center.y + 15
                    for i in 0..<3 {
                        let ringRadius = CGFloat(4 + i * 6)
                        let ringRect = CGRect(
                            x: impactX - ringRadius, y: impactY - ringRadius / 2,
                            width: ringRadius * 2, height: ringRadius
                        )
                        context.stroke(
                            Path(ellipseIn: ringRect),
                            with: .color(.white.opacity(0.15 - Double(i) * 0.04)),
                            lineWidth: 0.8
                        )
                    }
                }
            }

            // BPM counter vibe
            Text(hitSide > 0 ? "tap tap tap" : "…")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
                .offset(y: 55)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.08)) {
                hitSide = hitSide == 1 ? 2 : 1
            }
        }
    }
}

// MARK: - Star Jumps

struct StarJumpsAnimation: View {
    @State private var isJumping: Bool = false
    @State private var jumpCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let jumpOffset: CGFloat = isJumping ? -15 : 0
                let spread: CGFloat = isJumping ? 1.0 : 0.0

                // Head
                let headRect = CGRect(
                    x: center.x - 10, y: center.y - 42 + jumpOffset,
                    width: 20, height: 20
                )
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.4)), lineWidth: 1.5)

                // Torso
                var torso = Path()
                torso.move(to: CGPoint(x: center.x, y: center.y - 22 + jumpOffset))
                torso.addLine(to: CGPoint(x: center.x, y: center.y + 15 + jumpOffset))
                context.stroke(torso, with: .color(.white.opacity(0.35)), lineWidth: 2)

                // Arms (spread out like a star)
                let armAngle = spread * 50
                var leftArm = Path()
                leftArm.move(to: CGPoint(x: center.x - 3, y: center.y - 15 + jumpOffset))
                leftArm.addLine(to: CGPoint(
                    x: center.x - 40 - armAngle * 0.3,
                    y: center.y - 15 - armAngle + jumpOffset
                ))
                context.stroke(leftArm, with: .color(.white.opacity(0.4)), lineWidth: 2)

                var rightArm = Path()
                rightArm.move(to: CGPoint(x: center.x + 3, y: center.y - 15 + jumpOffset))
                rightArm.addLine(to: CGPoint(
                    x: center.x + 40 + armAngle * 0.3,
                    y: center.y - 15 - armAngle + jumpOffset
                ))
                context.stroke(rightArm, with: .color(.white.opacity(0.4)), lineWidth: 2)

                // Legs (spread for star)
                let legSpread = spread * 25
                var leftLeg = Path()
                leftLeg.move(to: CGPoint(x: center.x, y: center.y + 15 + jumpOffset))
                leftLeg.addLine(to: CGPoint(x: center.x - 18 - legSpread, y: center.y + 50 + jumpOffset))
                context.stroke(leftLeg, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                var rightLeg = Path()
                rightLeg.move(to: CGPoint(x: center.x, y: center.y + 15 + jumpOffset))
                rightLeg.addLine(to: CGPoint(x: center.x + 18 + legSpread, y: center.y + 50 + jumpOffset))
                context.stroke(rightLeg, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Ground shadow
                if isJumping {
                    let shadowRect = CGRect(x: center.x - 15, y: center.y + 55, width: 30, height: 4)
                    context.fill(
                        Path(ellipseIn: shadowRect),
                        with: .color(.white.opacity(0.08))
                    )
                }
            }

            Text(jumpCount > 0 ? "\(min(jumpCount, 3)) of 3" : "ready?")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 60)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            jumpCount = (jumpCount % 3) + 1
            withAnimation(reduceMotion ? .none : .interpolatingSpring(stiffness: 300, damping: 10)) {
                isJumping = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(reduceMotion ? .none : .easeIn(duration: 0.3)) { isJumping = false }
            }
        }
    }
}

// MARK: - Zombie Arms

struct ZombieArmsAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let sway = reduceMotion ? 0.0 : sin(t * 1.5) * 8
            let lurch = reduceMotion ? 0.0 : sin(t * 0.8) * 4

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Head (tilted)
                let headTilt = CGFloat(sway * 0.3)
                let headRect = CGRect(x: center.x - 12 + headTilt, y: center.y - 48, width: 24, height: 24)
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Dead eyes (X shapes)
                for side in [-1.0, 1.0] {
                    let eyeX = center.x + side * 6 + headTilt
                    let eyeY = center.y - 39
                    var x1 = Path()
                    x1.move(to: CGPoint(x: eyeX - 2.5, y: eyeY - 2.5))
                    x1.addLine(to: CGPoint(x: eyeX + 2.5, y: eyeY + 2.5))
                    var x2 = Path()
                    x2.move(to: CGPoint(x: eyeX + 2.5, y: eyeY - 2.5))
                    x2.addLine(to: CGPoint(x: eyeX - 2.5, y: eyeY + 2.5))
                    context.stroke(x1, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
                    context.stroke(x2, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
                }

                // Open mouth (groaning)
                let mouthRect = CGRect(x: center.x - 4 + headTilt, y: center.y - 32, width: 8, height: 5)
                context.fill(Path(ellipseIn: mouthRect), with: .color(.white.opacity(0.15)))
                context.stroke(Path(ellipseIn: mouthRect), with: .color(.white.opacity(0.3)), lineWidth: 1)

                // Torso (lurching forward)
                var torso = Path()
                torso.move(to: CGPoint(x: center.x, y: center.y - 24))
                torso.addLine(to: CGPoint(x: center.x + CGFloat(lurch), y: center.y + 20))
                context.stroke(torso, with: .color(.white.opacity(0.3)), lineWidth: 2)

                // Arms stretched forward (zombie style)
                let armY = center.y - 12
                let armBob = CGFloat(sin(t * 2.0) * 3)
                for side in [-1.0, 1.0] {
                    let armOffset = CGFloat(side * 3)
                    var arm = Path()
                    arm.move(to: CGPoint(x: center.x + armOffset, y: armY))
                    arm.addLine(to: CGPoint(x: center.x + 55, y: armY - 5 + CGFloat(side) * armBob))
                    context.stroke(arm, with: .color(.white.opacity(0.4)), lineWidth: 2)

                    // Droopy hands
                    var hand = Path()
                    hand.move(to: CGPoint(x: center.x + 55, y: armY - 5 + CGFloat(side) * armBob))
                    hand.addLine(to: CGPoint(x: center.x + 58, y: armY + 2 + CGFloat(side) * armBob))
                    context.stroke(hand, with: .color(.white.opacity(0.3)), lineWidth: 1.5)
                }

                // Legs (shuffling)
                let legShuffle = CGFloat(sway * 0.5)
                var legs = Path()
                legs.move(to: CGPoint(x: center.x + CGFloat(lurch), y: center.y + 20))
                legs.addLine(to: CGPoint(x: center.x - 15 + legShuffle, y: center.y + 55))
                legs.move(to: CGPoint(x: center.x + CGFloat(lurch), y: center.y + 20))
                legs.addLine(to: CGPoint(x: center.x + 15 - legShuffle, y: center.y + 55))
                context.stroke(legs, with: .color(.white.opacity(0.25)), lineWidth: 1.5)
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Penguin Waddle

struct PenguinWaddleAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let waddle = reduceMotion ? 0.0 : sin(t * 3.0) * 10
            let bodyTilt = reduceMotion ? 0.0 : sin(t * 3.0) * 0.08

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Body (round, tilting)
                let bodyRect = CGRect(x: center.x - 25 + CGFloat(waddle * 0.3), y: center.y - 20, width: 50, height: 55)
                context.fill(Path(ellipseIn: bodyRect), with: .color(.white.opacity(0.06)))
                context.stroke(Path(ellipseIn: bodyRect), with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Belly (white patch)
                let bellyRect = CGRect(x: center.x - 14 + CGFloat(waddle * 0.3), y: center.y - 8, width: 28, height: 38)
                context.fill(Path(ellipseIn: bellyRect), with: .color(.white.opacity(0.06)))
                context.stroke(Path(ellipseIn: bellyRect), with: .color(.white.opacity(0.15)), lineWidth: 0.8)

                // Head
                let headX = center.x + CGFloat(waddle * 0.3)
                let headRect = CGRect(x: headX - 14, y: center.y - 40, width: 28, height: 25)
                context.fill(Path(ellipseIn: headRect), with: .color(.white.opacity(0.04)))
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Eyes
                for side in [-1.0, 1.0] {
                    let eyeRect = CGRect(x: headX + side * 6 - 2.5, y: center.y - 33, width: 5, height: 5)
                    context.fill(Path(ellipseIn: eyeRect), with: .color(.white.opacity(0.5)))
                }

                // Beak
                var beak = Path()
                beak.move(to: CGPoint(x: headX - 4, y: center.y - 26))
                beak.addLine(to: CGPoint(x: headX, y: center.y - 21))
                beak.addLine(to: CGPoint(x: headX + 4, y: center.y - 26))
                beak.closeSubpath()
                context.fill(beak, with: .color(.orange.opacity(0.4)))

                // Flippers (tucked to sides, wiggling)
                let flipperWag = CGFloat(bodyTilt * 30)
                for side in [-1.0, 1.0] {
                    var flipper = Path()
                    let flipX = center.x + side * 25 + CGFloat(waddle * 0.3)
                    flipper.move(to: CGPoint(x: flipX, y: center.y - 10))
                    flipper.addQuadCurve(
                        to: CGPoint(x: flipX + side * 8, y: center.y + 20),
                        control: CGPoint(x: flipX + side * 14 + flipperWag * side, y: center.y + 5)
                    )
                    context.stroke(flipper, with: .color(.white.opacity(0.35)), lineWidth: 2)
                }

                // Feet
                for side in [-1.0, 1.0] {
                    let footX = center.x + side * 10 + CGFloat(waddle * 0.5)
                    var foot = Path()
                    foot.move(to: CGPoint(x: footX - 6, y: center.y + 35))
                    foot.addLine(to: CGPoint(x: footX + 6, y: center.y + 35))
                    foot.addLine(to: CGPoint(x: footX, y: center.y + 30))
                    foot.closeSubpath()
                    context.fill(foot, with: .color(.orange.opacity(0.3)))
                }
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Invisible Jump Rope

struct InvisibleJumpRopeAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let jumpCycle = reduceMotion ? 0.0 : sin(t * 4.0)
            let jumpHeight = max(0, jumpCycle) * 18
            let ropeAngle = reduceMotion ? 0.0 : t * 4.0

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let figureY = center.y - CGFloat(jumpHeight)

                // Head
                let headRect = CGRect(x: center.x - 10, y: figureY - 45, width: 20, height: 20)
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.4)), lineWidth: 1.5)

                // Torso
                var torso = Path()
                torso.move(to: CGPoint(x: center.x, y: figureY - 25))
                torso.addLine(to: CGPoint(x: center.x, y: figureY + 15))
                context.stroke(torso, with: .color(.white.opacity(0.35)), lineWidth: 2)

                // Arms (holding rope handles, elbows bent)
                for side in [-1.0, 1.0] {
                    var arm = Path()
                    arm.move(to: CGPoint(x: center.x + side * 3, y: figureY - 18))
                    arm.addLine(to: CGPoint(x: center.x + side * 18, y: figureY - 5))
                    arm.addLine(to: CGPoint(x: center.x + side * 15, y: figureY + 10))
                    context.stroke(arm, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
                }

                // Legs (bent during jump)
                let legBend: CGFloat = jumpHeight > 5 ? 8 : 0
                var legs = Path()
                legs.move(to: CGPoint(x: center.x, y: figureY + 15))
                legs.addLine(to: CGPoint(x: center.x - 12, y: figureY + 35 - legBend))
                legs.addLine(to: CGPoint(x: center.x - 10, y: figureY + 50))
                legs.move(to: CGPoint(x: center.x, y: figureY + 15))
                legs.addLine(to: CGPoint(x: center.x + 12, y: figureY + 35 - legBend))
                legs.addLine(to: CGPoint(x: center.x + 10, y: figureY + 50))
                context.stroke(legs, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

                // Rope arc (dashed, rotating around figure)
                let ropeSin = sin(ropeAngle)
                let ropeTopY = figureY - 55 - abs(CGFloat(ropeSin)) * 10
                let ropeBottomY = figureY + 50

                var rope = Path()
                let leftHandX = center.x - 15
                let rightHandX = center.x + 15

                if ropeSin > 0 {
                    // Rope in front (above)
                    rope.move(to: CGPoint(x: leftHandX, y: figureY + 10))
                    rope.addQuadCurve(
                        to: CGPoint(x: rightHandX, y: figureY + 10),
                        control: CGPoint(x: center.x, y: ropeTopY)
                    )
                } else {
                    // Rope behind (below)
                    rope.move(to: CGPoint(x: leftHandX, y: figureY + 10))
                    rope.addQuadCurve(
                        to: CGPoint(x: rightHandX, y: figureY + 10),
                        control: CGPoint(x: center.x, y: ropeBottomY)
                    )
                }

                let ropeAlpha = 0.2 + abs(ropeSin) * 0.15
                context.stroke(
                    rope,
                    with: .color(.white.opacity(ropeAlpha)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                )

                // Ground shadow
                if jumpHeight > 2 {
                    let shadowWidth: CGFloat = 20 - CGFloat(jumpHeight) * 0.3
                    let shadowRect = CGRect(
                        x: center.x - shadowWidth, y: center.y + 55,
                        width: shadowWidth * 2, height: 4
                    )
                    context.fill(Path(ellipseIn: shadowRect), with: .color(.white.opacity(0.06)))
                }
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Opera Singer

struct OperaSingerAnimation: View {
    @State private var phase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Musical notes emanating outward
            if phase == 1 {
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) * (.pi / 3) - .pi / 2
                    let distance: CGFloat = reduceMotion ? 50 : 60
                    Text(["♪", "♫", "♩", "♬", "♪", "♫"][i])
                        .font(.system(size: CGFloat(12 + i % 3 * 2)))
                        .foregroundColor(.white.opacity(0.25 - Double(i) * 0.03))
                        .offset(
                            x: cos(angle) * distance,
                            y: sin(angle) * distance
                        )
                        .transition(.opacity.combined(with: .scale))
                }
            }

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Head
                let headRect = CGRect(x: center.x - 14, y: center.y - 40, width: 28, height: 28)
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Eyes (closed dramatically)
                for side in [-1.0, 1.0] {
                    let eyeX = center.x + side * 6
                    let eyeY = center.y - 30
                    var eyePath = Path()
                    eyePath.move(to: CGPoint(x: eyeX - 4, y: eyeY))
                    eyePath.addQuadCurve(
                        to: CGPoint(x: eyeX + 4, y: eyeY),
                        control: CGPoint(x: eyeX, y: eyeY + 2))
                    context.stroke(eyePath, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
                }

                // Mouth (wide open for singing)
                let mouthOpen: CGFloat = phase == 1 ? 14 : 4
                let mouthWidth: CGFloat = phase == 1 ? 10 : 6
                let mouthRect = CGRect(
                    x: center.x - mouthWidth / 2, y: center.y - 20,
                    width: mouthWidth, height: mouthOpen
                )
                context.fill(Path(ellipseIn: mouthRect), with: .color(.white.opacity(0.12)))
                context.stroke(Path(ellipseIn: mouthRect), with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Torso
                var torso = Path()
                torso.move(to: CGPoint(x: center.x, y: center.y - 12))
                torso.addLine(to: CGPoint(x: center.x, y: center.y + 25))
                context.stroke(torso, with: .color(.white.opacity(0.3)), lineWidth: 2)

                // Arms (dramatic gesture)
                let armSpread: CGFloat = phase == 1 ? 50 : 20
                let armLift: CGFloat = phase == 1 ? -15 : 10
                for side in [-1.0, 1.0] {
                    var arm = Path()
                    arm.move(to: CGPoint(x: center.x + side * 3, y: center.y - 5))
                    arm.addLine(to: CGPoint(x: center.x + side * armSpread, y: center.y + armLift))
                    context.stroke(arm, with: .color(.white.opacity(0.4)), lineWidth: 2)
                }

                // Legs
                var legs = Path()
                legs.move(to: CGPoint(x: center.x, y: center.y + 25))
                legs.addLine(to: CGPoint(x: center.x - 15, y: center.y + 55))
                legs.move(to: CGPoint(x: center.x, y: center.y + 25))
                legs.addLine(to: CGPoint(x: center.x + 15, y: center.y + 55))
                context.stroke(legs, with: .color(.white.opacity(0.25)), lineWidth: 1.5)
            }

            // "Bravo" text
            if phase == 1 {
                Text("la la laaa~")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(.white.opacity(0.35))
                    .offset(y: 60)
                    .transition(.opacity)
            }
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.6)) { phase = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(reduceMotion ? .none : .easeIn(duration: 0.5)) { phase = 0 }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(reduceMotion ? .none : .easeOut(duration: 0.6)) { phase = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(reduceMotion ? .none : .easeIn(duration: 0.5)) { phase = 0 }
                }
            }
        }
    }
}

// MARK: - Robot Dance

struct RobotDanceAnimation: View {
    @State private var poseIndex: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    // Robot poses: (leftArmAngle, rightArmAngle, headTilt, legSpread)
    private let poses: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (-50, 50, 0, 0),
        (0, -60, 5, 10),
        (-70, 0, -5, -10),
        (-40, -40, 0, 5),
        (60, 60, 3, 0),
        (0, 0, -3, -5),
    ]

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let pose = poses[poseIndex % poses.count]
                let headTilt = reduceMotion ? CGFloat(0) : pose.2

                // Head (boxy/angular)
                let headRect = CGRect(x: center.x - 12 + headTilt, y: center.y - 48, width: 24, height: 22)
                context.stroke(
                    Path(roundedRect: headRect, cornerRadius: 2),
                    with: .color(.white.opacity(0.4)),
                    lineWidth: 1.5
                )

                // Antenna
                var antenna = Path()
                antenna.move(to: CGPoint(x: center.x + headTilt, y: center.y - 48))
                antenna.addLine(to: CGPoint(x: center.x + headTilt, y: center.y - 56))
                context.stroke(antenna, with: .color(.white.opacity(0.3)), lineWidth: 1)
                let dotRect = CGRect(x: center.x - 2 + headTilt, y: center.y - 59, width: 4, height: 4)
                context.fill(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.5)))

                // LED eyes
                for side in [-1.0, 1.0] {
                    let eyeRect = CGRect(x: center.x + side * 5 - 2.5 + headTilt, y: center.y - 42, width: 5, height: 3)
                    context.fill(
                        Path(roundedRect: eyeRect, cornerRadius: 1),
                        with: .color(.cyan.opacity(0.5))
                    )
                }

                // Torso (boxy)
                let torsoRect = CGRect(x: center.x - 14, y: center.y - 24, width: 28, height: 38)
                context.stroke(
                    Path(roundedRect: torsoRect, cornerRadius: 3),
                    with: .color(.white.opacity(0.3)),
                    lineWidth: 2
                )

                // Chest indicator
                let indicatorRect = CGRect(x: center.x - 3, y: center.y - 12, width: 6, height: 6)
                context.fill(
                    Path(roundedRect: indicatorRect, cornerRadius: 1),
                    with: .color(.red.opacity(poseIndex % 2 == 0 ? 0.4 : 0.15))
                )

                // Arms (jerky angular positions)
                let leftAngle = reduceMotion ? CGFloat(0) : pose.0
                let rightAngle = reduceMotion ? CGFloat(0) : pose.1
                for (side, angle) in [(-1.0, leftAngle), (1.0, rightAngle)] {
                    let shoulderX = center.x + CGFloat(side) * 14
                    let shoulderY = center.y - 20
                    let elbowX = shoulderX + CGFloat(side) * 20
                    let elbowY = shoulderY + 5
                    let handX = elbowX + CGFloat(side) * 5
                    let handY = elbowY + angle * 0.4

                    var arm = Path()
                    arm.move(to: CGPoint(x: shoulderX, y: shoulderY))
                    arm.addLine(to: CGPoint(x: elbowX, y: elbowY))
                    arm.addLine(to: CGPoint(x: handX, y: handY))
                    context.stroke(arm, with: .color(.white.opacity(0.4)), lineWidth: 2)

                    // Claw hand
                    let clawRect = CGRect(x: handX - 3, y: handY - 3, width: 6, height: 6)
                    context.stroke(
                        Path(roundedRect: clawRect, cornerRadius: 1),
                        with: .color(.white.opacity(0.35)),
                        lineWidth: 1
                    )
                }

                // Legs
                let legOffset = reduceMotion ? CGFloat(0) : pose.3
                var legs = Path()
                legs.move(to: CGPoint(x: center.x - 8, y: center.y + 14))
                legs.addLine(to: CGPoint(x: center.x - 14 + legOffset, y: center.y + 55))
                legs.move(to: CGPoint(x: center.x + 8, y: center.y + 14))
                legs.addLine(to: CGPoint(x: center.x + 14 - legOffset, y: center.y + 55))
                context.stroke(legs, with: .color(.white.opacity(0.3)), lineWidth: 2)
            }

            Text("beep boop")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.35))
                .offset(y: 60)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.15)) {
                poseIndex = (poseIndex + 1) % poses.count
            }
        }
    }
}

// MARK: - Butterfly Wings

struct ButterflyWingsAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let flapCycle = reduceMotion ? 0.5 : (sin(t * 2.0) * 0.5 + 0.5)
            let wingSpread = 0.3 + flapCycle * 0.7

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Upper wings
                for side in [-1.0, 1.0] {
                    let wingWidth = 40 * wingSpread
                    let wingPath = Path { path in
                        path.move(to: CGPoint(x: center.x, y: center.y - 5))
                        path.addQuadCurve(
                            to: CGPoint(x: center.x + side * wingWidth, y: center.y - 30),
                            control: CGPoint(x: center.x + side * wingWidth * 0.8, y: center.y - 45)
                        )
                        path.addQuadCurve(
                            to: CGPoint(x: center.x, y: center.y - 5),
                            control: CGPoint(x: center.x + side * wingWidth * 0.5, y: center.y - 10)
                        )
                    }

                    // Wing gradient fill
                    context.fill(wingPath, with: .color(.purple.opacity(0.12 + flapCycle * 0.08)))
                    context.stroke(wingPath, with: .color(.purple.opacity(0.35)), lineWidth: 1.5)

                    // Wing pattern dots
                    let dotX = center.x + side * wingWidth * 0.5
                    let dotY = center.y - 25
                    let dotRect = CGRect(x: dotX - 3, y: dotY - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.15)))
                }

                // Lower wings
                for side in [-1.0, 1.0] {
                    let wingWidth = 32 * wingSpread
                    let lowerWing = Path { path in
                        path.move(to: CGPoint(x: center.x, y: center.y))
                        path.addQuadCurve(
                            to: CGPoint(x: center.x + side * wingWidth, y: center.y + 15),
                            control: CGPoint(x: center.x + side * wingWidth * 0.9, y: center.y - 5)
                        )
                        path.addQuadCurve(
                            to: CGPoint(x: center.x, y: center.y),
                            control: CGPoint(x: center.x + side * wingWidth * 0.4, y: center.y + 25)
                        )
                    }
                    context.fill(lowerWing, with: .color(.blue.opacity(0.08 + flapCycle * 0.06)))
                    context.stroke(lowerWing, with: .color(.blue.opacity(0.3)), lineWidth: 1)
                }

                // Body (thin center line)
                var body = Path()
                body.move(to: CGPoint(x: center.x, y: center.y - 15))
                body.addLine(to: CGPoint(x: center.x, y: center.y + 15))
                context.stroke(body, with: .color(.white.opacity(0.4)), lineWidth: 2)

                // Head dot
                let headRect = CGRect(x: center.x - 3, y: center.y - 19, width: 6, height: 6)
                context.fill(Path(ellipseIn: headRect), with: .color(.white.opacity(0.4)))

                // Antennae
                for side in [-1.0, 1.0] {
                    var antenna = Path()
                    antenna.move(to: CGPoint(x: center.x, y: center.y - 18))
                    antenna.addQuadCurve(
                        to: CGPoint(x: center.x + side * 12, y: center.y - 32),
                        control: CGPoint(x: center.x + side * 4, y: center.y - 28)
                    )
                    context.stroke(antenna, with: .color(.white.opacity(0.3)), lineWidth: 1)
                    let tipRect = CGRect(x: center.x + side * 12 - 1.5, y: center.y - 33.5, width: 3, height: 3)
                    context.fill(Path(ellipseIn: tipRect), with: .color(.white.opacity(0.3)))
                }
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Mime Box

struct MimeBoxAnimation: View {
    @State private var wallIndex: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Dashed box outline
                let boxSize: CGFloat = 70
                let boxRect = CGRect(
                    x: center.x - boxSize / 2, y: center.y - boxSize / 2,
                    width: boxSize, height: boxSize
                )
                context.stroke(
                    Path(roundedRect: boxRect, cornerRadius: 2),
                    with: .color(.white.opacity(0.15)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )

                // Highlight the wall being pushed
                let wallAlpha = reduceMotion ? 0.2 : 0.3
                switch wallIndex {
                case 0: // Left wall
                    var wall = Path()
                    wall.move(to: CGPoint(x: center.x - boxSize / 2, y: center.y - boxSize / 2))
                    wall.addLine(to: CGPoint(x: center.x - boxSize / 2, y: center.y + boxSize / 2))
                    context.stroke(wall, with: .color(.white.opacity(wallAlpha)), lineWidth: 2.5)
                case 1: // Top wall
                    var wall = Path()
                    wall.move(to: CGPoint(x: center.x - boxSize / 2, y: center.y - boxSize / 2))
                    wall.addLine(to: CGPoint(x: center.x + boxSize / 2, y: center.y - boxSize / 2))
                    context.stroke(wall, with: .color(.white.opacity(wallAlpha)), lineWidth: 2.5)
                case 2: // Right wall
                    var wall = Path()
                    wall.move(to: CGPoint(x: center.x + boxSize / 2, y: center.y - boxSize / 2))
                    wall.addLine(to: CGPoint(x: center.x + boxSize / 2, y: center.y + boxSize / 2))
                    context.stroke(wall, with: .color(.white.opacity(wallAlpha)), lineWidth: 2.5)
                default: // Bottom wall
                    var wall = Path()
                    wall.move(to: CGPoint(x: center.x - boxSize / 2, y: center.y + boxSize / 2))
                    wall.addLine(to: CGPoint(x: center.x + boxSize / 2, y: center.y + boxSize / 2))
                    context.stroke(wall, with: .color(.white.opacity(wallAlpha)), lineWidth: 2.5)
                }

                // Hands pressing against walls
                let handSize: CGFloat = 8
                switch wallIndex {
                case 0: // Left wall - hands pressing left
                    for yOff in [-12.0, 12.0] {
                        let hx = center.x - boxSize / 2 + 2
                        let hy = center.y + CGFloat(yOff)
                        let handRect = CGRect(x: hx - handSize / 2, y: hy - handSize / 2, width: handSize, height: handSize)
                        context.fill(Path(ellipseIn: handRect), with: .color(.white.opacity(0.25)))
                        context.stroke(Path(ellipseIn: handRect), with: .color(.white.opacity(0.35)), lineWidth: 1)
                    }
                case 1: // Top wall - hands pressing up
                    for xOff in [-12.0, 12.0] {
                        let hx = center.x + CGFloat(xOff)
                        let hy = center.y - boxSize / 2 + 2
                        let handRect = CGRect(x: hx - handSize / 2, y: hy - handSize / 2, width: handSize, height: handSize)
                        context.fill(Path(ellipseIn: handRect), with: .color(.white.opacity(0.25)))
                        context.stroke(Path(ellipseIn: handRect), with: .color(.white.opacity(0.35)), lineWidth: 1)
                    }
                case 2: // Right wall - hands pressing right
                    for yOff in [-12.0, 12.0] {
                        let hx = center.x + boxSize / 2 - 2
                        let hy = center.y + CGFloat(yOff)
                        let handRect = CGRect(x: hx - handSize / 2, y: hy - handSize / 2, width: handSize, height: handSize)
                        context.fill(Path(ellipseIn: handRect), with: .color(.white.opacity(0.25)))
                        context.stroke(Path(ellipseIn: handRect), with: .color(.white.opacity(0.35)), lineWidth: 1)
                    }
                default: // Bottom wall - hands pressing down
                    for xOff in [-12.0, 12.0] {
                        let hx = center.x + CGFloat(xOff)
                        let hy = center.y + boxSize / 2 - 2
                        let handRect = CGRect(x: hx - handSize / 2, y: hy - handSize / 2, width: handSize, height: handSize)
                        context.fill(Path(ellipseIn: handRect), with: .color(.white.opacity(0.25)))
                        context.stroke(Path(ellipseIn: handRect), with: .color(.white.opacity(0.35)), lineWidth: 1)
                    }
                }

                // Face in center (worried expression)
                let faceY = center.y - 2
                // Eyes
                for side in [-1.0, 1.0] {
                    let eyeRect = CGRect(x: center.x + side * 6 - 2, y: faceY - 6, width: 4, height: 5)
                    context.fill(Path(ellipseIn: eyeRect), with: .color(.white.opacity(0.4)))
                }
                // Worried mouth
                var mouth = Path()
                mouth.move(to: CGPoint(x: center.x - 5, y: faceY + 6))
                mouth.addQuadCurve(
                    to: CGPoint(x: center.x + 5, y: faceY + 6),
                    control: CGPoint(x: center.x, y: faceY + 2)
                )
                context.stroke(mouth, with: .color(.white.opacity(0.3)), lineWidth: 1)
            }

            Text(wallIndex == 3 ? "where's the door?" : "push...")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
                .offset(y: 65)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                wallIndex = (wallIndex + 1) % 4
            }
        }
    }
}

// MARK: - Victory Lap

struct VictoryLapAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let sparklePhase = reduceMotion ? 0.5 : t

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Trophy body
                let cupTop: CGFloat = center.y - 30
                let cupBottom: CGFloat = center.y + 5

                // Cup shape
                var cup = Path()
                cup.move(to: CGPoint(x: center.x - 20, y: cupTop))
                cup.addLine(to: CGPoint(x: center.x - 15, y: cupBottom))
                cup.addQuadCurve(
                    to: CGPoint(x: center.x + 15, y: cupBottom),
                    control: CGPoint(x: center.x, y: cupBottom + 8)
                )
                cup.addLine(to: CGPoint(x: center.x + 20, y: cupTop))
                cup.closeSubpath()
                context.fill(cup, with: .color(.yellow.opacity(0.1)))
                context.stroke(cup, with: .color(.yellow.opacity(0.4)), lineWidth: 1.5)

                // Cup rim
                var rim = Path()
                rim.move(to: CGPoint(x: center.x - 22, y: cupTop))
                rim.addLine(to: CGPoint(x: center.x + 22, y: cupTop))
                context.stroke(rim, with: .color(.yellow.opacity(0.45)), lineWidth: 2)

                // Handles
                for side in [-1.0, 1.0] {
                    var handle = Path()
                    let hx = center.x + side * 20
                    handle.move(to: CGPoint(x: hx, y: cupTop + 8))
                    handle.addQuadCurve(
                        to: CGPoint(x: hx, y: cupBottom - 5),
                        control: CGPoint(x: hx + side * 12, y: center.y - 12)
                    )
                    context.stroke(handle, with: .color(.yellow.opacity(0.35)), lineWidth: 1.5)
                }

                // Stem
                var stem = Path()
                stem.move(to: CGPoint(x: center.x, y: cupBottom + 3))
                stem.addLine(to: CGPoint(x: center.x, y: center.y + 20))
                context.stroke(stem, with: .color(.yellow.opacity(0.3)), lineWidth: 2)

                // Base
                var base = Path()
                base.move(to: CGPoint(x: center.x - 16, y: center.y + 20))
                base.addLine(to: CGPoint(x: center.x + 16, y: center.y + 20))
                context.stroke(base, with: .color(.yellow.opacity(0.35)), lineWidth: 2.5)

                // Star on trophy
                let starCenter = CGPoint(x: center.x, y: center.y - 15)
                var star = Path()
                for i in 0..<5 {
                    let outerAngle = CGFloat(i) * (2 * .pi / 5) - .pi / 2
                    let innerAngle = outerAngle + .pi / 5
                    let outerPoint = CGPoint(
                        x: starCenter.x + cos(outerAngle) * 7,
                        y: starCenter.y + sin(outerAngle) * 7
                    )
                    let innerPoint = CGPoint(
                        x: starCenter.x + cos(innerAngle) * 3,
                        y: starCenter.y + sin(innerAngle) * 3
                    )
                    if i == 0 { star.move(to: outerPoint) }
                    else { star.addLine(to: outerPoint) }
                    star.addLine(to: innerPoint)
                }
                star.closeSubpath()
                context.fill(star, with: .color(.yellow.opacity(0.3)))

                // Confetti / sparkles
                let sparkleCount = 12
                for i in 0..<sparkleCount {
                    let seed = Double(i) * 2.39996
                    let sx = center.x + CGFloat(sin(seed * 3.7 + sparklePhase * 0.5) * 65)
                    let rawY = center.y - 50 + CGFloat(
                        (seed * 17.3 + sparklePhase * 30).truncatingRemainder(dividingBy: 130)
                    )
                    let sy = rawY
                    let sparkleAlpha = reduceMotion ? 0.15 : (sin(sparklePhase * 2 + seed) * 0.12 + 0.18)
                    let colors: [Color] = [.yellow, .pink, .cyan, .orange, .purple, .green]
                    let color = colors[i % colors.count]

                    if i % 3 == 0 {
                        // Small rectangle confetti
                        let confetti = CGRect(x: sx - 2, y: sy - 1, width: 4, height: 2)
                        context.fill(Path(confetti), with: .color(color.opacity(sparkleAlpha)))
                    } else {
                        // Dot confetti
                        let dotRect = CGRect(x: sx - 1.5, y: sy - 1.5, width: 3, height: 3)
                        context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(sparkleAlpha)))
                    }
                }
            }
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Balloon Breath

struct BalloonBreathAnimation: View {
    @State private var phase: Int = 0 // 0=deflated, 1=inflating, 2=flying
    @State private var balloonSize: CGFloat = 10
    @State private var flyOffset: CGPoint = .zero
    @State private var flyRotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                if phase == 2 {
                    // Flying balloon (erratic)
                    let bx = center.x + flyOffset.x
                    let by = center.y + flyOffset.y
                    let balloonRect = CGRect(x: bx - 15, y: by - 18, width: 30, height: 36)
                    context.fill(Path(ellipseIn: balloonRect), with: .color(.red.opacity(0.15)))
                    context.stroke(Path(ellipseIn: balloonRect), with: .color(.red.opacity(0.35)), lineWidth: 1.5)

                    // Squiggly tail (deflating)
                    var tail = Path()
                    tail.move(to: CGPoint(x: bx, y: by + 18))
                    tail.addCurve(
                        to: CGPoint(x: bx + 10, y: by + 35),
                        control1: CGPoint(x: bx - 8, y: by + 24),
                        control2: CGPoint(x: bx + 12, y: by + 28)
                    )
                    context.stroke(tail, with: .color(.red.opacity(0.25)), lineWidth: 1)
                } else {
                    // Balloon inflating
                    let radius = balloonSize
                    let balloonRect = CGRect(
                        x: center.x - radius, y: center.y - 10 - radius * 1.2,
                        width: radius * 2, height: radius * 2.4
                    )
                    context.fill(Path(ellipseIn: balloonRect), with: .color(.red.opacity(0.08 + Double(radius) * 0.003)))
                    context.stroke(Path(ellipseIn: balloonRect), with: .color(.red.opacity(0.35)), lineWidth: 1.5)

                    // Knot at bottom
                    let knotY = center.y - 10 + radius * 1.2
                    var knot = Path()
                    knot.move(to: CGPoint(x: center.x - 3, y: knotY))
                    knot.addLine(to: CGPoint(x: center.x, y: knotY + 5))
                    knot.addLine(to: CGPoint(x: center.x + 3, y: knotY))
                    context.stroke(knot, with: .color(.red.opacity(0.3)), lineWidth: 1)

                    // String
                    var string = Path()
                    string.move(to: CGPoint(x: center.x, y: knotY + 5))
                    string.addQuadCurve(
                        to: CGPoint(x: center.x + 5, y: knotY + 30),
                        control: CGPoint(x: center.x - 8, y: knotY + 18)
                    )
                    context.stroke(string, with: .color(.white.opacity(0.2)), lineWidth: 0.8)

                    // Shine highlight
                    if radius > 15 {
                        let shineRect = CGRect(
                            x: center.x - radius * 0.4, y: center.y - 10 - radius * 0.8,
                            width: radius * 0.35, height: radius * 0.5
                        )
                        context.fill(Path(ellipseIn: shineRect), with: .color(.white.opacity(0.08)))
                    }
                }
            }

            Text(phase == 0 ? "inhale..." : phase == 1 ? "bigger..." : "pbbbt!")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .offset(y: 60)
        }
        .frame(width: 180, height: 180)
        .onReceive(timer) { _ in
            startCycle()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { startCycle() }
        }
    }

    private func startCycle() {
        // Reset
        phase = 0
        balloonSize = 10
        flyOffset = .zero

        // Inflate
        withAnimation(reduceMotion ? .none : .easeOut(duration: 2.0)) {
            phase = 1
            balloonSize = 35
        }

        // Release and fly
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(reduceMotion ? .none : .interpolatingSpring(stiffness: 40, damping: 3)) {
                phase = 2
                flyOffset = CGPoint(x: CGFloat.random(in: -50...50), y: CGFloat.random(in: -60 ... -30))
            }
        }

        // Reset for next cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(reduceMotion ? .none : .easeIn(duration: 0.3)) {
                phase = 0
                balloonSize = 10
                flyOffset = .zero
            }
        }
    }
}

// MARK: - Ragdoll Shake

struct RagdollShakeAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let shakeSpeed: Double = reduceMotion ? 0.0 : 6.0
            let headShake = sin(t * shakeSpeed) * 5
            let bodyWobble = sin(t * shakeSpeed * 0.7 + 0.5) * 4

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Head (wobbling)
                let headX = center.x + CGFloat(headShake)
                let headRect = CGRect(x: headX - 11, y: center.y - 48, width: 22, height: 22)
                context.stroke(Path(ellipseIn: headRect), with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Dizzy eyes (spirals represented as dots)
                for side in [-1.0, 1.0] {
                    let eyeX = headX + side * 5
                    let eyeY = center.y - 40
                    let eyeRect = CGRect(x: eyeX - 2, y: eyeY - 2, width: 4, height: 4)
                    context.fill(Path(ellipseIn: eyeRect), with: .color(.white.opacity(0.4)))
                }

                // Loose mouth
                var mouth = Path()
                let mouthX = headX
                mouth.move(to: CGPoint(x: mouthX - 4, y: center.y - 33))
                mouth.addQuadCurve(
                    to: CGPoint(x: mouthX + 4, y: center.y - 33),
                    control: CGPoint(x: mouthX, y: center.y - 29)
                )
                context.stroke(mouth, with: .color(.white.opacity(0.3)), lineWidth: 1)

                // Torso (wobbly)
                let torsoBottom = CGPoint(x: center.x + CGFloat(bodyWobble), y: center.y + 18)
                var torso = Path()
                torso.move(to: CGPoint(x: headX, y: center.y - 26))
                torso.addQuadCurve(
                    to: torsoBottom,
                    control: CGPoint(x: center.x + CGFloat(bodyWobble * 0.5), y: center.y - 5)
                )
                context.stroke(torso, with: .color(.white.opacity(0.3)), lineWidth: 2)

                // Floppy arms (each with different frequency for noodly feel)
                let leftArmWobble = sin(t * shakeSpeed * 1.3) * 15
                let rightArmWobble = sin(t * shakeSpeed * 1.1 + 1.0) * 15
                let leftForearmWobble = sin(t * shakeSpeed * 1.6 + 0.5) * 10
                let rightForearmWobble = sin(t * shakeSpeed * 1.4 + 1.5) * 10

                // Left arm
                let leftShoulderX = headX - 3
                let leftShoulderY = center.y - 20
                var leftArm = Path()
                leftArm.move(to: CGPoint(x: leftShoulderX, y: leftShoulderY))
                let leftElbow = CGPoint(
                    x: center.x - 28 + CGFloat(leftArmWobble),
                    y: center.y - 5
                )
                leftArm.addLine(to: leftElbow)
                leftArm.addLine(to: CGPoint(
                    x: leftElbow.x - 10 + CGFloat(leftForearmWobble),
                    y: center.y + 15
                ))
                context.stroke(leftArm, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Right arm
                let rightShoulderX = headX + 3
                let rightShoulderY = center.y - 20
                var rightArm = Path()
                rightArm.move(to: CGPoint(x: rightShoulderX, y: rightShoulderY))
                let rightElbow = CGPoint(
                    x: center.x + 28 + CGFloat(rightArmWobble),
                    y: center.y - 5
                )
                rightArm.addLine(to: rightElbow)
                rightArm.addLine(to: CGPoint(
                    x: rightElbow.x + 10 + CGFloat(rightForearmWobble),
                    y: center.y + 15
                ))
                context.stroke(rightArm, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

                // Floppy legs
                let leftLegWobble = sin(t * shakeSpeed * 0.9 + 2.0) * 8
                let rightLegWobble = sin(t * shakeSpeed * 1.0 + 3.0) * 8
                let leftKneeWobble = sin(t * shakeSpeed * 1.2 + 2.5) * 6
                let rightKneeWobble = sin(t * shakeSpeed * 1.1 + 3.5) * 6

                // Left leg
                var leftLeg = Path()
                leftLeg.move(to: torsoBottom)
                let leftKnee = CGPoint(
                    x: center.x - 15 + CGFloat(leftLegWobble),
                    y: center.y + 38
                )
                leftLeg.addLine(to: leftKnee)
                leftLeg.addLine(to: CGPoint(
                    x: leftKnee.x - 5 + CGFloat(leftKneeWobble),
                    y: center.y + 55
                ))
                context.stroke(leftLeg, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

                // Right leg
                var rightLeg = Path()
                rightLeg.move(to: torsoBottom)
                let rightKnee = CGPoint(
                    x: center.x + 15 + CGFloat(rightLegWobble),
                    y: center.y + 38
                )
                rightLeg.addLine(to: rightKnee)
                rightLeg.addLine(to: CGPoint(
                    x: rightKnee.x + 5 + CGFloat(rightKneeWobble),
                    y: center.y + 55
                ))
                context.stroke(rightLeg, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

                // Motion lines
                for i in 0..<4 {
                    let lineT = t * 3.0 + Double(i) * 1.5
                    let lx = center.x + CGFloat(sin(lineT) * 50)
                    let ly = center.y - 15 + CGFloat(cos(lineT * 0.6) * 30)
                    let lineAlpha = reduceMotion ? 0.1 : (sin(lineT * 2) * 0.08 + 0.1)
                    var motionLine = Path()
                    motionLine.move(to: CGPoint(x: lx - 4, y: ly))
                    motionLine.addLine(to: CGPoint(x: lx + 4, y: ly))
                    context.stroke(motionLine, with: .color(.white.opacity(lineAlpha)), lineWidth: 1)
                }
            }
        }
        .frame(width: 180, height: 180)
    }
}
