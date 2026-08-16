import SwiftUI
import CoreMotion
import UIKit
import SceneKit

private enum DivinationStage: Equatable {
    case ready
    case shaking
    case drawing
    case revealed
}

@MainActor
private final class ShakeDetector: ObservableObject {
    @Published private(set) var shakeCount = 0
    private let manager = CMMotionManager()
    private var lastShake = Date.distantPast

    func start() {
        guard manager.isAccelerometerAvailable else { return }
        manager.accelerometerUpdateInterval = 0.08
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let acceleration = data?.acceleration else { return }
            let magnitude = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z)
            guard magnitude > 2.05, Date().timeIntervalSince(self.lastShake) > 0.75 else { return }
            self.lastShake = Date()
            self.shakeCount += 1
        }
    }

    func stop() { manager.stopAccelerometerUpdates() }
}

struct DivinationView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var detector = ShakeDetector()
    @State private var stage: DivinationStage = .ready
    @State private var sign: FortuneSign?
    @State private var interpretation = ""
    @State private var isInterpreting = false
    @State private var showResult = false

    var body: some View {
        ZStack {
            OrbitTheme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    cupArea
                    if let sign, stage == .revealed { result(sign) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("今日求签")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } } }
        .onAppear {
            detector.start()
        }
        .onDisappear { detector.stop() }
        .onChange(of: detector.shakeCount) { _, _ in
            guard stage == .ready else { return }
            beginDraw()
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("黃大仙靈籤").font(.custom("STKaitiTC-Regular", size: 31)).foregroundStyle(OrbitTheme.primary)
            Text(stage == .revealed ? "签已落定，慢慢读完它给你的提醒。" : "静下心，握住手机轻轻摇晃，让一支签落下来。")
                .font(.subheadline).foregroundStyle(OrbitTheme.secondary).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Label("百签签库", systemImage: "scroll.fill")
                Text("·")
                Text("传统文化自省")
            }
            .font(.caption).foregroundStyle(OrbitTheme.gold)
        }
    }

    private var cupArea: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(OrbitTheme.gold.opacity(0.13), lineWidth: 1).frame(width: 286, height: 286)
                Circle().stroke(OrbitTheme.gold.opacity(0.08), lineWidth: 1).frame(width: 226, height: 226)
                ShakeCup3D(stage: stage, reduceMotion: reduceMotion)
                    .frame(width: 180, height: 210)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(stage == .shaking ? "签筒正在摇动" : stage == .revealed ? "签筒已落签" : "黄大仙签筒")

            if stage == .ready {
                Button(action: beginDraw) {
                    Label("求签问卜", systemImage: "iphone.gen3.motion")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity).frame(height: 54)
                }
                .foregroundStyle(OrbitTheme.background).background(OrbitTheme.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .buttonStyle(OrbitPressStyle())
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .zIndex(2)
                .accessibilityHint("也可以直接摇晃手机开始")
            } else if stage == .shaking {
                Label("正在感应摇晃 · 请再摇几下", systemImage: "waveform.path")
                    .font(.subheadline.weight(.medium)).foregroundStyle(OrbitTheme.gold)
                    .transition(.opacity)
            } else if stage == .drawing {
                Label("签筒已停 · 正在抽签", systemImage: "sparkles")
                    .font(.subheadline.weight(.medium)).foregroundStyle(OrbitTheme.gold)
            } else {
                Button { reset() } label: {
                    Label("再求一签", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).frame(height: 48)
                }
                .foregroundStyle(OrbitTheme.gold).background(OrbitTheme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .buttonStyle(OrbitPressStyle())
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: stage)
    }

    private func result(_ sign: FortuneSign) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            FortunePaper(sign: sign)
            VStack(alignment: .leading, spacing: 10) {
                Label("签文解读", systemImage: "text.book.closed.fill").font(.headline.weight(.semibold)).foregroundStyle(OrbitTheme.primary)
                if isInterpreting { ReadingLoader().frame(width: 30, height: 30) }
                else { Text(interpretation.isEmpty ? sign.interpretation : interpretation).font(.body).foregroundStyle(OrbitTheme.secondary).lineSpacing(5).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(18).background(OrbitTheme.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            Label(sign.advice, systemImage: "arrow.turn.down.right").font(.subheadline.weight(.medium)).foregroundStyle(OrbitTheme.primary).lineSpacing(4)
            Text("签文用于传统文化与自我反思，不构成事实预测或专业建议。")
                .font(.caption).foregroundStyle(OrbitTheme.secondary)
        }
        .opacity(showResult ? 1 : 0).offset(y: showResult ? 0 : 20)
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85), value: showResult)
    }

    private func beginDraw() {
        guard stage == .ready else { return }
        stage = .shaking
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.45 : 2.35))
            guard stage == .shaking else { return }
            stage = .drawing
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.18 : 0.68))
            reveal()
        }
    }

    private func reveal() {
        sign = FortuneSign.all.randomElement() ?? FortuneSign.all[0]
        stage = .revealed
        showResult = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86)) { showResult = true }
        guard let sign else { return }
        isInterpreting = true
        Task { @MainActor in
            let text = await state.interpretSign(sign)
            guard self.sign == sign else { return }
            interpretation = text
            isInterpreting = false
        }
    }

    private func reset() {
        sign = nil; interpretation = ""; showResult = false; isInterpreting = false; stage = .ready
    }
}

private struct FortunePaper: View {
    let sign: FortuneSign
    private let paper = Color(red: 0.89, green: 0.84, blue: 0.72)
    private let ink = Color(red: 0.15, green: 0.10, blue: 0.06)
    private let mutedInk = Color(red: 0.39, green: 0.32, blue: 0.24)
    private let vermilion = Color(red: 0.52, green: 0.10, blue: 0.06)
    private var displaySign: FortuneSign { sign.traditionalized }

    private var poemLines: [String] {
        var lines: [String] = []
        var fragment = ""
        for character in displaySign.poem {
            if character == "\n" {
                if !fragment.isEmpty { lines.append(fragment); fragment = "" }
                continue
            }
            if "，。；！？、".contains(character) {
                if !fragment.isEmpty { lines.append(fragment) }
                fragment = ""
                continue
            }
            fragment.append(character)
        }
        if !fragment.isEmpty { lines.append(fragment) }
        return lines
    }

    private var themeTitle: String {
        displaySign.title.components(separatedBy: " · ").first ?? displaySign.title
    }

    private var signNumberLabel: String {
        "第\(displaySign.number)籤"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("黃大仙靈籤")
                        .font(.custom("STKaitiTC-Regular", size: 20))
                        .foregroundStyle(ink)
                    Text("靜心問事 · 一籤自省")
                        .font(.custom("STKaitiTC-Regular", size: 12))
                        .foregroundStyle(mutedInk)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(signNumberLabel)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                    Text(displaySign.rank.traditionalized)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(vermilion)
                }
                .foregroundStyle(ink)
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(themeTitle)
                        .font(.custom("STKaitiTC-Regular", size: 34))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("一籤一意，讀當下的心")
                        .font(.custom("STKaitiTC-Regular", size: 14))
                        .foregroundStyle(mutedInk)
                }
                Spacer()
                PaperSeal()
            }
            .padding(.top, 30)

            VStack(spacing: 15) {
                Rectangle().fill(vermilion.opacity(0.55)).frame(width: 34, height: 2)
                ForEach(Array(poemLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.custom("STKaitiTC-Regular", size: 27))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Rectangle().fill(vermilion.opacity(0.55)).frame(width: 34, height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)

            HStack {
                Text("心誠 · 靜觀 · 自省")
                Spacer()
                Text("傳統文化 · 自我觀照")
                    .foregroundStyle(vermilion)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(mutedInk)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .background(paper, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
        .shadow(color: .black.opacity(0.30), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第\(displaySign.number)籤，\(displaySign.rank)，\(displaySign.title)，籤文：\(displaySign.poem)")
    }
}

private struct PaperPoemFrame: View {
    let lines: [String]
    let color: Color

    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 25, weight: .regular, design: .serif))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, minHeight: 390, alignment: .center)
        .overlay(alignment: .center) {
            ZStack {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(color, lineWidth: 1.4)
                    .padding(7)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(color.opacity(0.72), lineWidth: 0.8)
                    .padding(12)
            }
        }
    }
}

private struct PaperSeal: View {
    private let vermilion = Color(red: 0.52, green: 0.10, blue: 0.06)

    var body: some View {
        ZStack {
            Circle().stroke(vermilion, lineWidth: 2)
            Circle().stroke(vermilion.opacity(0.72), lineWidth: 1).padding(5)
            VStack(spacing: 0) {
                Text("黃大").font(.custom("STKaitiTC-Regular", size: 11))
                Text("仙籤").font(.custom("STKaitiTC-Regular", size: 11))
            }
            .foregroundStyle(vermilion)
        }
        .frame(width: 64, height: 64)
    }
}

private struct ShakeCup3D: UIViewRepresentable {
    let stage: DivinationStage
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.scene = context.coordinator.controller.scene
        view.antialiasingMode = .multisampling2X
        context.coordinator.controller.update(stage: stage, reduceMotion: reduceMotion)
        configure(view, for: stage)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.controller.update(stage: stage, reduceMotion: reduceMotion)
        configure(view, for: stage)
    }

    private func configure(_ view: SCNView, for stage: DivinationStage) {
        let isAnimating = stage == .shaking || stage == .drawing
        view.preferredFramesPerSecond = isAnimating ? 60 : 30
        view.rendersContinuously = isAnimating
        view.isPlaying = isAnimating
        if !isAnimating { view.setNeedsDisplay() }
    }

    final class Coordinator {
        let controller = CupSceneController()
    }
}

private final class CupSceneController {
    let scene = SCNScene()
    private let vessel = SCNNode()
    private var sticks: [SCNNode] = []
    private var stickHomes: [(position: SCNVector3, rotation: SCNVector3)] = []
    private var currentStage: DivinationStage?
    private let gold = UIColor(red: 0.95, green: 0.68, blue: 0.25, alpha: 1)
    private let bambooDark = UIColor(red: 0.27, green: 0.15, blue: 0.07, alpha: 1)
    private let bambooMid = UIColor(red: 0.48, green: 0.28, blue: 0.12, alpha: 1)
    private let bambooLight = UIColor(red: 0.70, green: 0.47, blue: 0.22, alpha: 1)

    init() {
        scene.background.contents = UIColor.clear
        scene.physicsWorld.gravity = SCNVector3(0, -2.8, 0)
        scene.rootNode.addChildNode(vessel)
        setupCameraAndLights()
        setupCup()
        setupSticks()
        setupGround()
    }

    func update(stage: DivinationStage, reduceMotion: Bool) {
        guard currentStage != stage else { return }
        currentStage = stage
        switch stage {
        case .ready:
            reset()
        case .shaking:
            animateShake(reduceMotion: reduceMotion)
        case .drawing:
            animateDraw(reduceMotion: reduceMotion)
        case .revealed:
            vessel.removeAllActions()
        }
    }

    private func setupCameraAndLights() {
        let camera = SCNCamera()
        camera.fieldOfView = 39
        camera.zNear = 0.1
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.12, 5.5)
        cameraNode.eulerAngles.x = -0.12
        scene.rootNode.addChildNode(cameraNode)

        let key = SCNLight()
        key.type = .omni
        key.color = UIColor(red: 1, green: 0.82, blue: 0.55, alpha: 1)
        key.intensity = 900
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(-2.2, 3.8, 3.2)
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .ambient
        fill.color = UIColor(red: 0.80, green: 0.63, blue: 0.40, alpha: 1)
        fill.intensity = 340
        let fillNode = SCNNode()
        fillNode.light = fill
        scene.rootNode.addChildNode(fillNode)
    }

    private func setupCup() {
        vessel.position = SCNVector3(0, -0.38, 0)

        // A temple signing tube is a continuous bamboo vessel, not an open basket.
        // The dark opening is deliberately set just above the body so its hollow mouth remains visible.
        let body = SCNCone(topRadius: 0.63, bottomRadius: 0.57, height: 1.54)
        body.radialSegmentCount = 72
        body.firstMaterial = material(bambooMid, roughness: 0.84, metallic: 0)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position.y = 0.27
        vessel.addChildNode(bodyNode)

        let vermilion = UIColor(red: 0.68, green: 0.055, blue: 0.035, alpha: 1)
        let jade = UIColor(red: 0.02, green: 0.34, blue: 0.28, alpha: 1)
        let upperBand = SCNCylinder(radius: 0.645, height: 0.22)
        upperBand.radialSegmentCount = 64
        upperBand.firstMaterial = material(vermilion, roughness: 0.48, metallic: 0)
        let upperBandNode = SCNNode(geometry: upperBand)
        upperBandNode.position.y = 0.86
        vessel.addChildNode(upperBandNode)

        // The visible cone is solid, but the physics volume must only model the inner wall.
        // Otherwise SceneKit expels every sign through the exterior of the cup on startup.
        let collisionWall = SCNTube(innerRadius: 0.53, outerRadius: 0.58, height: 1.42)
        collisionWall.radialSegmentCount = 64
        let collisionNode = SCNNode(geometry: collisionWall)
        collisionNode.position.y = 0.25
        collisionNode.opacity = 0.001
        collisionNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: collisionWall, options: nil))
        vessel.addChildNode(collisionNode)

        let opening = SCNCylinder(radius: 0.56, height: 0.016)
        opening.radialSegmentCount = 72
        opening.firstMaterial = material(UIColor(red: 0.045, green: 0.025, blue: 0.012, alpha: 1), roughness: 1, metallic: 0)
        let openingNode = SCNNode(geometry: opening)
        openingNode.position.y = 1.045
        vessel.addChildNode(openingNode)

        let base = SCNCylinder(radius: 0.59, height: 0.13)
        base.radialSegmentCount = 64
        base.firstMaterial = material(bambooDark, roughness: 0.82, metallic: 0)
        let baseNode = SCNNode(geometry: base)
        baseNode.position.y = -0.47
        baseNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: base, options: nil))
        vessel.addChildNode(baseNode)

        let rim = SCNTorus(ringRadius: 0.615, pipeRadius: 0.030)
        rim.firstMaterial = material(bambooDark, roughness: 0.72, metallic: 0)
        let rimNode = SCNNode(geometry: rim)
        rimNode.position.y = 1.055
        vessel.addChildNode(rimNode)

        let bambooJoint = SCNTorus(ringRadius: 0.58, pipeRadius: 0.025)
        bambooJoint.firstMaterial = material(bambooDark, roughness: 0.82, metallic: 0)
        let bambooJointNode = SCNNode(geometry: bambooJoint)
        bambooJointNode.position.y = -0.22
        vessel.addChildNode(bambooJointNode)

        let lowerRim = SCNTorus(ringRadius: 0.54, pipeRadius: 0.030)
        lowerRim.firstMaterial = material(bambooDark, roughness: 0.72, metallic: 0)
        let lowerRimNode = SCNNode(geometry: lowerRim)
        lowerRimNode.position.y = -0.38
        vessel.addChildNode(lowerRimNode)

        let greenBand = SCNCylinder(radius: 0.595, height: 0.16)
        greenBand.radialSegmentCount = 64
        greenBand.firstMaterial = material(jade, roughness: 0.54, metallic: 0)
        let greenBandNode = SCNNode(geometry: greenBand)
        greenBandNode.position.y = -0.28
        vessel.addChildNode(greenBandNode)

        let lowerRedBand = SCNCylinder(radius: 0.60, height: 0.15)
        lowerRedBand.radialSegmentCount = 64
        lowerRedBand.firstMaterial = material(vermilion, roughness: 0.48, metallic: 0)
        let lowerRedBandNode = SCNNode(geometry: lowerRedBand)
        lowerRedBandNode.position.y = -0.45
        vessel.addChildNode(lowerRedBandNode)

    }

    private func setupSticks() {
        let positions: [SCNVector3] = [
            SCNVector3(-0.18, 0.56, -0.10), SCNVector3(-0.10, 0.66, 0.07), SCNVector3(0.00, 0.57, -0.12),
            SCNVector3(0.11, 0.70, 0.04), SCNVector3(0.01, 0.63, 0.13), SCNVector3(0.18, 0.56, -0.07),
            SCNVector3(-0.19, 0.63, 0.08), SCNVector3(-0.05, 0.75, 0.00), SCNVector3(0.09, 0.60, -0.15),
            SCNVector3(0.17, 0.69, 0.09), SCNVector3(-0.13, 0.57, 0.15), SCNVector3(-0.02, 0.71, 0.17),
            SCNVector3(0.04, 0.64, -0.20), SCNVector3(-0.16, 0.68, -0.03), SCNVector3(0.15, 0.61, -0.16),
            SCNVector3(-0.08, 0.59, -0.19), SCNVector3(0.20, 0.72, 0.01), SCNVector3(-0.20, 0.78, -0.02),
            SCNVector3(0.15, 0.76, -0.09), SCNVector3(-0.04, 0.82, 0.11), SCNVector3(0.06, 0.79, -0.10),
            SCNVector3(-0.12, 0.73, -0.16), SCNVector3(0.19, 0.67, 0.14), SCNVector3(-0.18, 0.69, 0.16)
        ]
        for index in positions.indices {
            let node = SCNNode()
            let stick = SCNBox(width: 0.080, height: 1.76 + CGFloat(index % 3) * 0.05, length: 0.024, chamferRadius: 0.008)
            stick.firstMaterial = material(index.isMultiple(of: 3) ? bambooLight : UIColor(red: 0.60, green: 0.37, blue: 0.15, alpha: 1), roughness: 0.82, metallic: 0)
            let shaft = SCNNode(geometry: stick)
            node.addChildNode(shaft)

            node.position = positions[index]
            node.position.y += 0.20
            node.eulerAngles = SCNVector3(Float((index % 4) - 2) * 0.035, Float(index % 5 - 2) * 0.055, Float((index % 3) - 1) * 0.025)
            node.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(node: node, options: nil))
            node.physicsBody?.isAffectedByGravity = false
            node.physicsBody?.damping = 1.65
            node.physicsBody?.angularDamping = 2.6
            node.physicsBody?.restitution = 0.16
            node.physicsBody?.friction = 0.84
            vessel.addChildNode(node)
            sticks.append(node)
            stickHomes.append((node.position, node.eulerAngles))
        }
    }

    private func setupGround() {
        let ground = SCNCylinder(radius: 1.28, height: 0.08)
        ground.radialSegmentCount = 64
        ground.firstMaterial = material(UIColor(red: 0.06, green: 0.045, blue: 0.025, alpha: 1), roughness: 0.72, metallic: 0)
        let groundNode = SCNNode(geometry: ground)
        groundNode.position.y = -0.85
        scene.rootNode.addChildNode(groundNode)
        let ring = SCNTorus(ringRadius: 1.02, pipeRadius: 0.025)
        ring.firstMaterial = material(gold.withAlphaComponent(0.42), roughness: 0.35, metallic: 0.25)
        let ringNode = SCNNode(geometry: ring)
        ringNode.position.y = -0.8
        scene.rootNode.addChildNode(ringNode)
    }

    private func animateShake(reduceMotion: Bool) {
        vessel.removeAllActions()
        for stick in sticks {
            stick.removeAllActions()
            // Kinematic bodies keep the animation deterministic on Simulator;
            // each slip gets its own phase and orbit so the bundle visibly breaks apart.
            stick.physicsBody?.type = .kinematic
            stick.physicsBody?.isAffectedByGravity = false
        }
        let duration = reduceMotion ? 0.24 : 0.13
        let left = SCNAction.rotateBy(x: 0.08, y: 0.02, z: -0.13, duration: duration)
        let right = SCNAction.rotateBy(x: -0.08, y: -0.02, z: 0.26, duration: duration * 1.15)
        let settle = SCNAction.rotateBy(x: 0.02, y: 0, z: -0.13, duration: duration)
        vessel.runAction(.repeatForever(.sequence([left, right, settle])))
        let collisionPulse = SCNAction.run { [weak self] _ in self?.applyShakeImpulse() }
        let collisionSequence = SCNAction.sequence([collisionPulse, .wait(duration: reduceMotion ? 0.25 : 0.11)])
        vessel.runAction(.repeat(collisionSequence, count: reduceMotion ? 2 : 16), forKey: "collisionPulse")

        for (index, stick) in sticks.enumerated() {
            let phase = Double(index % 5) * 0.035
            let x = CGFloat((index % 4) - 1) * 0.055
            let z = CGFloat((index % 3) - 1) * 0.045
            let sway = SCNAction.group([
                SCNAction.moveBy(x: x, y: CGFloat(index % 2) * 0.035, z: z, duration: duration),
                SCNAction.rotateBy(x: CGFloat(index % 3 - 1) * 0.18, y: CGFloat(index % 4 - 2) * 0.14, z: CGFloat(index % 5 - 2) * 0.16, duration: duration)
            ])
            let rebound = SCNAction.group([
                SCNAction.moveBy(x: -x * 2, y: -CGFloat(index % 2) * 0.07, z: -z * 2, duration: duration * 1.18),
                SCNAction.rotateBy(x: CGFloat(1 - index % 3) * 0.28, y: CGFloat(2 - index % 4) * 0.22, z: CGFloat(2 - index % 5) * 0.24, duration: duration * 1.18)
            ])
            let settle = SCNAction.group([
                SCNAction.moveBy(x: x, y: 0, z: z, duration: duration * 0.9),
                SCNAction.rotateBy(x: CGFloat(index % 3 - 1) * 0.10, y: CGFloat(index % 4 - 2) * 0.08, z: CGFloat(index % 5 - 2) * 0.09, duration: duration * 0.9)
            ])
            stick.runAction(.sequence([.wait(duration: phase), .repeatForever(.sequence([sway, rebound, settle]))]), forKey: "individual-shake-\(index)")
        }
    }

    private func animateDraw(reduceMotion: Bool) {
        vessel.removeAllActions()
        sticks.forEach {
            $0.removeAllActions()
            $0.physicsBody?.clearAllForces()
            $0.physicsBody?.type = .kinematic
            $0.physicsBody?.isAffectedByGravity = false
        }
        let selected = sticks[4]
        selected.physicsBody?.type = .kinematic
        let liftDuration = reduceMotion ? 0.14 : 0.24
        let travelDuration = reduceMotion ? 0.10 : 0.16
        let fallDuration = reduceMotion ? 0.12 : 0.20
        // Clear the mouth with the whole stick before it ever tilts; this prevents the
        // lower end from clipping through the rim during the draw animation.
        let lift = SCNAction.moveBy(x: 0, y: 1.18, z: 0, duration: liftDuration)
        let travel = SCNAction.group([
            SCNAction.moveBy(x: 0.12, y: 0.06, z: 0.70, duration: travelDuration),
            SCNAction.rotateBy(x: -0.28, y: 0.08, z: 0.16, duration: travelDuration)
        ])
        let fall = SCNAction.moveBy(x: 0.12, y: -0.78, z: 0.58, duration: fallDuration)
        selected.runAction(.sequence([lift, .wait(duration: 0.04), travel, .wait(duration: 0.02), fall]))
        vessel.runAction(.sequence([
            .rotateBy(x: 0, y: 0, z: 0.08, duration: reduceMotion ? 0.12 : 0.28),
            .rotateBy(x: 0, y: 0, z: -0.08, duration: reduceMotion ? 0.12 : 0.28)
        ]))
    }

    private func reset() {
        vessel.removeAllActions()
        vessel.eulerAngles = SCNVector3(0, 0, 0)
        for (index, stick) in sticks.enumerated() {
            stick.removeAllActions()
            stick.physicsBody?.type = .kinematic
            stick.physicsBody?.isAffectedByGravity = false
            stick.physicsBody?.clearAllForces()
            stick.physicsBody?.velocity = SCNVector3(0, 0, 0)
            stick.physicsBody?.angularVelocity = SCNVector4(0, 0, 0, 0)
            stick.position = stickHomes[index].position
            stick.eulerAngles = stickHomes[index].rotation
        }
    }

    private func applyShakeImpulse() {
        for (index, stick) in sticks.enumerated() {
            let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let contact = SCNAction.sequence([
                SCNAction.moveBy(x: direction * 0.035, y: 0.018, z: -direction * 0.026, duration: 0.045),
                SCNAction.moveBy(x: -direction * 0.035, y: -0.018, z: direction * 0.026, duration: 0.055)
            ])
            stick.runAction(contact, forKey: "contact-\(index)")
        }
    }

    private func material(_ color: UIColor, roughness: CGFloat, metallic: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.roughness.contents = roughness
        material.metalness.contents = metallic
        return material
    }
}

private extension FortuneSign {
    var traditionalized: FortuneSign {
        FortuneSign(
            number: number,
            title: title.traditionalized,
            poem: poem.traditionalized,
            interpretation: interpretation.traditionalized,
            advice: advice.traditionalized
        )
    }
}

private extension String {
    var traditionalized: String {
        let mutable = NSMutableString(string: self)
        CFStringTransform(mutable, nil, "Hans-Hant" as CFString, false)
        return (mutable as String).replacingOccurrences(of: "簽", with: "籤")
    }
}
