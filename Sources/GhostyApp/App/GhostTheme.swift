import SwiftUI

// MARK: – Body Shape Provider

/// Each ghost supplies its own silhouette by conforming to this protocol.
protocol GhostBodyShapeProvider: Sendable {
    func path(phase: CGFloat, in rect: CGRect) -> Path
}

/// A concrete `Shape` that wraps any `GhostBodyShapeProvider`, forwarding
/// `phase` as animatable data so the wavy/tentacle bottom animates smoothly.
struct ThemeBodyShape: Shape {
    let provider: any GhostBodyShapeProvider & Sendable
    var phase: CGFloat = 0

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        provider.path(phase: phase, in: rect)
    }
}

// MARK: – Accessory Shape Provider

/// Each accessory supplies its own shape by conforming to this protocol.
protocol GhostAccessoryShapeProvider: Sendable {
    func path(in rect: CGRect) -> Path
}

/// A concrete `Shape` that wraps any `GhostAccessoryShapeProvider`.
struct AccessoryShape: Shape {
    let provider: any GhostAccessoryShapeProvider & Sendable

    func path(in rect: CGRect) -> Path {
        provider.path(in: rect)
    }
}

/// Controls whether an accessory draws below or above the eyes layer.
enum AccessoryLayer: Sendable {
    case belowEyes
    case aboveEyes
}

/// Describes a single decorative overlay drawn on top of the ghost body.
struct GhostAccessoryConfig: Sendable {
    let shapeProvider: any GhostAccessoryShapeProvider & Sendable
    let fillColors: [Color]
    let fillStart: UnitPoint
    let fillEnd: UnitPoint
    let strokeColor: Color?
    let strokeWidthRatio: CGFloat
    let opacity: Double
    let layer: AccessoryLayer

    init(
        shapeProvider: any GhostAccessoryShapeProvider & Sendable,
        fillColors: [Color],
        fillStart: UnitPoint = .top,
        fillEnd: UnitPoint = .bottom,
        strokeColor: Color? = nil,
        strokeWidthRatio: CGFloat = 0,
        opacity: Double = 1.0,
        layer: AccessoryLayer = .aboveEyes
    ) {
        self.shapeProvider = shapeProvider
        self.fillColors = fillColors
        self.fillStart = fillStart
        self.fillEnd = fillEnd
        self.strokeColor = strokeColor
        self.strokeWidthRatio = strokeWidthRatio
        self.opacity = opacity
        self.layer = layer
    }
}

// MARK: – Theme Sub-Configs

struct GhostGradientStop {
    let color: Color
    let location: CGFloat? // nil → evenly distributed
}

struct GhostBodyAppearance: Sendable {
    /// Height as a multiple of `size`.
    let heightMultiplier: CGFloat

    // Fill gradient
    let fillColors: [Color]
    let fillStart: UnitPoint
    let fillEnd: UnitPoint

    // Darkening overlay gradient (top → bottom)
    let darkenColors: [Color]

    // Radial highlight
    let highlightCenter: UnitPoint
    let highlightStartRadius: CGFloat // as fraction of size
    let highlightEndRadius: CGFloat   // as fraction of size
    let highlightColors: [Color]
    let highlightOffset: (x: CGFloat, y: CGFloat) // as fractions of size

    // Outline
    let outlineColor: Color
    let outlineWidthRatio: CGFloat // multiplied by size

    // Fabric texture
    let showFabricTexture: Bool
    let fabricTextureOpacity: Double
}

struct GhostEyeConfig: Sendable {
    /// Position relative to body center, as fractions of `size`.
    let relativeX: CGFloat
    let relativeY: CGFloat

    // Sclera
    let scleraWidthRatio: CGFloat
    let scleraHeightRatio: CGFloat
    let scleraColor: Color
    let scleraStrokeColor: Color
    let scleraStrokeOpacity: Double
    let scleraStrokeWidthRatio: CGFloat

    // Pupil
    let pupilDiameterRatio: CGFloat
    let pupilColor: Color

    // Highlight (the small reflection dot)
    let highlightDiameterRatio: CGFloat
    let highlightInsetRatio: CGFloat
    let highlightColor: Color
    let highlightOpacity: Double

    /// Phase offset for loading-dots animation so eyes animate out of sync.
    let loadingPhaseOffset: CGFloat

    /// Phase shift for voice-waveform so eyes animate out of sync.
    let waveformPhaseShift: CGFloat

    // Stalk (optional — draws a stem from a body anchor to the eye)
    /// Length of the stalk as a fraction of `size`. `nil` means no stalk.
    let stalkLengthRatio: CGFloat?
    /// Width of the stalk as a fraction of `size`.
    let stalkWidthRatio: CGFloat
    /// Color of the stalk capsule.
    let stalkColor: Color?

    init(
        relativeX: CGFloat,
        relativeY: CGFloat,
        scleraWidthRatio: CGFloat,
        scleraHeightRatio: CGFloat,
        scleraColor: Color,
        scleraStrokeColor: Color,
        scleraStrokeOpacity: Double,
        scleraStrokeWidthRatio: CGFloat,
        pupilDiameterRatio: CGFloat,
        pupilColor: Color,
        highlightDiameterRatio: CGFloat,
        highlightInsetRatio: CGFloat,
        highlightColor: Color,
        highlightOpacity: Double,
        loadingPhaseOffset: CGFloat,
        waveformPhaseShift: CGFloat,
        stalkLengthRatio: CGFloat? = nil,
        stalkWidthRatio: CGFloat = 0.04,
        stalkColor: Color? = nil
    ) {
        self.relativeX = relativeX
        self.relativeY = relativeY
        self.scleraWidthRatio = scleraWidthRatio
        self.scleraHeightRatio = scleraHeightRatio
        self.scleraColor = scleraColor
        self.scleraStrokeColor = scleraStrokeColor
        self.scleraStrokeOpacity = scleraStrokeOpacity
        self.scleraStrokeWidthRatio = scleraStrokeWidthRatio
        self.pupilDiameterRatio = pupilDiameterRatio
        self.pupilColor = pupilColor
        self.highlightDiameterRatio = highlightDiameterRatio
        self.highlightInsetRatio = highlightInsetRatio
        self.highlightColor = highlightColor
        self.highlightOpacity = highlightOpacity
        self.loadingPhaseOffset = loadingPhaseOffset
        self.waveformPhaseShift = waveformPhaseShift
        self.stalkLengthRatio = stalkLengthRatio
        self.stalkWidthRatio = stalkWidthRatio
        self.stalkColor = stalkColor
    }
}

struct GhostMouthConfig: Sendable {
    let widthRatio: CGFloat
    let heightRatio: CGFloat
    let cornerRadiusRatio: CGFloat
    let offsetX: CGFloat // as fraction of size
    let offsetY: CGFloat // as fraction of size
    let color: Color
    let opacity: Double
    let hiddenInVoiceMode: Bool
}

struct GhostAnimationConfig: Sendable {
    let baseScale: CGFloat
    let flapCyclesPerSecond: CGFloat
    let waveSpeedPerSecond: CGFloat
    let loadingSpeedPerSecond: CGFloat
    let idleTimeoutSeconds: Double
    let gazeSensitivity: CGFloat
    let maxPupilRadiusRatio: CGFloat

    // Pulse (listening mode)
    let pulseScaleLow: CGFloat
    let pulseScaleHigh: CGFloat
    let pulseOpacityLow: Double
    let pulseOpacityHigh: Double
    let pulseDuration: Double

    // Retreat
    let retreatDistanceMultiplier: CGFloat
    let retreatDuration: Double
    let retreatDelay: Double
    let retreatPupilSnapDuration: Double
}

// MARK: – Top-Level Theme

struct GhostTheme: Identifiable, Sendable {
    let id: String
    let displayName: String
    let bodyShape: any GhostBodyShapeProvider & Sendable
    let bodyAppearance: GhostBodyAppearance
    let eyes: [GhostEyeConfig]
    let mouth: GhostMouthConfig?
    let animation: GhostAnimationConfig
    var accessories: [GhostAccessoryConfig] = []
}
