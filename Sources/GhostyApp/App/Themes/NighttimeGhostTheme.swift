import SwiftUI

// MARK: – Nighttime Theme Definition

/// A dark-bodied ghost for nighttime vibes – same OG silhouette, pitch-dark
/// fill with a subtle moonlit highlight and softly glowing eyes.
enum NighttimeGhostTheme {
    @MainActor static let theme = GhostTheme(
        id: "nighttime",
        displayName: "Nighttime",
        bodyShape: OGBodyShape(),
        bodyAppearance: GhostBodyAppearance(
            heightMultiplier: 1.28,
            fillColors: [
                Color(white: 0.12),
                Color(white: 0.08),
                Color(white: 0.04),
            ],
            fillStart: .topLeading,
            fillEnd: .bottomTrailing,
            darkenColors: [
                .black.opacity(0.0),
                .black.opacity(0.08),
                .black.opacity(0.20),
            ],
            highlightCenter: .topLeading,
            highlightStartRadius: 0,
            highlightEndRadius: 0.50,
            highlightColors: [
                Color(red: 0.45, green: 0.50, blue: 0.65).opacity(0.35),  // cool moonlit glow
                Color(red: 0.45, green: 0.50, blue: 0.65).opacity(0.0),
            ],
            highlightOffset: (x: -0.06, y: -0.10),
            outlineColor: Color(white: 0.25).opacity(0.30),
            outlineWidthRatio: 0.03,
            showFabricTexture: false,
            fabricTextureOpacity: 0
        ),
        eyes: [
            // Left eye – pale glowing sclera against the dark body
            GhostEyeConfig(
                relativeX: -0.20,
                relativeY: -0.11,
                scleraWidthRatio: 0.198,
                scleraHeightRatio: 0.184,
                scleraColor: Color(red: 0.78, green: 0.82, blue: 0.92),
                scleraStrokeColor: Color(red: 0.55, green: 0.60, blue: 0.75),
                scleraStrokeOpacity: 0.40,
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
                scleraColor: Color(red: 0.78, green: 0.82, blue: 0.92),
                scleraStrokeColor: Color(red: 0.55, green: 0.60, blue: 0.75),
                scleraStrokeOpacity: 0.40,
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
            color: Color(white: 0.30),
            opacity: 0.70,
            hiddenInVoiceMode: true
        ),
        animation: GhostAnimationConfig(
            baseScale: 1.06,
            flapCyclesPerSecond: 0.18,         // slightly slower, spookier
            waveSpeedPerSecond: 0.54,
            loadingSpeedPerSecond: 0.84,
            idleTimeoutSeconds: 3.0,
            gazeSensitivity: 0.018,
            maxPupilRadiusRatio: 0.032,
            pulseScaleLow: 0.93,
            pulseScaleHigh: 1.06,
            pulseOpacityLow: 0.60,
            pulseOpacityHigh: 1.0,
            pulseDuration: 0.75,               // slower, eerie pulse
            retreatDistanceMultiplier: 4.5,
            retreatDuration: 0.42,
            retreatDelay: 0.08,
            retreatPupilSnapDuration: 0.12
        )
    )
}
