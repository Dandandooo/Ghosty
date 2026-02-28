import AppKit
import Foundation
import SwiftUI

struct GhostCharacterView: View {
    let state: AssistantState
    var size: CGFloat = 30
    var gazeTarget: CGPoint? = nil
    var gazeActivityToken: Int = 0
    private let bodyHeightMultiplier: CGFloat = 1.28
    private let baseScale: CGFloat = 1.06

    @State private var pulse = false
    @State private var flapPhase: CGFloat = 0
    @State private var loadingPhase: CGFloat = 0
    @State private var leftPupilOffset: CGSize = .zero
    @State private var rightPupilOffset: CGSize = .zero
    @State private var ghostFrameInScreen: CGRect = .zero
    @State private var lastMousePos: CGPoint = .zero
    @State private var followingTextCursor = false
    @State private var lastActivityTime: Date = Date()
    @State private var isIdle = false
    private let flapCyclesPerSecond: CGFloat = 0.22

    private let gazeTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        let ghostShape = GhostBody(phase: flapPhase)
        let eye = eyeMetrics
        let snappedLeftPupilOffset = pixelSnapped(leftPupilOffset)
        let snappedRightPupilOffset = pixelSnapped(rightPupilOffset)

        ZStack {
            ghostShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(white: 0.992),
                            Color(white: 0.965)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size * bodyHeightMultiplier)
                .overlay {
                    ghostShape
                        .fill(
                            LinearGradient(
                                colors: [
                                    .black.opacity(0.0),
                                    .black.opacity(0.05),
                                    .black.opacity(0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size, height: size * bodyHeightMultiplier)
                }
                .overlay {
                    ghostShape
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.56),
                                    .white.opacity(0.0)
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: size * 0.55
                            )
                        )
                        .frame(width: size, height: size * bodyHeightMultiplier)
                        .offset(x: -size * 0.06, y: -size * 0.10)
                }
                .overlay {
                    FabricTextureView(size: size)
                        .mask(
                            ghostShape
                                .frame(width: size, height: size * bodyHeightMultiplier)
                        )
                        .opacity(0.24)
                }

            ghostShape
                .stroke(.black.opacity(0.11), lineWidth: max(1, size * 0.03))
                .frame(width: size, height: size * bodyHeightMultiplier)

            HStack(spacing: eye.spacing) {
                ZStack {
                    Ellipse()
                        .fill(.white)
                        .frame(width: eye.whiteWidth, height: eye.whiteHeight)
                        .overlay {
                            Ellipse().stroke(.black.opacity(0.22), lineWidth: eye.strokeWidth)
                        }

                    Circle()
                        .fill(.black)
                        .frame(width: eye.pupilDiameter, height: eye.pupilDiameter)
                        .offset(snappedLeftPupilOffset)

                    if isWorking {
                        EyeLoadingDots(
                            pupilOffset: snappedLeftPupilOffset,
                            pupilDiameter: eye.pupilDiameter,
                            dotDiameter: eye.highlightDiameter,
                            phase: loadingPhase,
                            phaseOffset: 0
                        )
                    } else {
                        Circle()
                            .fill(.white.opacity(0.95))
                            .frame(width: eye.highlightDiameter, height: eye.highlightDiameter)
                            .offset(
                                x: snappedLeftPupilOffset.width - eye.highlightInset,
                                y: snappedLeftPupilOffset.height - eye.highlightInset
                            )
                    }
                }

                ZStack {
                    Ellipse()
                        .fill(.white)
                        .frame(width: eye.whiteWidth, height: eye.whiteHeight)
                        .overlay {
                            Ellipse().stroke(.black.opacity(0.22), lineWidth: eye.strokeWidth)
                        }

                    Circle()
                        .fill(.black)
                        .frame(width: eye.pupilDiameter, height: eye.pupilDiameter)
                        .offset(snappedRightPupilOffset)

                    if isWorking {
                        EyeLoadingDots(
                            pupilOffset: snappedRightPupilOffset,
                            pupilDiameter: eye.pupilDiameter,
                            dotDiameter: eye.highlightDiameter,
                            phase: loadingPhase,
                            phaseOffset: 0.5
                        )
                    } else {
                        Circle()
                            .fill(.white.opacity(0.95))
                            .frame(width: eye.highlightDiameter, height: eye.highlightDiameter)
                            .offset(
                                x: snappedRightPupilOffset.width - eye.highlightInset,
                                y: snappedRightPupilOffset.height - eye.highlightInset
                            )
                    }
                }
            }
            .offset(y: eye.verticalOffset)

            RoundedRectangle(cornerRadius: size * 0.08)
                .fill(.black.opacity(0.82))
                .frame(width: size * 0.14, height: size * 0.06)
                .offset(x: size * 0.055, y: size * 0.08)
        }
        .frame(width: size, height: size * bodyHeightMultiplier)
        .contentShape(Rectangle())
        .background(
            GhostScreenFrameReader { frame in
                ghostFrameInScreen = frame
            }
        )
        .scaleEffect(pulses ? (pulse ? 1.08 : 0.95) : 1.0)
        .scaleEffect(baseScale)
        .opacity(pulses ? (pulse ? 1.0 : 0.68) : 1.0)
        .animation(pulses ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: pulse)
        .animation(.easeOut(duration: 0.09), value: leftPupilOffset)
        .animation(.easeOut(duration: 0.09), value: rightPupilOffset)
        .onReceive(gazeTimer) { _ in
            updateGazeFromCursor()
            flapPhase += flapCyclesPerSecond / 30.0
            if isWorking {
                loadingPhase += 0.028
                if loadingPhase > 10_000 {
                    loadingPhase = loadingPhase.truncatingRemainder(dividingBy: 1)
                }
            }
            if flapPhase > 10_000 {
                flapPhase = flapPhase.truncatingRemainder(dividingBy: 1)
            }
        }
        .onChange(of: pulses) { _, nowPulsing in
            pulse = nowPulsing
        }
        .onChange(of: gazeTarget) { _, _ in
            // keep followingTextCursor pointing at the latest position
            if gazeTarget != nil {
                followingTextCursor = true
            }
        }
        .onChange(of: gazeActivityToken) { _, _ in
            // fires on every keystroke, even when the screen point doesn't change
            followingTextCursor = true
            lastActivityTime = Date()
            isIdle = false
        }
        .onAppear {
            flapPhase = 0
            loadingPhase = 0
            pulse = pulses
        }
    }

    private var pulses: Bool {
        state == .listening
    }

    private var isWorking: Bool {
        state == .working
    }

    private func updateGazeFromCursor() {
        guard !ghostFrameInScreen.isEmpty else {
            leftPupilOffset = .zero
            rightPupilOffset = .zero
            return
        }

        let mouse = NSEvent.mouseLocation
        let mouseMoved = lastMousePos != .zero && hypot(mouse.x - lastMousePos.x, mouse.y - lastMousePos.y) > 1.5
        if mouseMoved {
            followingTextCursor = false
            lastActivityTime = Date()
            if isIdle { isIdle = false }
        }
        lastMousePos = mouse

        let secondsSinceActivity = Date().timeIntervalSince(lastActivityTime)
        if secondsSinceActivity >= 3.0 {
            if !isIdle {
                isIdle = true
                withAnimation(.easeInOut(duration: 0.5)) {
                    leftPupilOffset = .zero
                    rightPupilOffset = .zero
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

        let leftEyeCenter = eyeCenterInScreen(isLeftEye: true)
        let rightEyeCenter = eyeCenterInScreen(isLeftEye: false)

        leftPupilOffset = pupilOffset(toward: target, from: leftEyeCenter)
        rightPupilOffset = pupilOffset(toward: target, from: rightEyeCenter)
    }

    private func eyeCenterInScreen(isLeftEye: Bool) -> CGPoint {
        let eyeSpacing = size * 0.22
        let eyeCenterYOffset = -size * 0.11
        let eyeCenterXInView = size / 2 + (isLeftEye ? -eyeSpacing / 2 : eyeSpacing / 2)
        let eyeCenterYInView = (size * bodyHeightMultiplier) / 2 + eyeCenterYOffset

        return CGPoint(
            x: ghostFrameInScreen.minX + eyeCenterXInView,
            y: ghostFrameInScreen.maxY - eyeCenterYInView
        )
    }

    private func pupilOffset(toward target: CGPoint, from eyeCenter: CGPoint) -> CGSize {
        let dx = target.x - eyeCenter.x
        let dy = target.y - eyeCenter.y

        let rawX = dx * 0.018
        let rawY = -dy * 0.018
        let maxRadius = size * 0.032

        let distance = sqrt(rawX * rawX + rawY * rawY)
        let scale = distance > maxRadius ? maxRadius / distance : 1

        return CGSize(
            width: rawX * scale,
            height: rawY * scale
        )
    }

    private var eyeMetrics: EyeMetrics {
        EyeMetrics(
            spacing: pixelSnapped(size * 0.22),
            verticalOffset: pixelSnapped(-size * 0.11),
            whiteWidth: pixelSnapped(size * 0.198),
            whiteHeight: pixelSnapped(size * 0.184),
            strokeWidth: pixelSnapped(max(0.8, size * 0.018)),
            pupilDiameter: pixelSnapped(size * 0.141),
            highlightDiameter: pixelSnapped(size * 0.033),
            highlightInset: pixelSnapped(size * 0.024)
        )
    }

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
        CGSize(
            width: pixelSnapped(offset.width),
            height: pixelSnapped(offset.height)
        )
    }
}

private struct EyeLoadingDots: View {
    let pupilOffset: CGSize
    let pupilDiameter: CGFloat
    let dotDiameter: CGFloat
    let phase: CGFloat
    let phaseOffset: CGFloat

    private let dotCount = 6

    var body: some View {
        let orbitRadius = pupilDiameter * 0.29

        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                let progress = (phase + phaseOffset + CGFloat(index) / CGFloat(dotCount)).truncatingRemainder(dividingBy: 1)
                let angle = progress * .pi * 2
                let opacity = 0.18 + (Double(index) / Double(dotCount - 1)) * 0.82

                Circle()
                    .fill(.white.opacity(opacity))
                    .frame(width: dotDiameter * 0.72, height: dotDiameter * 0.72)
                    .offset(
                        x: pupilOffset.width + cos(angle) * orbitRadius,
                        y: pupilOffset.height + sin(angle) * orbitRadius
                    )
            }
        }
    }
}

private struct EyeMetrics {
    let spacing: CGFloat
    let verticalOffset: CGFloat
    let whiteWidth: CGFloat
    let whiteHeight: CGFloat
    let strokeWidth: CGFloat
    let pupilDiameter: CGFloat
    let highlightDiameter: CGFloat
    let highlightInset: CGFloat
}

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

private struct GhostBody: Shape {
    var phase: CGFloat = 0

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let leftSideX = rect.minX + width * 0.20
        let rightSideX = rect.maxX - width * 0.20
        let topY = rect.minY + height * 0.10
        let shoulderY = rect.minY + height * 0.43
        let baseY = rect.minY + height * 0.84
        let span = rightSideX - leftSideX
        let uniformFoldCount: CGFloat = 3
        let sampleCount = 48
        let waveAmplitude = height * 0.026

        func bottomPoint(t: CGFloat) -> CGPoint {
            let x = rightSideX - span * t
            let angle = (t * uniformFoldCount * 2 * .pi) + (phase * 2 * .pi)
            let y = baseY + CGFloat(sin(Double(angle))) * waveAmplitude
            return CGPoint(x: x, y: y)
        }

        path.move(to: CGPoint(x: leftSideX, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: rightSideX, y: shoulderY),
            control: CGPoint(x: rect.midX, y: topY)
        )

        path.addCurve(
            to: CGPoint(x: rightSideX, y: baseY),
            control1: CGPoint(x: rightSideX + width * 0.01, y: shoulderY + height * 0.12),
            control2: CGPoint(x: rightSideX + width * 0.012, y: baseY - height * 0.12)
        )

        path.addLine(to: bottomPoint(t: 0))
        for i in 1 ... sampleCount {
            let t = CGFloat(i) / CGFloat(sampleCount)
            path.addLine(to: bottomPoint(t: t))
        }

        path.addCurve(
            to: CGPoint(x: leftSideX, y: shoulderY),
            control1: CGPoint(x: leftSideX - width * 0.01, y: baseY - height * 0.12),
            control2: CGPoint(x: leftSideX - width * 0.01, y: shoulderY + height * 0.12)
        )

        path.closeSubpath()
        return path
    }
}
