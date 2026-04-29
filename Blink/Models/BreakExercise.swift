import Foundation

enum BreakExerciseCategory: String, CaseIterable {
    case eye
    case breathing
    case body
    case fun
}

enum BreakExercise: String, CaseIterable, Identifiable {
    // Eye exercises (2x weight — core mission)
    case palming
    case focusShift
    case slowBlinks
    case eyeCircles
    case figureEight
    case nearFarFocus
    case eyeSqueeze
    case deepEyeRest

    // Breathing exercises (1x weight)
    case deepBreathing
    case boxBreathing

    // Body exercises (1x weight)
    case neckRolls
    case shoulderShrugs
    case wristStretches
    case templeMassage
    case jawRelease
    case spinalTwist
    case handMassage
    case chestOpener
    case sideNeckStretch
    case ankleCircles

    // Fun exercises (1x weight — chaotic good energy)
    case dramaticSigh
    case catStretch
    case invisiblePiano
    case powerPose
    case faceScrunch
    case tRexArms
    case shoulderShimmy
    case existentialStare
    case deskDrumroll
    case starJumps
    case zombieArms
    case penguinWaddle
    case invisibleJumpRope
    case operaSinger
    case robotDance
    case butterflyWings
    case mimeBox
    case victoryLap
    case balloonBreath
    case ragdollShake

    var id: String { rawValue }

    var category: BreakExerciseCategory {
        switch self {
        case .palming, .focusShift, .slowBlinks, .eyeCircles,
             .figureEight, .nearFarFocus, .eyeSqueeze, .deepEyeRest:
            return .eye
        case .deepBreathing, .boxBreathing:
            return .breathing
        case .neckRolls, .shoulderShrugs, .wristStretches, .templeMassage,
             .jawRelease, .spinalTwist, .handMassage, .chestOpener,
             .sideNeckStretch, .ankleCircles:
            return .body
        case .dramaticSigh, .catStretch, .invisiblePiano, .powerPose,
             .faceScrunch, .tRexArms, .shoulderShimmy, .existentialStare,
             .deskDrumroll, .starJumps, .zombieArms, .penguinWaddle,
             .invisibleJumpRope, .operaSinger, .robotDance, .butterflyWings,
             .mimeBox, .victoryLap, .balloonBreath, .ragdollShake:
            return .fun
        }
    }

    var selectionWeight: Int {
        switch category {
        case .eye: return 2
        case .breathing: return 1
        case .body: return 1
        case .fun: return 1
        }
    }

    var instruction: String {
        switch self {
        case .palming:
            return "Cup your hands over your closed eyes. Feel the warmth."
        case .focusShift:
            return "Look at something 20 feet away for 20 seconds."
        case .slowBlinks:
            return "Close your eyes slowly… hold… open."
        case .eyeCircles:
            return "Roll your eyes in a wide circle, slowly."
        case .figureEight:
            return "Trace a large figure 8 with your eyes."
        case .nearFarFocus:
            return "Focus on your thumb up close, then something far away."
        case .eyeSqueeze:
            return "Squeeze eyes shut for 3 seconds, then open wide."
        case .deepEyeRest:
            return "Close your eyes. Let them feel heavy and relaxed."
        case .deepBreathing:
            return "Breathe in 4s… hold 4s… out 6s."
        case .boxBreathing:
            return "Breathe in 4s… hold 4s… out 4s… hold 4s."
        case .neckRolls:
            return "Slowly roll your head in a circle."
        case .shoulderShrugs:
            return "Raise shoulders to your ears… hold… release."
        case .wristStretches:
            return "Extend your arm, pull fingers back gently."
        case .templeMassage:
            return "Gently massage your temples in small circles."
        case .jawRelease:
            return "Open your mouth wide, stretch, then relax."
        case .spinalTwist:
            return "Sit tall and twist gently to each side."
        case .handMassage:
            return "Squeeze and release each finger slowly."
        case .chestOpener:
            return "Clasp hands behind your back. Open your chest."
        case .sideNeckStretch:
            return "Tilt your ear toward your shoulder. Hold each side."
        case .ankleCircles:
            return "Rotate your ankles in slow circles."
        case .dramaticSigh:
            return "Let out the most dramatic sigh of your life. Really sell it."
        case .catStretch:
            return "Arch your back like a cat who just spotted a cucumber."
        case .invisiblePiano:
            return "Play an imaginary piano. Feel the concerto flowing through you."
        case .powerPose:
            return "Stand up. Hands on hips. You are the CEO of this break."
        case .faceScrunch:
            return "Scrunch your face as tight as possible. Now release. Beautiful."
        case .tRexArms:
            return "Tuck your elbows in. Wiggle your tiny T-Rex arms. Rawr."
        case .shoulderShimmy:
            return "Shimmy your shoulders like nobody's watching. Because they're not."
        case .existentialStare:
            return "Stare into the void. Let the void stare back. Blink first."
        case .deskDrumroll:
            return "Air drum a dramatic drumroll. Finish with a cymbal crash."
        case .starJumps:
            return "Do three star jumps. Yes, right now. We'll wait."
        case .zombieArms:
            return "Stretch your arms out. Shamble forward. You are now a desk zombie."
        case .penguinWaddle:
            return "Stand up. Tuck arms to sides. Waddle. You're a penguin now."
        case .invisibleJumpRope:
            return "Grab your invisible rope. Jump! Jump! Cardio counts even if imaginary."
        case .operaSinger:
            return "Open your mouth. Belt out a silent high note. Hold it. Bravo."
        case .robotDance:
            return "Move in stiff, jerky motions. You are a robot. Beep boop."
        case .butterflyWings:
            return "Extend your arms. Flap slowly like a majestic butterfly."
        case .mimeBox:
            return "You're trapped in an invisible box. Push the walls. Find the door."
        case .victoryLap:
            return "Stand up. Do a small celebratory lap around your chair. You earned it."
        case .balloonBreath:
            return "Pretend to inflate a balloon. Bigger\u{2026} bigger\u{2026} now let it fly. Pbbbt."
        case .ragdollShake:
            return "Go completely limp. Shake out your arms, legs, everything. Be a noodle."
        }
    }

    var sfSymbol: String {
        switch self {
        case .palming: return "hand.raised.fingers.spread"
        case .focusShift: return "eye.trianglebadge.exclamationmark"
        case .slowBlinks: return "eye"
        case .eyeCircles: return "circle.dotted"
        case .figureEight: return "infinity"
        case .nearFarFocus: return "arrow.up.left.and.arrow.down.right"
        case .eyeSqueeze: return "eye.slash"
        case .deepEyeRest: return "moon.stars"
        case .deepBreathing: return "wind"
        case .boxBreathing: return "square"
        case .neckRolls: return "arrow.triangle.2.circlepath"
        case .shoulderShrugs: return "arrow.up.and.down"
        case .wristStretches: return "hand.wave"
        case .templeMassage: return "brain.head.profile"
        case .jawRelease: return "mouth"
        case .spinalTwist: return "arrow.left.arrow.right"
        case .handMassage: return "hand.point.up"
        case .chestOpener: return "arrow.up.left.and.arrow.down.right.circle"
        case .sideNeckStretch: return "figure.stand"
        case .ankleCircles: return "figure.walk"
        case .dramaticSigh: return "cloud"
        case .catStretch: return "cat"
        case .invisiblePiano: return "pianokeys"
        case .powerPose: return "figure.arms.open"
        case .faceScrunch: return "face.smiling"
        case .tRexArms: return "fossil.shell"
        case .shoulderShimmy: return "sparkles"
        case .existentialStare: return "eye.circle"
        case .deskDrumroll: return "drum.fill"
        case .starJumps: return "star"
        case .zombieArms: return "figure.walk.motion"
        case .penguinWaddle: return "bird"
        case .invisibleJumpRope: return "figure.jumprope"
        case .operaSinger: return "music.mic"
        case .robotDance: return "gearshape.2"
        case .butterflyWings: return "leaf"
        case .mimeBox: return "square.dashed"
        case .victoryLap: return "trophy"
        case .balloonBreath: return "balloon"
        case .ragdollShake: return "figure.flexibility"
        }
    }

    var title: String {
        switch self {
        case .palming: return "Palming"
        case .focusShift: return "20-20-20"
        case .slowBlinks: return "Slow Blinks"
        case .eyeCircles: return "Eye Circles"
        case .figureEight: return "Figure Eight"
        case .nearFarFocus: return "Near-Far Focus"
        case .eyeSqueeze: return "Eye Squeeze"
        case .deepEyeRest: return "Deep Eye Rest"
        case .deepBreathing: return "Deep Breathing"
        case .boxBreathing: return "Box Breathing"
        case .neckRolls: return "Neck Rolls"
        case .shoulderShrugs: return "Shoulder Shrugs"
        case .wristStretches: return "Wrist Stretches"
        case .templeMassage: return "Temple Massage"
        case .jawRelease: return "Jaw Release"
        case .spinalTwist: return "Spinal Twist"
        case .handMassage: return "Hand Massage"
        case .chestOpener: return "Chest Opener"
        case .sideNeckStretch: return "Side Neck Stretch"
        case .ankleCircles: return "Ankle Circles"
        case .dramaticSigh: return "Dramatic Sigh"
        case .catStretch: return "Cat Stretch"
        case .invisiblePiano: return "Invisible Piano"
        case .powerPose: return "Power Pose"
        case .faceScrunch: return "Face Scrunch"
        case .tRexArms: return "T-Rex Arms"
        case .shoulderShimmy: return "Shoulder Shimmy"
        case .existentialStare: return "Existential Stare"
        case .deskDrumroll: return "Desk Drumroll"
        case .starJumps: return "Star Jumps"
        case .zombieArms: return "Zombie Arms"
        case .penguinWaddle: return "Penguin Waddle"
        case .invisibleJumpRope: return "Invisible Jump Rope"
        case .operaSinger: return "Opera Singer"
        case .robotDance: return "Robot Dance"
        case .butterflyWings: return "Butterfly Wings"
        case .mimeBox: return "Mime Box"
        case .victoryLap: return "Victory Lap"
        case .balloonBreath: return "Balloon Breath"
        case .ragdollShake: return "Ragdoll Shake"
        }
    }
}

enum BreakContentMode: String, CaseIterable, Identifiable {
    case guided = "guided"
    case staticMessage = "static"
    case none = "none"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .guided: return "Guided exercises"
        case .staticMessage: return "Static message"
        case .none: return "None"
        }
    }
}
