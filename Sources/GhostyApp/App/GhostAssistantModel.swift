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
    @Published var textCursorScreenPoint: CGPoint? = nil
    @Published var textActivityToken: Int = 0

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

        Task { @MainActor [weak self] in
            guard let self else { return }
            let startedAt = Date()
            do {
                let response = try self.backendBridge.runPythonTemplate(input: trimmed)
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed < 2.0 {
                    try? await Task.sleep(nanoseconds: UInt64((2.0 - elapsed) * 1_000_000_000))
                }
                self.appendOutput(from: response)
                self.assistantState = .idle
            } catch {
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed < 2.0 {
                    try? await Task.sleep(nanoseconds: UInt64((2.0 - elapsed) * 1_000_000_000))
                }
                self.outputItems.append(
                    AssistantOutputItem(content: .text("Template response: backend unavailable for \"\(trimmed)\"."))
                )
                self.assistantState = .idle
                print("Python backend invocation failed: \(error)")
            }

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

    func retreatGhost() {
        retreatTask?.cancel()
        isSubmittingText = false
        assistantState = .hidden
        isPeeked = false
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
        if let state = update.state {
            assistantState = state
            isPeeked = state != .hidden
        }

        if update.completed == true {
            assistantState = .complete
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
