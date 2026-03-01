import AppKit
import Foundation
import SwiftUI

struct GhostCharacterView: View {
    let state: AssistantState
    var size: CGFloat = 30
    var gazeTarget: CGPoint? = nil
    var gazeActivityToken: Int = 0
    var isRetreating: Bool = false
    var isVoiceMode: Bool = false
    var micLevel: Float = 0
    var theme: GhostTheme = OGGhostTheme.theme

    private var bodyAppearance: GhostBodyAppearance { theme.bodyAppearance }
    private var anim: GhostAnimationConfig { theme.animation }

    @State private var pulse = false
    @State private var flapPhase: CGFloat = 0
    @State private var loadingPhase: CGFloat = 0
    @State private var wavePhase: CGFloat = 0
    @State private var pupilOffsets: [CGSize] = []
    @State private var ghostFrameInScreen: CGRect = .zero
    @State private var lastMousePos: CGPoint = .zero
    @State private var followingTextCursor = false
    @State private var lastActivityTime: Date = Date()
    @State private var isIdle = false
    @State private var retreatOffset: CGFloat = 0
    @State private var retreatOpacity: Double = 1.0
    @State private var lastFrameDate: Date? = nil

    var body: some View {
        TimelineView(.animation) { timeline in
            innerBody(frameDate: timeline.date)
        }
    }

    // MARK: - Main Layout

    @ViewBuilder
    private func innerBody(frameDate: Date) -> some View {
        let ghostShape = ThemeBodyShape(provider: theme.bodyShape, phase: flapPhase)
        let bodyH = size * bodyAppearance.heightMultiplier

        ZStack {
            // Body fill
            ghostShape
                .fill(
                    LinearGradient(
                        colors: bodyAppearance.fillColors,
                        startPoint: bodyAppearance.fillStart,
                        endPoint: bodyAppearance.fillEnd
                    )
                )
                .frame(width: size, height: bodyH)
                // Darkening overlay
                .overlay {
                    ghostShape
                        .fill(
                            LinearGradient(
                                colors: bodyAppearance.darkenColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size, height: bodyH)
                }
                // Radial highlight
                .overlay {
                    ghostShape
                        .fill(
                            RadialGradient(
                                colors: bodyAppearance.highlightColors,
                                center: bodyAppearance.highlightCenter,
                                startRadius: size * bodyAppearance.highlightStartRadius,
                                endRadius: size * bodyAppearance.highlightEndRadius
                            )
                        )
                        .frame(width: size, height: bodyH)
                        .offset(
                            x: size * bodyAppearance.highlightOffset.x,
                            y: size * bodyAppearance.highlightOffset.y
                        )
                }
                // Fabric texture (optional)
                .overlay {
                    if bodyAppearance.showFabricTexture {
                        FabricTextureView(size: size)
                            .mask(
                                ghostShape.frame(width: size, height: bodyH)
                            )
                            .opacity(bodyAppearance.fabricTextureOpacity)
                    }
                }

            // Outline
            ghostShape
                .stroke(bodyAppearance.outlineColor, lineWidth: max(1, size * bodyAppearance.outlineWidthRatio))
                .frame(width: size, height: bodyH)

            // Below-eyes accessories (clipped to ghost body shape)
            accessoriesLayer(for: .belowEyes, bodyH: bodyH)
                .clipShape(ghostShape)
                .frame(width: size, height: bodyH)

            // Eyes
            eyesLayer

            // Mouth (optional)
            if let mouth = theme.mouth {
                if !(mouth.hiddenInVoiceMode && isVoiceMode) {
                    RoundedRectangle(cornerRadius: size * mouth.cornerRadiusRatio)
                        .fill(mouth.color.opacity(mouth.opacity))
                        .frame(width: size * mouth.widthRatio, height: size * mouth.heightRatio)
                        .offset(x: size * mouth.offsetX, y: size * mouth.offsetY)
                }
            }

            // Above-eyes accessories
            accessoriesLayer(for: .aboveEyes, bodyH: bodyH)
        }
        .frame(width: size, height: bodyH)
        .contentShape(Rectangle())
        .background(
            GhostScreenFrameReader { frame in
                ghostFrameInScreen = frame
            }
        )
        .scaleEffect(pulses ? (pulse ? anim.pulseScaleHigh : anim.pulseScaleLow) : 1.0)
        .scaleEffect(anim.baseScale)
        .opacity(pulses ? (pulse ? anim.pulseOpacityHigh : anim.pulseOpacityLow) : 1.0)
        .animation(
            pulses
                ? .easeInOut(duration: anim.pulseDuration).repeatForever(autoreverses: true)
                : .default,
            value: pulse
        )
        .animation(.easeOut(duration: 0.09), value: pupilOffsets)
        .offset(y: retreatOffset)
        .opacity(retreatOpacity)
        .onChange(of: isRetreating) { _, retreating in
            if retreating {
                withAnimation(.easeOut(duration: anim.retreatPupilSnapDuration)) {
                    for i in pupilOffsets.indices {
                        pupilOffsets[i] = CGSize(width: 0, height: -(size * anim.maxPupilRadiusRatio))
                    }
                }
                withAnimation(.easeIn(duration: anim.retreatDuration).delay(anim.retreatDelay)) {
                    retreatOffset = -(size * anim.retreatDistanceMultiplier)
                    retreatOpacity = 0.0
                }
            } else {
                retreatOffset = 0
                retreatOpacity = 1.0
            }
        }
        .onChange(of: frameDate) { _, newDate in
            let dt: CGFloat
            if let last = lastFrameDate {
                dt = CGFloat(newDate.timeIntervalSince(last))
            } else {
                dt = 1.0 / 60.0
            }
            lastFrameDate = newDate
            updateGaze()
            flapPhase += anim.flapCyclesPerSecond * dt
            if isVoiceMode {
                wavePhase += anim.waveSpeedPerSecond * dt
                if wavePhase > 10_000 { wavePhase = wavePhase.truncatingRemainder(dividingBy: 1) }
            }
            if isWorking {
                loadingPhase += anim.loadingSpeedPerSecond * dt
                if loadingPhase > 10_000 { loadingPhase = loadingPhase.truncatingRemainder(dividingBy: 1) }
            }
            if flapPhase > 10_000 { flapPhase = flapPhase.truncatingRemainder(dividingBy: 1) }
        }
        .onChange(of: pulses) { _, nowPulsing in
            pulse = nowPulsing
        }
        .onChange(of: state) { _, newState in
            if newState == .working {
                withAnimation(.easeInOut(duration: 0.5)) {
                    for i in pupilOffsets.indices { pupilOffsets[i] = .zero }
                }
            }
        }
        .onChange(of: gazeTarget) { _, _ in
            if gazeTarget != nil { followingTextCursor = true }
        }
        .onChange(of: gazeActivityToken) { _, _ in
            followingTextCursor = true
            lastActivityTime = Date()
            isIdle = false
        }
        .onAppear {
            ensurePupilOffsets()
            flapPhase = 0; loadingPhase = 0; wavePhase = 0
            pulse = pulses
        }
    }

    // MARK: - Accessories Layer

    @ViewBuilder
    private func accessoriesLayer(for layer: AccessoryLayer, bodyH: CGFloat) -> some View {
        // Shape-based accessories
        let items = theme.accessories.filter { $0.layer == layer }
        ForEach(0..<items.count, id: \.self) { i in
            let acc = items[i]
            let shape = AccessoryShape(provider: acc.shapeProvider)
            shape
                .fill(
                    LinearGradient(
                        colors: acc.fillColors,
                        startPoint: acc.fillStart,
                        endPoint: acc.fillEnd
                    )
                )
                .overlay {
                    if let strokeColor = acc.strokeColor, acc.strokeWidthRatio > 0 {
                        shape
                            .stroke(strokeColor, lineWidth: max(0.5, size * acc.strokeWidthRatio))
                    }
                }
                .frame(width: size, height: bodyH)
                .opacity(acc.opacity)
        }
    }

    // MARK: - Eyes Layer

    @ViewBuilder
    private var eyesLayer: some View {
        let offsets = pupilOffsets.isEmpty
            ? Array(repeating: CGSize.zero, count: theme.eyes.count)
            : pupilOffsets

        ZStack {
            ForEach(Array(theme.eyes.enumerated()), id: \.offset) { idx, eyeCfg in
                let snapped = pixelSnapped(idx < offsets.count ? offsets[idx] : .zero)
                let scleraW = pixelSnapped(size * eyeCfg.scleraWidthRatio)
                let scleraH = pixelSnapped(size * eyeCfg.scleraHeightRatio)
                let strokeW = pixelSnapped(max(0.8, size * eyeCfg.scleraStrokeWidthRatio))
                let pupilD  = pixelSnapped(size * eyeCfg.pupilDiameterRatio)
                let hlDiam  = pixelSnapped(size * eyeCfg.highlightDiameterRatio)
                let hlInset = pixelSnapped(size * eyeCfg.highlightInsetRatio)

                ZStack {
                    // Stalk (drawn behind eye if present)
                    if let stalkLen = eyeCfg.stalkLengthRatio {
                        let stalkW = size * eyeCfg.stalkWidthRatio
                        let stalkH = size * stalkLen
                        Capsule()
                            .fill(eyeCfg.stalkColor ?? bodyAppearance.fillColors.last ?? .gray)
                            .frame(width: stalkW, height: stalkH)
                            .offset(y: stalkH / 2 - scleraH * 0.15)
                    }

                    // Sclera
                    Ellipse()
                        .fill(eyeCfg.scleraColor)
                        .frame(width: scleraW, height: scleraH)
                        .overlay {
                            Ellipse().stroke(
                                eyeCfg.scleraStrokeColor.opacity(eyeCfg.scleraStrokeOpacity),
                                lineWidth: strokeW
                            )
                        }

                    if isVoiceMode {
                        Ellipse()
                            .fill(eyeCfg.pupilColor)
                            .frame(width: scleraW, height: scleraH)
                        EyeWaveformView(
                            phase: wavePhase,
                            eyeWidth: scleraW,
                            eyeHeight: scleraH,
                            phaseShift: eyeCfg.waveformPhaseShift,
                            micLevel: micLevel
                        )
                    } else {
                        // Pupil
                        Circle()
                            .fill(eyeCfg.pupilColor)
                            .frame(width: pupilD, height: pupilD)
                            .offset(snapped)

                        if isWorking {
                            EyeLoadingDots(
                                pupilOffset: snapped,
                                pupilDiameter: pupilD,
                                dotDiameter: hlDiam,
                                dotColor: eyeCfg.highlightColor,
                                phase: loadingPhase,
                                phaseOffset: eyeCfg.loadingPhaseOffset
                            )
                        } else {
                            // Highlight dot
                            Circle()
                                .fill(eyeCfg.highlightColor.opacity(eyeCfg.highlightOpacity))
                                .frame(width: hlDiam, height: hlDiam)
                                .offset(
                                    x: snapped.width - hlInset,
                                    y: snapped.height - hlInset
                                )
                        }
                    }
                }
                .offset(
                    x: pixelSnapped(size * eyeCfg.relativeX),
                    y: pixelSnapped(size * eyeCfg.relativeY)
                )
            }
        }
    }

    // MARK: - Computed Helpers

    private var pulses: Bool { state == .listening && !isVoiceMode }
    private var isWorking: Bool { state == .working }

    // MARK: - Gaze Tracking

    private func ensurePupilOffsets() {
        if pupilOffsets.count != theme.eyes.count {
            pupilOffsets = Array(repeating: .zero, count: theme.eyes.count)
        }
    }

    private func updateGaze() {
        guard !isRetreating, !isWorking, !ghostFrameInScreen.isEmpty else {
            if !ghostFrameInScreen.isEmpty { return }
            ensurePupilOffsets()
            for i in pupilOffsets.indices { pupilOffsets[i] = .zero }
            return
        }

        ensurePupilOffsets()

        let mouse = NSEvent.mouseLocation
        let mouseMoved = lastMousePos != .zero
            && hypot(mouse.x - lastMousePos.x, mouse.y - lastMousePos.y) > 1.5
        if mouseMoved {
            followingTextCursor = false
            lastActivityTime = Date()
            if isIdle { isIdle = false }
        }
        lastMousePos = mouse

        let secondsSinceActivity = Date().timeIntervalSince(lastActivityTime)
        if secondsSinceActivity >= anim.idleTimeoutSeconds {
            if !isIdle {
                isIdle = true
                withAnimation(.easeInOut(duration: 0.5)) {
                    for i in pupilOffsets.indices { pupilOffsets[i] = .zero }
                }
            }
            return
        }

        let target: CGPoint
        if followingTextCursor, let gt = gazeTarget {
            target = gt
        } else {
            target = mouse
        }

        for (idx, eyeCfg) in theme.eyes.enumerated() {
            let center = eyeCenterInScreen(for: eyeCfg)
            pupilOffsets[idx] = pupilOffset(toward: target, from: center)
        }
    }

    private func eyeCenterInScreen(for eyeCfg: GhostEyeConfig) -> CGPoint {
        let bodyH = size * bodyAppearance.heightMultiplier
        let eyeCenterXInView = size / 2 + size * eyeCfg.relativeX
        let eyeCenterYInView = bodyH / 2 + size * eyeCfg.relativeY
        return CGPoint(
            x: ghostFrameInScreen.minX + eyeCenterXInView,
            y: ghostFrameInScreen.maxY - eyeCenterYInView
        )
    }

    private func pupilOffset(toward target: CGPoint, from eyeCenter: CGPoint) -> CGSize {
        let dx = target.x - eyeCenter.x
        let dy = target.y - eyeCenter.y
        let rawX = dx * anim.gazeSensitivity
        let rawY = -dy * anim.gazeSensitivity
        let maxRadius = size * anim.maxPupilRadiusRatio
        let distance = sqrt(rawX * rawX + rawY * rawY)
        let scale = distance > maxRadius ? maxRadius / distance : 1
        return CGSize(width: rawX * scale, height: rawY * scale)
    }

    // MARK: - Pixel Snapping

    private var displayScale: CGFloat {
        guard !ghostFrameInScreen.isEmpty else {
            return max(NSScreen.main?.backingScaleFactor ?? 2.0, 1.0)
        }
        let center = CGPoint(x: ghostFrameInScreen.midX, y: ghostFrameInScreen.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return max(screen.backingScaleFactor, 1.0)
        }
        return max(NSScreen.main?.backingScaleFactor ?? 2.0, 1.0)
    }

    private func pixelSnapped(_ value: CGFloat) -> CGFloat {
        (value * displayScale).rounded() / displayScale
    }

    private func pixelSnapped(_ offset: CGSize) -> CGSize {
        CGSize(width: pixelSnapped(offset.width), height: pixelSnapped(offset.height))
    }
}

// MARK: - Eye Loading Dots

private struct EyeLoadingDots: View {
    let pupilOffset: CGSize
    let pupilDiameter: CGFloat
    let dotDiameter: CGFloat
    var dotColor: Color = .white
    let phase: CGFloat
    let phaseOffset: CGFloat

    private let dotCount = 6

    var body: some View {
        let orbitRadius = pupilDiameter * 0.29

        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                let progress = (phase + phaseOffset + CGFloat(index) / CGFloat(dotCount))
                    .truncatingRemainder(dividingBy: 1)
                let angle = progress * .pi * 2
                let opacity = 0.18 + (Double(index) / Double(dotCount - 1)) * 0.82

                Circle()
                    .fill(dotColor.opacity(opacity))
                    .frame(width: dotDiameter * 0.72, height: dotDiameter * 0.72)
                    .offset(
                        x: pupilOffset.width + cos(angle) * orbitRadius,
                        y: pupilOffset.height + sin(angle) * orbitRadius
                    )
            }
        }
    }
}

// MARK: - Eye Waveform

private struct EyeWaveformView: View {
    let phase: CGFloat
    let eyeWidth: CGFloat
    let eyeHeight: CGFloat
    let phaseShift: CGFloat
    let micLevel: Float

    private let barCount = 4
    private let barFreqs:   [CGFloat] = [1.0, 2.17, 1.63, 2.84]
    private let barOffsets: [CGFloat] = [0.0,  0.43, 0.21, 0.68]
    private let barHarm2:   [CGFloat] = [0.38, 0.26, 0.48, 0.22]

    var body: some View {
        HStack(alignment: .center, spacing: eyeWidth * 0.07) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(0.90))
                    .frame(width: eyeWidth * 0.10, height: barHeight(for: i))
            }
        }
        .frame(width: eyeWidth, height: eyeHeight)
        .clipShape(Ellipse())
    }

    private func barHeight(for index: Int) -> CGFloat {
        let f  = barFreqs[index]
        let phi  = (barOffsets[index] + phaseShift) * .pi * 2
        let h2 = Double(barHarm2[index])
        let theta  = Double(phase * f * .pi * 2)

        let wave = sin(theta + Double(phi)) + h2 * sin(theta * 2.13 + Double(phi) * 0.7)
        let normalized = CGFloat(wave / (1.0 + h2))

        let amplitude = CGFloat(max(micLevel, 0.08))
        let minH = eyeHeight * 0.18
        let maxH = eyeHeight * (0.18 + 0.64 * amplitude)
        return minH + (maxH - minH) * (normalized * 0.5 + 0.5)
    }
}

// MARK: - Fabric Texture

private struct FabricTextureView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .white.opacity(0.20),
                    .clear,
                    .white.opacity(0.10),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .scaleEffect(x: 1.8, y: 2.0)

            LinearGradient(
                colors: [
                    .black.opacity(0.06),
                    .clear,
                    .black.opacity(0.04),
                    .clear
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .scaleEffect(x: 2.2, y: 1.6)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.24),
                            .clear,
                            .white.opacity(0.14),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .rotationEffect(.degrees(-18))
                .scaleEffect(x: 0.65, y: 1.4)
                .offset(x: -size * 0.07, y: -size * 0.03)
        }
    }
}

// MARK: - Screen Frame Reader

private struct GhostScreenFrameReader: NSViewRepresentable {
    var onChange: (CGRect) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onFrameChange = onChange
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onFrameChange = onChange
        nsView.reportFrameIfPossible()
    }

    final class TrackingView: NSView {
        var onFrameChange: ((CGRect) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportFrameIfPossible()
        }

        override func layout() {
            super.layout()
            reportFrameIfPossible()
        }

        func reportFrameIfPossible() {
            guard let window else { return }
            let frameInWindow = convert(bounds, to: nil)
            let frameInScreen = window.convertToScreen(frameInWindow)
            DispatchQueue.main.async { [weak self] in
                guard self != nil else { return }
                self?.onFrameChange?(frameInScreen)
            }
        }
    }
}
