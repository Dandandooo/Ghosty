import SwiftUI

// MARK: – Blingy Accessory Shapes

/// A thick U-shaped gold chain draped around the ghost's neck.
struct GoldChainShape: GhostAccessoryShapeProvider {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()

        let thickness = w * 0.045
        let leftX  = w * 0.26
        let rightX = w * 0.74
        let topY   = h * 0.668
        let bottomY = h * 0.908

        // Outer U
        p.move(to: CGPoint(x: leftX, y: topY))
        p.addCurve(
            to: CGPoint(x: rightX, y: topY),
            control1: CGPoint(x: leftX - w * 0.02, y: bottomY + h * 0.04),
            control2: CGPoint(x: rightX + w * 0.02, y: bottomY + h * 0.04)
        )
        // Inner U (going back)
        p.addCurve(
            to: CGPoint(x: leftX + thickness, y: topY),
            control1: CGPoint(x: rightX - thickness + w * 0.01, y: bottomY - h * 0.02),
            control2: CGPoint(x: leftX + thickness - w * 0.01, y: bottomY - h * 0.02)
        )
        p.closeSubpath()
        return p
    }
}

/// A circular medallion at the bottom center of the chain.
struct MedallionShape: GhostAccessoryShapeProvider {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = w * 0.50
        let cy = h * 0.883
        let r = w * 0.085
        var p = Path()
        p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        return p
    }
}

/// Inner ring of the medallion for depth.
struct MedallionInnerRingShape: GhostAccessoryShapeProvider {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = w * 0.50
        let cy = h * 0.883
        let outerR = w * 0.078
        let innerR = w * 0.065
        var p = Path()
        p.addEllipse(in: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2))
        // Cut out the inner circle to form a ring
        p.addEllipse(in: CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2))
        return p
    }
}

/// The letter "G" on the medallion.
struct MedallionLetterGShape: GhostAccessoryShapeProvider {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = w * 0.50
        let cy = h * 0.883
        let r = w * 0.048
        let thickness = w * 0.018
        var p = Path()

        // Approximate the letter G as an arc + horizontal bar
        // Outer arc (about 300 degrees, gap at right side)
        let startAngle = Angle.degrees(-50)
        let endAngle = Angle.degrees(220)
        p.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                 startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.addArc(center: CGPoint(x: cx, y: cy), radius: r - thickness,
                 startAngle: endAngle, endAngle: startAngle, clockwise: true)
        p.closeSubpath()

        // Horizontal bar of the G (the crossbar)
        let barLeft = cx - w * 0.004
        let barRight = cx + r * cos(startAngle.radians)
        let barTop = cy - thickness / 2
        p.addRect(CGRect(x: barLeft, y: barTop, width: barRight - barLeft, height: thickness))

        return p
    }
}

/// Small reflective glint for bling shine effect.
struct GlintShape: GhostAccessoryShapeProvider {
    let centerX: CGFloat  // fraction of width
    let centerY: CGFloat  // fraction of height
    let radius: CGFloat   // fraction of width

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = w * centerX
        let cy = h * centerY
        let r = w * radius
        var p = Path()

        // 4-pointed star glint
        p.move(to: CGPoint(x: cx, y: cy - r))
        p.addQuadCurve(to: CGPoint(x: cx + r * 0.25, y: cy - r * 0.25),
                       control: CGPoint(x: cx + r * 0.06, y: cy - r * 0.06))
        p.addQuadCurve(to: CGPoint(x: cx + r, y: cy),
                       control: CGPoint(x: cx + r * 0.06, y: cy + r * 0.06))
        p.addQuadCurve(to: CGPoint(x: cx + r * 0.25, y: cy + r * 0.25),
                       control: CGPoint(x: cx + r * 0.06, y: cy + r * 0.06))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy + r),
                       control: CGPoint(x: cx - r * 0.06, y: cy + r * 0.06))
        p.addQuadCurve(to: CGPoint(x: cx - r * 0.25, y: cy + r * 0.25),
                       control: CGPoint(x: cx - r * 0.06, y: cy + r * 0.06))
        p.addQuadCurve(to: CGPoint(x: cx - r, y: cy),
                       control: CGPoint(x: cx - r * 0.06, y: cy - r * 0.06))
        p.addQuadCurve(to: CGPoint(x: cx - r * 0.25, y: cy - r * 0.25),
                       control: CGPoint(x: cx - r * 0.06, y: cy - r * 0.06))
        p.closeSubpath()
        return p
    }
}

// MARK: – Blingy Theme Definition

enum BlingyGhostTheme {
    @MainActor static let theme: GhostTheme = {
        let goldBright = Color(red: 1.00, green: 0.84, blue: 0.00)
        let goldMid    = Color(red: 0.85, green: 0.65, blue: 0.00)
        let goldDark   = Color(red: 0.60, green: 0.44, blue: 0.00)
        let goldDeep   = Color(red: 0.45, green: 0.32, blue: 0.00)

        var t = GhostTheme(
            id: "blingy",
            displayName: "Blingy",
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

        t.accessories = [
            // Gold chain
            GhostAccessoryConfig(
                shapeProvider: GoldChainShape(),
                fillColors: [goldBright, goldMid, goldDark],
                fillStart: .topLeading,
                fillEnd: .bottomTrailing,
                strokeColor: goldDeep.opacity(0.5),
                strokeWidthRatio: 0.008,
                layer: .belowEyes
            ),
            // Medallion
            GhostAccessoryConfig(
                shapeProvider: MedallionShape(),
                fillColors: [goldBright, goldMid],
                fillStart: .topLeading,
                fillEnd: .bottomTrailing,
                strokeColor: goldDark.opacity(0.6),
                strokeWidthRatio: 0.012,
                layer: .belowEyes
            ),
            // Medallion inner ring (depth)
            GhostAccessoryConfig(
                shapeProvider: MedallionInnerRingShape(),
                fillColors: [goldDark.opacity(0.4)],
                layer: .belowEyes
            ),
            // Letter G
            GhostAccessoryConfig(
                shapeProvider: MedallionLetterGShape(),
                fillColors: [goldDeep],
                layer: .belowEyes
            ),
            // Reflective glint on chain (upper left)
            GhostAccessoryConfig(
                shapeProvider: GlintShape(centerX: 0.34, centerY: 0.728, radius: 0.032),
                fillColors: [.white],
                opacity: 0.75,
                layer: .belowEyes
            ),
            // Reflective glint on medallion
            GhostAccessoryConfig(
                shapeProvider: GlintShape(centerX: 0.47, centerY: 0.863, radius: 0.025),
                fillColors: [.white],
                opacity: 0.65,
                layer: .belowEyes
            ),
            // Small glint on chain (upper right)
            GhostAccessoryConfig(
                shapeProvider: GlintShape(centerX: 0.68, centerY: 0.708, radius: 0.022),
                fillColors: [.white],
                opacity: 0.55,
                layer: .belowEyes
            ),
        ]

        return t
    }()
}
