import Foundation

/// Central registry of all available ghost themes.
@MainActor
final class GhostThemeRegistry {
    static let shared = GhostThemeRegistry()

    /// Ordered list of all registered themes.
    let themes: [GhostTheme]

    /// The fallback theme used when a stored ID doesn't match anything.
    var defaultTheme: GhostTheme { themes[0] }

    private init() {
        themes = [
            OGGhostTheme.theme,
            AlienGhostTheme.theme,
            WildWestGhostTheme.theme,
            BlingyGhostTheme.theme,
            NighttimeGhostTheme.theme,
        ]
    }

    /// Look up a theme by its `id`. Returns `defaultTheme` if not found.
    func theme(forID id: String) -> GhostTheme {
        themes.first { $0.id == id } ?? defaultTheme
    }
}
