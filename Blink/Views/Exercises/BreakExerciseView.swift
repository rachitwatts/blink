import SwiftUI

struct BreakExerciseView: View {
    let exercise: BreakExercise
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            // Exercise title with category icon
            HStack(spacing: 8) {
                Image(systemName: exercise.sfSymbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Text(exercise.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -8)

            // Animation
            animationView
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.9)

            // Instruction text
            Text(exercise.instruction)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 400)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.8)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var animationView: some View {
        switch exercise {
        case .palming:
            PalmingAnimation()
        case .focusShift:
            FocusShiftAnimation()
        case .slowBlinks:
            SlowBlinksAnimation()
        case .eyeCircles:
            EyeCirclesAnimation()
        case .figureEight:
            FigureEightAnimation()
        case .nearFarFocus:
            NearFarFocusAnimation()
        case .eyeSqueeze:
            EyeSqueezeAnimation()
        case .deepEyeRest:
            DeepEyeRestAnimation()
        case .deepBreathing:
            DeepBreathingAnimation()
        case .boxBreathing:
            BoxBreathingAnimation()
        case .neckRolls:
            NeckRollsAnimation()
        case .shoulderShrugs:
            ShoulderShrugsAnimation()
        case .wristStretches:
            WristStretchesAnimation()
        case .templeMassage:
            TempleMassageAnimation()
        case .jawRelease:
            JawReleaseAnimation()
        case .spinalTwist:
            SpinalTwistAnimation()
        case .handMassage:
            HandMassageAnimation()
        case .chestOpener:
            ChestOpenerAnimation()
        case .sideNeckStretch:
            SideNeckStretchAnimation()
        case .ankleCircles:
            AnkleCirclesAnimation()
        case .dramaticSigh:
            DramaticSighAnimation()
        case .catStretch:
            CatStretchAnimation()
        case .invisiblePiano:
            InvisiblePianoAnimation()
        case .powerPose:
            PowerPoseAnimation()
        case .faceScrunch:
            FaceScrunchAnimation()
        case .tRexArms:
            TRexArmsAnimation()
        case .shoulderShimmy:
            ShoulderShimmyAnimation()
        case .existentialStare:
            ExistentialStareAnimation()
        case .deskDrumroll:
            DeskDrumrollAnimation()
        case .starJumps:
            StarJumpsAnimation()
        case .zombieArms:
            ZombieArmsAnimation()
        case .penguinWaddle:
            PenguinWaddleAnimation()
        case .invisibleJumpRope:
            InvisibleJumpRopeAnimation()
        case .operaSinger:
            OperaSingerAnimation()
        case .robotDance:
            RobotDanceAnimation()
        case .butterflyWings:
            ButterflyWingsAnimation()
        case .mimeBox:
            MimeBoxAnimation()
        case .victoryLap:
            VictoryLapAnimation()
        case .balloonBreath:
            BalloonBreathAnimation()
        case .ragdollShake:
            RagdollShakeAnimation()
        }
    }
}

#Preview("Gallery") {
    let background = Color(red: 0.05, green: 0.05, blue: 0.12)
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    ScrollView {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(BreakExercise.allCases) { exercise in
                VStack(spacing: 8) {
                    BreakExerciseView(exercise: exercise)
                        .frame(height: 280)

                    Text(exercise.category.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(
                            exercise.category == .eye ? .cyan.opacity(0.6) :
                            exercise.category == .breathing ? .purple.opacity(0.6) :
                            exercise.category == .fun ? .pink.opacity(0.6) :
                            .orange.opacity(0.6)
                        )
                        .padding(.bottom, 8)
                }
                .background(background)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .padding(20)
    }
    .background(background)
    .frame(width: 1200, height: 900)
}
