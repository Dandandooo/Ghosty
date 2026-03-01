import SwiftUI

// MARK: – Alien Body Shape

struct AlienBodyShape: GhostBodyShapeProvider {
    func path(phase: CGFloat, in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // A taller, narrower domed head tapering to a wider tentacle base.
        let headApexY = rect.minY + h * 0.04           // pointy top
        let headSideY = rect.minY + h * 0.32           // where head meets "shoulders"
        let midBodyY  = rect.minY + h * 0.55           // widest point (bulge)
        let tentacleStartY = rect.minY + h * 0.72      // where tentacles begin

        let headLeftX  = rect.minX + w * 0.28
        let headRightX = rect.maxX - w * 0.28
        let bulgeLeftX  = rect.minX + w * 0.12
        let bulgeRightX = rect.maxX - w * 0.12
        let tentacleLeftX  = rect.minX + w * 0.15
        let tentacleRightX = rect.maxX - w * 0.15

        // Start from left head side, draw the pointy dome
        path.move(to: CGPoint(x: headLeftX, y: headSideY))

        // Left side of dome → apex (pointy)
        path.addCurve(
            to: CGPoint(x: rect.midX, y: headApexY),
            control1: CGPoint(x: headLeftX - w * 0.02, y: headSideY - h * 0.14),
            control2: CGPoint(x: rect.midX - w * 0.08, y: headApexY)
        )

        // Apex → right side of dome
        path.addCurve(
            to: CGPoint(x: headRightX, y: headSideY),
            control1: CGPoint(x: rect.midX + w * 0.08, y: headApexY),
            control2: CGPoint(x: headRightX + w * 0.02, y: headSideY - h * 0.14)
        )

        // Right side: head → bulge outward → tentacle start
        path.addCurve(
            to: CGPoint(x: bulgeRightX, y: midBodyY),
            control1: CGPoint(x: headRightX + w * 0.06, y: headSideY + h * 0.06),
            control2: CGPoint(x: bulgeRightX + w * 0.04, y: midBodyY - h * 0.06)
        )

        path.addCurve(
            to: CGPoint(x: tentacleRightX, y: tentacleStartY),
            control1: CGPoint(x: bulgeRightX + w * 0.02, y: midBodyY + h * 0.08),
            control2: CGPoint(x: tentacleRightX + w * 0.03, y: tentacleStartY - h * 0.05)
        )

        // Tentacle bottom — 5 lobes with deep, asymmetric motion
        let tentacleCount = 5
        let sampleCount = 60
        let span = tentacleRightX - tentacleLeftX
        let baseY = rect.minY + h * 0.88
        let amplitude = h * 0.075    // much deeper than OG's gentle wave

        func tentaclePoint(t: CGFloat) -> CGPoint {
            let x = tentacleRightX - span * t
            let angle = t * CGFloat(tentacleCount) * 2 * .pi + phase * 2 * .pi
            // Asymmetric: sharper dip, rounder peak (tentacle tips hang down)
            let wave = sin(Double(angle))
            let sharpened = wave < 0 ? wave * 1.4 : wave * 0.7
            let y = baseY + CGFloat(sharpened) * amplitude
            return CGPoint(x: x, y: y)
        }

        path.addLine(to: tentaclePoint(t: 0))
        for i in 1...sampleCount {
            let t = CGFloat(i) / CGFloat(sampleCount)
            path.addLine(to: tentaclePoint(t: t))
        }

        // Left side: tentacle start → bulge → head
        path.addCurve(
            to: CGPoint(x: bulgeLeftX, y: midBodyY),
            control1: CGPoint(x: tentacleLeftX - w * 0.03, y: tentacleStartY - h * 0.05),
            control2: CGPoint(x: bulgeLeftX - w * 0.02, y: midBodyY + h * 0.08)
        )

        path.addCurve(
            to: CGPoint(x: headLeftX, y: headSideY),
            control1: CGPoint(x: bulgeLeftX - w * 0.04, y: midBodyY - h * 0.06),
            control2: CGPoint(x: headLeftX - w * 0.06, y: headSideY + h * 0.06)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: – Alien Theme Definition

enum AlienGhostTheme {
    @MainActor static let theme = GhostTheme(
        id: "alien",
        displayName: "The Alien",
        bodyShape: AlienBodyShape(),
        bodyAppearance: GhostBodyAppearance(
            heightMultiplier: 1.42,  // taller than OG
            fillColors: [
                Color(red: 0.18, green: 0.62, blue: 0.22),   // dark green
                Color(red: 0.22, green: 0.72, blue: 0.28),   // medium green
                Color(red: 0.38, green: 0.82, blue: 0.32),   // lime-ish
            ],
            fillStart: .topLeading,
            fillEnd: .bottomTrailing,
            darkenColors: [
                .black.opacity(0.0),
                .black.opacity(0.06),
                .black.opacity(0.18),
            ],
            highlightCenter: .topLeading,
            highlightStartRadius: 0,
            highlightEndRadius: 0.50,
            highlightColors: [
                Color(red: 0.3, green: 0.95, blue: 0.85).opacity(0.45),  // teal glow
                Color(red: 0.3, green: 0.95, blue: 0.85).opacity(0.0),
            ],
            highlightOffset: (x: -0.05, y: -0.08),
            outlineColor: Color(red: 0.08, green: 0.35, blue: 0.12).opacity(0.30),
            outlineWidthRatio: 0.028,
            showFabricTexture: false,
            fabricTextureOpacity: 0
        ),
        eyes: [
            // Left eye (on stalk)
            GhostEyeConfig(
                relativeX: -0.30,
                relativeY: -0.30,
                scleraWidthRatio: 0.155,
                scleraHeightRatio: 0.155,
                scleraColor: Color(red: 0.72, green: 0.92, blue: 1.0),
                scleraStrokeColor: Color(red: 0.15, green: 0.35, blue: 0.55),
                scleraStrokeOpacity: 0.35,
                scleraStrokeWidthRatio: 0.016,
                pupilDiameterRatio: 0.108,
                pupilColor: Color(red: 0.10, green: 0.12, blue: 0.45),
                highlightDiameterRatio: 0.028,
                highlightInsetRatio: 0.020,
                highlightColor: Color(red: 0.6, green: 0.9, blue: 1.0),
                highlightOpacity: 0.9,
                loadingPhaseOffset: 0.0,
                waveformPhaseShift: 0.0,
                stalkLengthRatio: 0.20,
                stalkWidthRatio: 0.038,
                stalkColor: Color(red: 0.20, green: 0.58, blue: 0.24)
            ),
            // Center eye (on taller stalk)
            GhostEyeConfig(
                relativeX: 0.0,
                relativeY: -0.36,
                scleraWidthRatio: 0.175,
                scleraHeightRatio: 0.175,
                scleraColor: Color(red: 0.72, green: 0.92, blue: 1.0),
                scleraStrokeColor: Color(red: 0.15, green: 0.35, blue: 0.55),
                scleraStrokeOpacity: 0.35,
                scleraStrokeWidthRatio: 0.018,
                pupilDiameterRatio: 0.125,
                pupilColor: Color(red: 0.10, green: 0.12, blue: 0.45),
                highlightDiameterRatio: 0.032,
                highlightInsetRatio: 0.023,
                highlightColor: Color(red: 0.6, green: 0.9, blue: 1.0),
                highlightOpacity: 0.9,
                loadingPhaseOffset: 0.33,
                waveformPhaseShift: 0.25,
                stalkLengthRatio: 0.22,
                stalkWidthRatio: 0.042,
                stalkColor: Color(red: 0.20, green: 0.58, blue: 0.24)
            ),
            // Right eye (on stalk)
            GhostEyeConfig(
                relativeX: 0.30,
                relativeY: -0.30,
                scleraWidthRatio: 0.155,
                scleraHeightRatio: 0.155,
                scleraColor: Color(red: 0.72, green: 0.92, blue: 1.0),
                scleraStrokeColor: Color(red: 0.15, green: 0.35, blue: 0.55),
                scleraStrokeOpacity: 0.35,
                scleraStrokeWidthRatio: 0.016,
                pupilDiameterRatio: 0.108,
                pupilColor: Color(red: 0.10, green: 0.12, blue: 0.45),
                highlightDiameterRatio: 0.028,
                highlightInsetRatio: 0.020,
                highlightColor: Color(red: 0.6, green: 0.9, blue: 1.0),
                highlightOpacity: 0.9,
                loadingPhaseOffset: 0.66,
                waveformPhaseShift: 0.50,
                stalkLengthRatio: 0.20,
                stalkWidthRatio: 0.038,
                stalkColor: Color(red: 0.20, green: 0.58, blue: 0.24)
            ),
        ],
        mouth: nil,  // aliens don't have mouths
        animation: GhostAnimationConfig(
            baseScale: 1.06,
            flapCyclesPerSecond: 0.35,         // faster tentacle movement
            waveSpeedPerSecond: 0.54,
            loadingSpeedPerSecond: 0.84,
            idleTimeoutSeconds: 3.0,
            gazeSensitivity: 0.022,            // slightly more responsive
            maxPupilRadiusRatio: 0.030,
            pulseScaleLow: 0.93,               // deeper alien throb
            pulseScaleHigh: 1.10,
            pulseOpacityLow: 0.62,
            pulseOpacityHigh: 1.0,
            pulseDuration: 0.7,
            retreatDistanceMultiplier: 4.5,
            retreatDuration: 0.42,
            retreatDelay: 0.08,
            retreatPupilSnapDuration: 0.12
        )
    )
}
