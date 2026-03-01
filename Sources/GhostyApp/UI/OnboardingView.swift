import SwiftUI

// MARK: – Onboarding Data Models

struct MCPServerOption: Identifiable {
    let id: String
    let name: String
    let iconName: String          // SF Symbol
    let requiresAPIKey: Bool
    var apiKey: String = ""
    var isSelected: Bool = false
}

struct SkillOption: Identifiable {
    let id: String
    let name: String
    let iconName: String
    var isSelected: Bool = false
}

// MARK: – ViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Phase: Int, CaseIterable {
        case name = 0
        case personalization
        case mcpSelection
        case skillsSelection
        case themeSelection
        case thankYou
    }

    @Published var phase: Phase = .name
    @Published var userName: String = ""
    @Published var personalizationPrompt: String = ""
    @Published var selectedTheme: String = "og"

    @Published var mcpServers: [MCPServerOption] = [
        MCPServerOption(id: "github", name: "GitHub", iconName: "cat.fill", requiresAPIKey: true),
        MCPServerOption(id: "context7", name: "Context7", iconName: "7.circle.fill", requiresAPIKey: false),
        MCPServerOption(id: "playwright", name: "Playwright", iconName: "theatermasks.fill", requiresAPIKey: false),
        MCPServerOption(id: "notion", name: "Notion", iconName: "note.text", requiresAPIKey: true),
    ]

    @Published var skills: [SkillOption] = [
        SkillOption(id: "find_skills", name: "Find Skills", iconName: "magnifyingglass"),
        SkillOption(id: "nano_banana", name: "Nano Banana", iconName: "leaf.fill"),
        SkillOption(id: "github_cli", name: "Github CLI", iconName: "terminal.fill"),
        SkillOption(id: "moltbook", name: "Moltbook", iconName: "book.fill"),
    ]

    @Published var apiKeyPopoverServerID: String? = nil
    @Published var pendingAPIKey: String = ""

    /// Ghost entrance animation state
    @Published var ghostArrived: Bool = false

    var onComplete: (() -> Void)?

    var canAdvance: Bool {
        switch phase {
        case .name:
            return !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    func advance() {
        guard let next = Phase(rawValue: phase.rawValue + 1) else {
            finish()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            phase = next
        }

        if next == .thankYou {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
                self?.finish()
            }
        }
    }

    func goBack() {
        guard let prev = Phase(rawValue: phase.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            phase = prev
        }
    }

    func toggleMCP(_ id: String) {
        guard let idx = mcpServers.firstIndex(where: { $0.id == id }) else { return }
        let server = mcpServers[idx]

        if server.isSelected {
            // Deselect
            mcpServers[idx].isSelected = false
            mcpServers[idx].apiKey = ""
            return
        }

        if server.requiresAPIKey {
            pendingAPIKey = ""
            apiKeyPopoverServerID = id
        } else {
            mcpServers[idx].isSelected = true
        }
    }

    func confirmAPIKey() {
        guard let id = apiKeyPopoverServerID,
              let idx = mcpServers.firstIndex(where: { $0.id == id })
        else { return }
        mcpServers[idx].isSelected = true
        mcpServers[idx].apiKey = pendingAPIKey
        apiKeyPopoverServerID = nil
        pendingAPIKey = ""
    }

    func cancelAPIKey() {
        apiKeyPopoverServerID = nil
        pendingAPIKey = ""
    }

    func toggleSkill(_ id: String) {
        guard let idx = skills.firstIndex(where: { $0.id == id }) else { return }
        skills[idx].isSelected.toggle()
    }

    private func finish() {
        let sm = SettingsManager.shared
        sm.userName = userName
        sm.personalizationPrompt = personalizationPrompt
        sm.selectedThemeID = selectedTheme
        sm.hasCompletedOnboarding = true
        onComplete?()
    }
}

// MARK: – Main Onboarding View

struct OnboardingView: View {
    @StateObject private var vm = OnboardingViewModel()
    var onComplete: (() -> Void)?

    var body: some View {
        ZStack {
            // Background
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content area
                ZStack {
                    switch vm.phase {
                    case .name:
                        NamePhaseView(vm: vm)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .personalization:
                        PersonalizationPhaseView(vm: vm)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .mcpSelection:
                        MCPSelectionPhaseView(vm: vm)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .skillsSelection:
                        SkillsSelectionPhaseView(vm: vm)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .themeSelection:
                        ThemeSelectionPhaseView(vm: vm)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .thankYou:
                        ThankYouPhaseView(vm: vm)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Navigation bar (hidden on thank you phase)
                if vm.phase != .thankYou {
                    OnboardingNavBar(vm: vm)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)
                }
            }

            // Peeking ghost in top-right corner (hidden on theme selection page)
            if vm.phase != .themeSelection {
                PeekingGhostView(arrived: vm.ghostArrived)
            }
        }
        .onAppear {
            vm.onComplete = onComplete
            // Animate the ghost arriving to its perch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                    vm.ghostArrived = true
                }
            }
        }
    }
}

// MARK: – Peeking Ghost

private struct PeekingGhostView: View {
    let arrived: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer()
                GhostCharacterView(state: .idle, size: 44)
                    .offset(
                        x: -16,
                        y: arrived ? -20 : -70
                    )
                    .opacity(arrived ? 1 : 0)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

// MARK: – Navigation Bar

private struct OnboardingNavBar: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        HStack {
            if vm.phase.rawValue > 0 {
                Button("Back") {
                    vm.goBack()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            // Phase dots
            Spacer()
            HStack(spacing: 6) {
                ForEach(OnboardingViewModel.Phase.allCases, id: \.rawValue) { p in
                    Circle()
                        .fill(p == vm.phase ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            Spacer()

            if vm.phase == .mcpSelection || vm.phase == .skillsSelection || vm.phase == .themeSelection || vm.phase == .personalization {
                Button("Next") {
                    vm.advance()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if vm.phase == .name {
                Button("Next") {
                    vm.advance()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!vm.canAdvance)
            }
        }
        .frame(height: 40)
    }
}

// MARK: – Phase 1: Name

private struct NamePhaseView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Welcome to Ghosty")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("What should Ghosty call you?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Your name", text: $vm.userName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
                .multilineTextAlignment(.center)
                .onSubmit {
                    if vm.canAdvance { vm.advance() }
                }

            Spacer()
        }
        .padding()
    }
}

// MARK: – Phase 2: Personalization

private struct PersonalizationPhaseView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Personalize Ghosty")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Tell Ghosty about yourself — your interests, preferred tone, or anything that makes the experience yours.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            TextEditor(text: $vm.personalizationPrompt)
                .font(.body)
                .frame(maxWidth: 400, minHeight: 120, maxHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                }

            Spacer()
        }
        .padding()
    }
}

// MARK: – Phase 3: MCP Selection

private struct MCPSelectionPhaseView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("MCP Servers")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Choose MCP servers to connect. You can always configure these later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            HStack(spacing: 16) {
                ForEach(vm.mcpServers) { server in
                    MCPCardView(server: server, vm: vm)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
        .sheet(isPresented: Binding(
            get: { vm.apiKeyPopoverServerID != nil },
            set: { if !$0 { vm.cancelAPIKey() } }
        )) {
            APIKeySheet(vm: vm)
        }
    }
}

private struct MCPCardView: View {
    let server: MCPServerOption
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        Button {
            vm.toggleMCP(server.id)
        } label: {
            VStack(spacing: 8) {
                MCPIcon(server: server)
                    .frame(width: 36, height: 36)

                Text(server.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(width: 80, height: 80)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(server.isSelected
                          ? Color.accentColor.opacity(0.18)
                          : Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(server.isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: server.isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MCPIcon: View {
    let server: MCPServerOption

    var body: some View {
        Group {
            switch server.id {
            case "github":
                // GitHub logo-like mark
                Image(systemName: "cat.fill")
                    .font(.system(size: 22))
            case "context7":
                Text("C7")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            case "playwright":
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 22))
            case "notion":
                Image(systemName: "note.text")
                    .font(.system(size: 22))
            default:
                Image(systemName: "server.rack")
                    .font(.system(size: 22))
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct APIKeySheet: View {
    @ObservedObject var vm: OnboardingViewModel

    private var serverName: String {
        vm.mcpServers.first(where: { $0.id == vm.apiKeyPopoverServerID })?.name ?? "Server"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Enter API Key")
                .font(.headline)

            Text("\(serverName) requires an API key to connect.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SecureField("API Key", text: $vm.pendingAPIKey)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            HStack(spacing: 12) {
                Button("Cancel") {
                    vm.cancelAPIKey()
                }
                .buttonStyle(.bordered)

                Button("Confirm") {
                    vm.confirmAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.pendingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 340)
    }
}

// MARK: – Phase 4: Skills Selection

private struct SkillsSelectionPhaseView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Choose Skills")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Select skills for Ghosty to learn. You can add more later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            HStack(spacing: 16) {
                ForEach(vm.skills) { skill in
                    SkillCardView(skill: skill, vm: vm)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }
}

private struct SkillCardView: View {
    let skill: SkillOption
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        Button {
            vm.toggleSkill(skill.id)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: skill.iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)

                Text(skill.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 80, height: 80)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(skill.isSelected
                          ? Color.accentColor.opacity(0.18)
                          : Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(skill.isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: skill.isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Phase 5: Theme Selection

private struct ThemeSelectionPhaseView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Choose a Look")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Pick a style for your ghost.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let columns = [GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 16)]
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(GhostThemeRegistry.shared.themes, id: \.id) { theme in
                    OnboardingThemeCard(
                        label: theme.displayName,
                        theme: theme,
                        isSelected: vm.selectedTheme == theme.id
                    ) {
                        vm.selectedTheme = theme.id
                    }
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }
}

private struct OnboardingThemeCard: View {
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
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.18)
                          : Color(nsColor: .controlBackgroundColor))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Phase 6: Thank You

private struct ThankYouPhaseView: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("You're all set, \(vm.userName)!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            Text("Have fun with Ghosty!")
                .font(.title3)
                .foregroundStyle(.secondary)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}

// MARK: – Visual Effect Background

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
