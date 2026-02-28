import Combine
import Foundation

enum AssistantState: String, Codable {
    case hidden
    case idle
    case listening
    case working
    case complete
}

struct AssistantOutputItem: Identifiable {
    enum Content {
        case text(String)
        case image(resourceName: String)
    }

    let id = UUID()
    let content: Content
}

@MainActor
final class GhostAssistantModel: ObservableObject {
    @Published var assistantState: AssistantState = .hidden
    @Published var isPeeked = false
    @Published var isVoiceEnabled = true
    @Published var textDraft = ""
    @Published var outputItems: [AssistantOutputItem] = []
    @Published var isSubmittingText = false
    @Published var workingMessage: String?
    @Published var workingStep: Int?
    @Published var workingTotalSteps: Int?
    @Published var isRetreating = false
    @Published var textCursorScreenPoint: CGPoint? = nil
    @Published var textActivityToken: Int = 0
    @Published var micLevel: Float = 0

    var isSleeping: Bool {
        assistantState == .hidden
    }

    private let backendBridge = BackendBridge()
    private var retreatTask: Task<Void, Never>?

    func togglePeekAndListenMode() {
        if isPeeked {
            retreatGhost()
            return
        }

        isPeeked = true
        assistantState = isVoiceEnabled ? .listening : .idle
    }

    func submitIntent(_ intent: String) {
        guard !intent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        assistantState = .working

        Task {
            do {
                let response = try await backendBridge.runGemini(prompt: intent)
                print("Gemini response:\n\(response)")
                assistantState = .complete
                scheduleRetreat()
            } catch {
                print("Gemini invocation failed: \(error)")
                assistantState = .idle
                scheduleRetreat()
            }
        }
    }

    func submitTextIntent(_ intent: String) {
        let trimmed = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        retreatTask?.cancel()
        isPeeked = true
        isSubmittingText = true
        assistantState = .working
        workingMessage = "Understanding: \(trimmed)"

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await self.backendBridge.runAgent(intent: trimmed)
                self.appendOutput(from: response)
            } catch {
                self.outputItems.append(
                    AssistantOutputItem(content: .text("Agent error: \(error.localizedDescription)"))
                )
                print("Agent invocation failed: \(error)")
            }

            self.workingMessage = nil
            self.workingStep = nil
            self.workingTotalSteps = nil
            self.assistantState = .idle
            self.isSubmittingText = false
        }
    }

    private func appendOutput(from response: String) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let lines = trimmed
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var parsedItems: [AssistantOutputItem] = []

        for line in lines {
            if line.hasPrefix("[[image:"), line.hasSuffix("]]"), line.count > 10 {
                let start = line.index(line.startIndex, offsetBy: 8)
                let end = line.index(line.endIndex, offsetBy: -2)
                let name = String(line[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    parsedItems.append(AssistantOutputItem(content: .image(resourceName: name)))
                    continue
                }
            }

            parsedItems.append(AssistantOutputItem(content: .text(line)))
        }

        if parsedItems.isEmpty {
            parsedItems.append(AssistantOutputItem(content: .text(trimmed)))
        }

        outputItems.append(contentsOf: parsedItems)
    }

    func showMessage(_ text: String) {
        retreatTask?.cancel()
        isPeeked = true
        assistantState = .complete
        outputItems.append(AssistantOutputItem(content: .text(text)))
        scheduleRetreat()
    }

    func retreatGhost() {
        retreatTask?.cancel()
        isSubmittingText = false

        guard !isRetreating else { return }
        isRetreating = true

        Task { @MainActor [weak self] in
            // Wait for the ghost fly-up animation to finish (~0.55 s)
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard let self else { return }
            self.isRetreating = false
            self.assistantState = .hidden
            self.isPeeked = false
        }
    }

    func startStateMonitor() {
        backendBridge.onStateUpdate = { [weak self] update in
            Task { @MainActor in
                guard let self else { return }
                self.applyBackendState(update)
            }
        }
        backendBridge.startMonitoringStateFile()
    }

    private func applyBackendState(_ update: BackendStateUpdate) {
        if let newState = update.state {
            assistantState = newState
            isPeeked = newState != .hidden
        }

        if let message = update.message {
            workingMessage = message
        }
        if let step = update.step {
            workingStep = step
        }
        if let totalSteps = update.total_steps {
            workingTotalSteps = totalSteps
        }

        if update.completed == true || update.state == .complete {
            assistantState = .complete
            workingMessage = nil
            workingStep = nil
            workingTotalSteps = nil
            scheduleRetreat()
        }
    }

    private func scheduleRetreat() {
        retreatTask?.cancel()
        retreatTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self?.retreatGhost()
        }
    }
}
