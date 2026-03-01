import SwiftUI

// MARK: – Wild West Accessory Shapes

/// Wide cowboy hat brim – a thin, curved ellipse wider than the ghost head.
struct CowboyHatBrimShape: GhostAccessoryShapeProvider {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // Outer brim ellipse
        let cy = h * 0.359
        let rx = w * 0.50
        let ry = h * 0.028
        p.addEllipse(in: CGRect(
            x: rect.midX - rx, y: cy - ry,
            width: rx * 2, height: ry * 2
        ))
        return p
    }
}

/// Cowboy hat crown – a tall trapezoid with a classic pinched/dented top.
struct CowboyHatCrownShape: GhostAccessoryShapeProvider {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        let baseY  = h * 0.374
        let topY   = h * 0.214
        let leftX  = w * 0.30
        let rightX = w * 0.70

        p.move(to: CGPoint(x: leftX, y: baseY))
        // Left side up
        p.addLine(to: CGPoint(x: leftX + w * 0.02, y: topY))
        // Left top curve
        p.addCurve(
            to: CGPoint(x: w * 0.43, y: h * 0.194),
            control1: CGPoint(x: leftX + w * 0.02, y: h * 0.184),
            control2: CGPoint(x: w * 0.36, y: h * 0.174)
        )
        // Center dent (pinch)
        p.addCurve(
            to: CGPoint(x: w * 0.57, y: h * 0.194),
            control1: CGPoint(x: w * 0.47, y: h * 0.229),
            control2: CGPoint(x: w * 0.53, y: h * 0.229)
        )
        // Right top curve
        p.addCurve(
            to: CGPoint(x: rightX - w * 0.02, y: topY),
            control1: CGPoint(x: w * 0.64, y: h * 0.174),
            control2: CGPoint(x: rightX - w * 0.02, y: h * 0.184)
        )
        // Right side down
        p.addLine(to: CGPoint(x: rightX, y: baseY))
        p.closeSubpath()
        return p
    }
}

/// A thin band around the base of the hat crown.
struct CowboyHatBandShape: GhostAccessoryShapeProvider {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let topY = h * 0.339
        let botY = h * 0.364
        let leftX  = w * 0.305
        let rightX = w * 0.695
        var p = Path()
        p.addRect(CGRect(x: leftX, y: topY, width: rightX - leftX, height: botY - topY))
        return p
    }
}

/// Triangular bandana hanging from the ghost's neck/shoulder area.
struct BandanaShape: GhostAccessoryShapeProvider {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        let leftX  = w * (-0.02)
        let rightX = w * 1.02
        let topY   = h * 0.54
        let bottomY = h * 0.78
        let midX = rect.midX

        // Top edge follows a slight curve (shoulder line)
        p.move(to: CGPoint(x: leftX, y: topY))
        p.addQuadCurve(
            to: CGPoint(x: rightX, y: topY),
            control: CGPoint(x: midX, y: topY - h * 0.02)
        )
        // Right side down to point
        p.addLine(to: CGPoint(x: midX, y: bottomY))
        // Left side back up
        p.closeSubpath()
        return p
    }
}

/// A small 5-pointed star for the bandana accents.
struct StarShape: GhostAccessoryShapeProvider {
    let centerX: CGFloat   // fraction of width
    let centerY: CGFloat   // fraction of height
    let radius: CGFloat    // fraction of width

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = w * centerX
        let cy = h * centerY
        let r = w * radius
        let innerR = r * 0.40

        var p = Path()
        let points = 5
        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let rad = i.isMultiple(of: 2) ? r : innerR
            let pt = CGPoint(x: cx + rad * cos(angle), y: cy + rad * sin(angle))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: – Wild West Theme Definition

enum WildWestGhostTheme {
    @MainActor static let theme: GhostTheme = {
        var t = GhostTheme(
            id: "wildwest",
            displayName: "Wild West",
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
            mouth: nil,  // bandana covers the mouth area
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

        let hatBrown = Color(red: 0.52, green: 0.32, blue: 0.14)
        let hatDarkBrown = Color(red: 0.36, green: 0.20, blue: 0.08)
        let bandanaRed = Color(red: 0.82, green: 0.12, blue: 0.12)
        let bandanaDarkRed = Color(red: 0.60, green: 0.08, blue: 0.08)

        t.accessories = [
            // Hat brim (behind crown)
            GhostAccessoryConfig(
                shapeProvider: CowboyHatBrimShape(),
                fillColors: [hatBrown, hatDarkBrown],
                fillStart: .top,
                fillEnd: .bottom,
                strokeColor: hatDarkBrown.opacity(0.5),
                strokeWidthRatio: 0.012,
                layer: .aboveEyes
            ),
            // Hat crown
            GhostAccessoryConfig(
                shapeProvider: CowboyHatCrownShape(),
                fillColors: [
                    Color(red: 0.58, green: 0.36, blue: 0.18),
                    hatBrown,
                    hatDarkBrown,
                ],
                fillStart: .topLeading,
                fillEnd: .bottomTrailing,
                strokeColor: hatDarkBrown.opacity(0.4),
                strokeWidthRatio: 0.010,
                layer: .aboveEyes
            ),
            // Hat band
            GhostAccessoryConfig(
                shapeProvider: CowboyHatBandShape(),
                fillColors: [hatDarkBrown],
                layer: .aboveEyes
            ),
            // Bandana
            GhostAccessoryConfig(
                shapeProvider: BandanaShape(),
                fillColors: [bandanaRed, bandanaDarkRed],
                fillStart: .top,
                fillEnd: .bottom,
                strokeColor: bandanaDarkRed.opacity(0.4),
                strokeWidthRatio: 0.008,
                layer: .belowEyes
            ),
            // Star accents on the bandana
            GhostAccessoryConfig(
                shapeProvider: StarShape(centerX: 0.50, centerY: 0.63, radius: 0.045),
                fillColors: [.white],
                opacity: 0.92,
                layer: .belowEyes
            ),
            GhostAccessoryConfig(
                shapeProvider: StarShape(centerX: 0.36, centerY: 0.65, radius: 0.030),
                fillColors: [.white],
                opacity: 0.80,
                layer: .belowEyes
            ),
            GhostAccessoryConfig(
                shapeProvider: StarShape(centerX: 0.64, centerY: 0.65, radius: 0.030),
                fillColors: [.white],
                opacity: 0.80,
                layer: .belowEyes
            ),
        ]

        return t
    }()
}
