import SwiftUI

// MARK: – Dinnerbone Theme Definition
// Entire ghost (body AND face) is upside-down.

enum DinnerboneGhostTheme {
    @MainActor static let theme: GhostTheme = {
        var t = GhostTheme(
            id: "dinnerbone",
            displayName: "Dinnerbone",
            bodyShape: OGBodyShape(),
            bodyFlipped: true,
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
                // Left eye – OG position, will be flipped with body
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

        return t
    }()
}
