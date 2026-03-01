import SwiftUI

// MARK: – OG Ghost Body Shape

struct OGBodyShape: GhostBodyShapeProvider {
    func path(phase: CGFloat, in rect: CGRect) -> Path {
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
        for i in 1...sampleCount {
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

// MARK: – OG Theme Definition

enum OGGhostTheme {
    @MainActor static let theme = GhostTheme(
        id: "og",
        displayName: "The OG",
        bodyShape: OGBodyShape(),
        bodyAppearance: GhostBodyAppearance(
            heightMultiplier: 1.28,
            fillColors: [
                Color.white,
                Color(white: 0.992),
                Color(white: 0.965),
            ],
            fillStart: .topLeading,
            fillEnd: .bottomTrailing,
            darkenColors: [
                .black.opacity(0.0),
                .black.opacity(0.05),
                .black.opacity(0.12),
            ],
            highlightCenter: .topLeading,
            highlightStartRadius: 0,
            highlightEndRadius: 0.55,
            highlightColors: [
                .white.opacity(0.56),
                .white.opacity(0.0),
            ],
            highlightOffset: (x: -0.06, y: -0.10),
            outlineColor: .black.opacity(0.11),
            outlineWidthRatio: 0.03,
            showFabricTexture: true,
            fabricTextureOpacity: 0.24
        ),
        eyes: [
            // Left eye
            GhostEyeConfig(
                relativeX: -0.20,
                relativeY: -0.11,
                scleraWidthRatio: 0.198,
                scleraHeightRatio: 0.184,
                scleraColor: .white,
                scleraStrokeColor: .black,
                scleraStrokeOpacity: 0.22,
                scleraStrokeWidthRatio: 0.018,
                pupilDiameterRatio: 0.141,
                pupilColor: .black,
                highlightDiameterRatio: 0.033,
                highlightInsetRatio: 0.024,
                highlightColor: .white,
                highlightOpacity: 0.95,
                loadingPhaseOffset: 0,
                waveformPhaseShift: 0.0
            ),
            // Right eye
            GhostEyeConfig(
                relativeX: 0.20,
                relativeY: -0.11,
                scleraWidthRatio: 0.198,
                scleraHeightRatio: 0.184,
                scleraColor: .white,
                scleraStrokeColor: .black,
                scleraStrokeOpacity: 0.22,
                scleraStrokeWidthRatio: 0.018,
                pupilDiameterRatio: 0.141,
                pupilColor: .black,
                highlightDiameterRatio: 0.033,
                highlightInsetRatio: 0.024,
                highlightColor: .white,
                highlightOpacity: 0.95,
                loadingPhaseOffset: 0.5,
                waveformPhaseShift: 0.37
            ),
        ],
        mouth: GhostMouthConfig(
            widthRatio: 0.14,
            heightRatio: 0.06,
            cornerRadiusRatio: 0.08,
            offsetX: 0.055,
            offsetY: 0.08,
            color: .black,
            opacity: 0.82,
            hiddenInVoiceMode: true
        ),
        animation: GhostAnimationConfig(
            baseScale: 1.06,
            flapCyclesPerSecond: 0.22,
            waveSpeedPerSecond: 0.54,
            loadingSpeedPerSecond: 0.84,
            idleTimeoutSeconds: 3.0,
            gazeSensitivity: 0.018,
            maxPupilRadiusRatio: 0.032,
            pulseScaleLow: 0.95,
            pulseScaleHigh: 1.08,
            pulseOpacityLow: 0.68,
            pulseOpacityHigh: 1.0,
            pulseDuration: 0.6,
            retreatDistanceMultiplier: 4.5,
            retreatDuration: 0.42,
            retreatDelay: 0.08,
            retreatPupilSnapDuration: 0.12
        )
    )
}
