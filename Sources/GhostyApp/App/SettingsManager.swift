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

    // MARK: – MCP Config Writing

    /// Serialises the given selected MCP server options to `mcp_servers.json` and
    /// reloads the in-memory list.
    func writeMCPConfig(servers: [MCPServerOption]) {
        var entries: [[String: Any]] = []
        for s in servers {
            var entry: [String: Any] = [
                "name": s.name,
                "command": s.command,
                "args": s.args,
            ]
            if let key = s.envKeyName, !s.apiKey.isEmpty {
                entry["env"] = [key: s.apiKey]
            }
            entries.append(entry)
        }
        let json: [String: Any] = ["servers": entries]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: mcpConfigFileURL, options: .atomic)
        }
        reloadMCPServers()
    }

    // MARK: – Skill Installation

    /// Extracts the bundled default-skill zip (located under the app bundle's
    /// `DefaultSkills` resource directory) into the user's Skills folder.
    ///
    /// The zip is expected to contain a `_meta.json` with a `"slug"` field that
    /// determines the destination folder name.  If the meta is absent the slug is
    /// derived from the zip file name by stripping the version suffix.
    func installDefaultSkill(zipFileName: String) {
        let stem = zipFileName.hasSuffix(".zip")
            ? String(zipFileName.dropLast(4))
            : zipFileName

        // Try with and without the DefaultSkills sub-directory prefix.
        let zipURL: URL? =
            Bundle.module.url(forResource: stem, withExtension: "zip", subdirectory: "DefaultSkills")
            ?? Bundle.module.url(forResource: stem, withExtension: "zip")

        guard let zipURL else {
            print("Ghosty: bundled skill zip not found: \(zipFileName)")
            return
        }

        // Unzip to a temporary directory first.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ghosty_skill_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc.arguments = ["-o", zipURL.path, "-d", tmp.path]
        try? proc.run()
        proc.waitUntilExit()

        // Determine slug from _meta.json or fall back to stem-minus-version.
        let slug: String
        let metaURL = tmp.appendingPathComponent("_meta.json")
        if let data = try? Data(contentsOf: metaURL),
           let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let s = meta["slug"] as? String, !s.isEmpty {
            slug = s
        } else {
            // Strip trailing version segment like "-1.0.0"
            let parts = stem.split(separator: "-")
            let versionPattern = #/^\d+\.\d+.*$/#
            slug = parts.drop(while: { _ in false })
                .reversed()
                .drop(while: { $0.contains(".") || ($0.firstMatch(of: versionPattern) != nil) })
                .reversed()
                .joined(separator: "-")
                .nonEmpty ?? stem
        }

        let dest = skillsFolderURL.appendingPathComponent(slug, isDirectory: true)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.moveItem(at: tmp, to: dest)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
