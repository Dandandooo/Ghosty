import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        TabView {
            Tab("Personalization", systemImage: "person.crop.circle") {
                PersonalizationTab(settings: settings)
            }

            Tab("Theme", systemImage: "paintbrush") {
                ThemeTab()
            }

            Tab("MCP Servers", systemImage: "server.rack") {
                MCPServersTab(settings: settings)
            }

            Tab("Skills", systemImage: "puzzlepiece.extension") {
                SkillsTab(settings: settings)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSidebarBottomBar {
            Spacer().frame(width: 170)
        }
        .frame(minWidth: 600, minHeight: 420)
    }
}

// MARK: – Personalization

private struct PersonalizationTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section {
                TextField("Your Name", text: $settings.userName)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Name")
            } footer: {
                Text("Ghosty will use this name when talking to you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextEditor(text: $settings.personalizationPrompt)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
            } header: {
                Text("Personalization Prompt")
            } footer: {
                Text("Describe how you'd like Ghosty to feel — tone, personality quirks, topics of interest, etc.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: – Ghosty Theme

private struct ThemeTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    private let themes = GhostThemeRegistry.shared.themes

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a theme for your ghost.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let columns = [GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 16)]
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(themes, id: \.id) { theme in
                    ThemeCard(
                        label: theme.displayName,
                        theme: theme,
                        isSelected: settings.selectedThemeID == theme.id
                    ) {
                        settings.selectedThemeID = theme.id
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

private struct ThemeCard: View {
    let label: String
    var theme: GhostTheme = OGGhostTheme.theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                GhostCharacterView(state: .idle, size: 48, theme: theme)
                    .allowsHitTesting(false)
                    .frame(width: 72, height: 72)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: – MCP Servers

private struct MCPServersTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MCP servers are loaded from a JSON configuration file.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if settings.mcpServerNames.isEmpty {
                ContentUnavailableView {
                    Label("No MCP Servers Found", systemImage: "server.rack")
                } description: {
                    Text("Add servers to your configuration file to see them here.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(settings.mcpServerNames, id: \.self) { name in
                    Label(name, systemImage: "server.rack")
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            HStack {
                Button("Open Configuration File") {
                    settings.openMCPConfigInEditor()
                }
                .buttonStyle(.bordered)

                Button("Reload") {
                    settings.reloadMCPServers()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

// MARK: – Skills

private struct SkillsTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skills compatible with OpenClaw or downloaded from the ClawHub.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if settings.installedSkills.isEmpty {
                ContentUnavailableView {
                    Label("No Skills Installed", systemImage: "puzzlepiece.extension")
                } description: {
                    Text("Add skill folders to the Skills directory to see them here.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(settings.installedSkills, id: \.self) { skill in
                    Label(skill, systemImage: "puzzlepiece.extension")
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            HStack {
                Button("Open Skills Folder") {
                    settings.openSkillsFolder()
                }
                .buttonStyle(.bordered)

                Button("Reload") {
                    settings.reloadSkills()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
