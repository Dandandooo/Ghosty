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
        case streamingText(String)   // in-progress bubble; finalised to .text on newline / completion
        case image(resourceName: String)
        case userMessage(String)
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
    @Published var isRetreating = false
    @Published var textCursorScreenPoint: CGPoint? = nil
    @Published var textActivityToken: Int = 0
    @Published var micLevel: Float = 0

    var isSleeping: Bool {
        assistantState == .hidden
    }

    private let backendBridge = BackendBridge()
    private var retreatTask: Task<Void, Never>?
    private var pendingNewlines = 0

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

        outputItems.append(AssistantOutputItem(content: .userMessage(trimmed)))
        // Seed the first streaming bubble
        outputItems.append(AssistantOutputItem(content: .streamingText("")))

        do {
            try backendBridge.runPythonTemplateStreaming(
                input: trimmed,
                onChunk: { [weak self] chunk in
                    DispatchQueue.main.async {
                        self?.processStreamingChunk(chunk)
                    }
                },
                onComplete: { [weak self] result in
                    DispatchQueue.main.async {
                        self?.finishStreaming(result: result)
                    }
                }
            )
        } catch {
            // Launch failed immediately – tidy up and show error
            if case .streamingText = outputItems.last?.content { outputItems.removeLast() }
            outputItems.append(AssistantOutputItem(content: .text("Backend unavailable: \(error.localizedDescription)")))
            isSubmittingText = false
            assistantState = .idle
        }
    }

    private func processStreamingChunk(_ chunk: String) {
        for char in chunk {
            if char == "\n" {
                pendingNewlines += 1
            } else {
                if pendingNewlines >= 2 {
                    // Double+ newline → new bubble
                    pendingNewlines = 0
                    if case .streamingText(let text) = outputItems.last?.content {
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // Reuse empty bubble
                            outputItems[outputItems.count - 1] =
                                AssistantOutputItem(content: .streamingText(String(char)))
                        } else {
                            outputItems[outputItems.count - 1] =
                                AssistantOutputItem(content: .text(text))
                            outputItems.append(AssistantOutputItem(content: .streamingText(String(char))))
                        }
                    } else {
                        outputItems.append(AssistantOutputItem(content: .streamingText(String(char))))
                    }
                } else if pendingNewlines == 1 {
                    // Single newline → line break within the same bubble
                    pendingNewlines = 0
                    if case .streamingText(let text) = outputItems.last?.content {
                        outputItems[outputItems.count - 1] =
                            AssistantOutputItem(content: .streamingText(text + "\n" + String(char)))
                    } else {
                        outputItems.append(AssistantOutputItem(content: .streamingText(String(char))))
                    }
                } else {
                    // Normal character, no pending newlines
                    if case .streamingText(let text) = outputItems.last?.content {
                        outputItems[outputItems.count - 1] =
                            AssistantOutputItem(content: .streamingText(text + String(char)))
                    } else {
                        outputItems.append(AssistantOutputItem(content: .streamingText(String(char))))
                    }
                }
            }
        }
    }

    private func finishStreaming(result: Result<Void, Error>) {
        pendingNewlines = 0

        // Finalise the dangling streaming bubble
        if case .streamingText(let text) = outputItems.last?.content {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                outputItems.removeLast()
            } else {
                outputItems[outputItems.count - 1] =
                    AssistantOutputItem(content: .text(text))
            }
        }

        if case .failure(let error) = result {
            outputItems.append(AssistantOutputItem(content: .text("Error: \(error.localizedDescription)")))
        }

        isSubmittingText = false
        assistantState = .idle
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
