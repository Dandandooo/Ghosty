import AppKit
import Combine
import Foundation

/// Persists Ghosty settings using UserDefaults and exposes them as published properties.
@MainActor
final class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    // MARK: – Onboarding

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    // MARK: – Personalization

    @Published var userName: String {
        didSet { defaults.set(userName, forKey: Keys.userName) }
    }

    @Published var personalizationPrompt: String {
        didSet { defaults.set(personalizationPrompt, forKey: Keys.personalizationPrompt) }
    }

    // MARK: – MCP Servers

    /// URL of the MCP servers JSON configuration file.
    let mcpConfigFileURL: URL

    /// Parsed server names from the config file (empty when the file is missing or malformed).
    @Published var mcpServerNames: [String] = []

    // MARK: – Skills

    /// Root folder where OpenClaw-compatible skill bundles live.
    let skillsFolderURL: URL

    /// Names of installed skills detected on disk.
    @Published var installedSkills: [String] = []

    // MARK: – Init

    private let defaults = UserDefaults.standard

    // MARK: – Theme

    @Published var selectedThemeID: String {
        didSet { defaults.set(selectedThemeID, forKey: Keys.selectedThemeID) }
    }

    var selectedTheme: GhostTheme {
        GhostThemeRegistry.shared.theme(forID: selectedThemeID)
    }

    private enum Keys {
        static let hasCompletedOnboarding = "ghosty_hasCompletedOnboarding"
        static let userName = "ghosty_userName"
        static let personalizationPrompt = "ghosty_personalizationPrompt"
        static let selectedThemeID = "ghosty_selectedThemeID"
    }

    init() {
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.userName = defaults.string(forKey: Keys.userName) ?? ""
        self.personalizationPrompt = defaults.string(forKey: Keys.personalizationPrompt) ?? ""
        self.selectedThemeID = defaults.string(forKey: Keys.selectedThemeID) ?? "og"

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let ghostyDir = appSupport.appendingPathComponent("Ghosty", isDirectory: true)

        // Ensure Ghosty application-support directory exists.
        try? FileManager.default.createDirectory(at: ghostyDir, withIntermediateDirectories: true)

        self.mcpConfigFileURL = ghostyDir.appendingPathComponent("mcp_servers.json")
        self.skillsFolderURL = ghostyDir.appendingPathComponent("Skills", isDirectory: true)

        // Create a default (empty) MCP config if it doesn't already exist.
        if !FileManager.default.fileExists(atPath: mcpConfigFileURL.path) {
            let placeholder = """
            {
              "servers": []
            }
            """
            try? placeholder.write(to: mcpConfigFileURL, atomically: true, encoding: .utf8)
        }

        // Ensure Skills folder exists.
        try? FileManager.default.createDirectory(at: skillsFolderURL, withIntermediateDirectories: true)

        reloadMCPServers()
        reloadSkills()
    }

    // MARK: – Reload helpers

    func reloadMCPServers() {
        guard let data = try? Data(contentsOf: mcpConfigFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["servers"] as? [[String: Any]]
        else {
            mcpServerNames = []
            return
        }

        mcpServerNames = servers.compactMap { $0["name"] as? String }
    }

    func reloadSkills() {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: skillsFolderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            installedSkills = []
            return
        }

        installedSkills = entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { $0.lastPathComponent }
            .sorted()
    }

    // MARK: – Actions

    func openMCPConfigInEditor() {
        NSWorkspace.shared.open(mcpConfigFileURL)
    }

    func openSkillsFolder() {
        NSWorkspace.shared.open(skillsFolderURL)
    }
}
