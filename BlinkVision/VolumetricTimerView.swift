import SwiftUI
import RealityKit

struct VolumetricTimerView: View {

    @ObservedObject private var appState = AppState.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private let dotCount = 60
    private let ringRadius: Float = 0.1
    private let outerRadius: Float = 0.07
    private let dotRadius: Float = 0.004

    private class RenderState {
        var lastLitCount: Int = -1
        var lastColorIndex: Int = -1
    }
    @State private var renderState = RenderState()

    var body: some View {
        RealityView { content, attachments in
            let root = Entity()
            root.name = "timerRoot"

            let outerOrb = ModelEntity(
                mesh: .generateSphere(radius: outerRadius),
                materials: [makeOrbMaterial(.systemBlue)]
            )
            outerOrb.name = "outerOrb"
            root.addChild(outerOrb)

            let fillOrb = ModelEntity(
                mesh: .generateSphere(radius: 0.01),
                materials: [makeFillMaterial(.systemBlue)]
            )
            fillOrb.name = "fillOrb"
            root.addChild(fillOrb)

            let ring = Entity()
            ring.name = "progressRing"
            for i in 0..<dotCount {
                let angle = Float(i) / Float(dotCount) * 2 * .pi - .pi / 2
                let x = ringRadius * cos(angle)
                let z = ringRadius * sin(angle)
                let dot = ModelEntity(
                    mesh: .generateSphere(radius: dotRadius),
                    materials: [makeDimDotMaterial()]
                )
                dot.name = "dot_\(i)"
                dot.position = [x, 0, z]
                ring.addChild(dot)
            }
            root.addChild(ring)

            if let timeAttachment = attachments.entity(for: "timeDisplay") {
                timeAttachment.position = [0, 0.11, 0]
                timeAttachment.components.set(BillboardComponent())
                root.addChild(timeAttachment)
            }

            content.add(root)
        } update: { content, _ in
            guard let root = content.entities.first(where: { $0.name == "timerRoot" }) else { return }

            let color = accentUIColor
            let colorIndex = colorIndexValue
            let progress = appState.isOverlayVisible ? 1.0 : appState.workProgress
            let litCount = Int(Double(dotCount) * progress)

            if colorIndex != renderState.lastColorIndex {
                if let orb = root.findEntity(named: "outerOrb") as? ModelEntity {
                    orb.model?.materials = [makeOrbMaterial(color)]
                }
                if let fill = root.findEntity(named: "fillOrb") as? ModelEntity {
                    fill.model?.materials = [makeFillMaterial(color)]
                }
            }

            if let fill = root.findEntity(named: "fillOrb") as? ModelEntity {
                let fillScale = Float(max(0.05, progress)) * outerRadius * 0.9
                fill.scale = SIMD3<Float>(repeating: fillScale / 0.01)
            }

            if litCount != renderState.lastLitCount || colorIndex != renderState.lastColorIndex {
                if let ring = root.findEntity(named: "progressRing") {
                    let litMat = makeLitDotMaterial(color)
                    let dimMat = makeDimDotMaterial()
                    for i in 0..<dotCount {
                        guard let dot = ring.findEntity(named: "dot_\(i)") as? ModelEntity else { continue }
                        let isLit = i < litCount
                        dot.model?.materials = [isLit ? litMat : dimMat]
                        dot.scale = isLit ? SIMD3<Float>(repeating: 1.3) : SIMD3<Float>(repeating: 1.0)
                    }
                }
            }

            renderState.lastLitCount = litCount
            renderState.lastColorIndex = colorIndex
        } attachments: {
            Attachment(id: "timeDisplay") {
                Text(appState.displayTime)
                    .font(.system(size: 36, weight: .thin, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .onDisappear {
            openWindow(id: "main-timer")
        }
        .onReceive(AppState.shared.$isOverlayVisible) { visible in
            if visible {
                dismissWindow(id: "volumetric-timer")
            }
        }
    }

    // MARK: - Materials

    private func makeOrbMaterial(_ color: UIColor) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color.withAlphaComponent(0.2))
        m.roughness = .init(floatLiteral: 0.1)
        m.blending = .transparent(opacity: .init(floatLiteral: 0.3))
        m.clearcoat = .init(floatLiteral: 1.0)
        m.clearcoatRoughness = .init(floatLiteral: 0.05)
        m.emissiveColor = .init(color: color.withAlphaComponent(0.2))
        m.emissiveIntensity = 0.3
        return m
    }

    private func makeFillMaterial(_ color: UIColor) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color.withAlphaComponent(0.6))
        m.roughness = .init(floatLiteral: 0.3)
        m.blending = .transparent(opacity: .init(floatLiteral: 0.7))
        m.emissiveColor = .init(color: color.withAlphaComponent(0.5))
        m.emissiveIntensity = 0.6
        return m
    }

    private func makeLitDotMaterial(_ color: UIColor) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.emissiveColor = .init(color: color)
        m.emissiveIntensity = 1.0
        m.roughness = .init(floatLiteral: 0.2)
        return m
    }

    private func makeDimDotMaterial() -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .systemGray3.withAlphaComponent(0.3))
        m.roughness = .init(floatLiteral: 0.6)
        return m
    }

    // MARK: - State

    private var accentUIColor: UIColor {
        if appState.isOverlayVisible { return .systemGreen }
        if appState.timerState == .workPaused { return .systemGray }
        let p = appState.workProgress
        if p < 0.7 { return .systemBlue }
        if p < 0.9 { return .systemOrange }
        return .systemRed
    }

    private var colorIndexValue: Int {
        if appState.isOverlayVisible { return 4 }
        if appState.timerState == .workPaused { return 3 }
        let p = appState.workProgress
        if p < 0.7 { return 0 }
        if p < 0.9 { return 1 }
        return 2
    }
}
