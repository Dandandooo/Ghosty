import Combine
import Foundation
import CoreGraphics
import AppKit

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
    @Published var ignoresMouseEvents: Bool = false
    @Published var isWindowVisible: Bool = true

    var isSleeping: Bool {
        assistantState == .hidden
    }

    private let backendBridge = BackendBridge()
    private var retreatTask: Task<Void, Never>?
    private var actionHistory: [String] = []
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
        
        // Prevent re-entry: reject if already working or just completed
        guard assistantState != .working && assistantState != .complete else {
            print("submitTextIntent: Rejected re-entry (state=\(assistantState))")
            return
        }

        retreatTask?.cancel()
        isPeeked = true
        isSubmittingText = true
        assistantState = .working

        Task { @MainActor [weak self] in
            guard let self else { return }
            
            self.actionHistory = []
            var turn = 0
            let maxTurns = 10
            var isFinished = false
            var consecutiveEnterCount = 0
            
            while turn < maxTurns && !isFinished {
                turn += 1
                
                do {
                    // Capture fresh screenshot and get next step (off main thread)
                    var turnPrompt = trimmed
                    if !self.actionHistory.isEmpty {
                        turnPrompt += "\n\nACTION HISTORY:\n" + self.actionHistory.joined(separator: "\n")
                    }
                    
                    let response = try await Task.detached {
                        try self.backendBridge.runPythonTemplate(input: turnPrompt)
                    }.value
                    
                    print("[Loop Turn \(turn)] Response: \(response)")
                    
                    if response.contains("COMMAND_HIDE_GHOSTY") {
                        self.retreatGhost()
                        isFinished = true
                        break
                    }
                    
                    // Parse and execute actions natively
                    let result = self.parseAndExecuteGUIAction(from: response)
                    
                    // Track consecutive ENTER-only turns to avoid infinite loops
                    let isEnterOnly = result.count == 1 && response.contains("'action': 'ENTER'")
                    if isEnterOnly {
                        consecutiveEnterCount += 1
                    } else {
                        consecutiveEnterCount = 0
                    }
                    
                    if consecutiveEnterCount >= 2 {
                        print("[Loop] 2 consecutive ENTER actions — assuming message sent, forcing completion.")
                        isFinished = true
                        self.assistantState = .complete
                        self.scheduleRetreat()
                        break
                    }
                    
                    if result.count > 0 {
                        self.appendOutput(from: "[Turn \(turn)] Executing \(result.count) action(s)...")
                    } else if !result.isCompleted {
                        // If no actions and not completed, maybe it's a chat response
                        self.appendOutput(from: response)
                    }
                    
                    if result.isCompleted {
                        print("[Loop] Task marked as completed by model.")
                        isFinished = true
                        self.assistantState = .complete
                        self.scheduleRetreat()
                    } else {
                        // Settle time for UI before next screenshot turn
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
                    }
                    
                } catch {
                    print("[Loop] turn \(turn) failed: \(error)")
                    isFinished = true
                    self.assistantState = .idle
                }
            }
            
            self.isSubmittingText = false
        }
    }

    /// Parses all JSON action blocks from the string and executes them in sequence natively
    private func parseAndExecuteGUIAction(from response: String) -> (count: Int, isCompleted: Bool) {
        print("Attempting to parse GUI actions from response: \(response)")
        
        let pattern = "\\{[^\\}]*['\"]action['\"]\\s*:\\s*.*?\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return (0, false)
        }
        
        let matches = regex.matches(in: response, options: [], range: NSRange(location: 0, length: response.utf16.count))
        
        var parsedActions: [[String: Any]] = []
        var isTaskCompleted = response.contains("TASK_STATUS: completed")
        
        // Extract and log thought if present
        if let thoughtRange = response.range(of: "THOUGHT: "),
           let newlineRange = response.range(of: "\n", range: thoughtRange.upperBound..<response.endIndex) {
            let thought = String(response[thoughtRange.upperBound..<newlineRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            print("[Ghosty Thought] \(thought)")
            if !thought.isEmpty {
                self.appendOutput(from: "Thought: \(thought)")
            }
        }
        
        for match in matches {
            guard let range = Range(match.range, in: response) else { continue }
            var jsonString = String(response[range])
            print("Found JSON candidate: \(jsonString)")
            
            // Sanitize common Pythonisms that break standard parsers
            jsonString = jsonString.replacingOccurrences(of: "None", with: "null")
            jsonString = jsonString.replacingOccurrences(of: "True", with: "true")
            jsonString = jsonString.replacingOccurrences(of: "False", with: "false")
            
            var parsedJSON: [String: Any]? = nil
            if let data = jsonString.data(using: .utf8) {
                if #available(macOS 12.0, *) {
                    parsedJSON = try? JSONSerialization.jsonObject(with: data, options: [.json5Allowed]) as? [String: Any]
                }
                if parsedJSON == nil {
                    // Fallback: forcefully replace single quotes if JSON5 failed or unavailable
                    let fallbackString = jsonString.replacingOccurrences(of: "'", with: "\"")
                    if let fallbackData = fallbackString.data(using: .utf8) {
                        parsedJSON = try? JSONSerialization.jsonObject(with: fallbackData, options: []) as? [String: Any]
                    }
                }
            }
            
            if let json = parsedJSON {
                if let status = json["task_status"] as? String, status == "completed" {
                    isTaskCompleted = true
                }
                if json["action"] is String {
                    parsedActions.append(json)
                }
            }
        }
        
        if parsedActions.isEmpty {
            return (0, isTaskCompleted)
        }
        
        // Execute the parsed actions sequentially with delays so the UI can react between actions
        Task { @MainActor in
            self.ignoresMouseEvents = true
            for dict in parsedActions {
                let actionType = dict["action"] as! String
                let value = dict["value"] as? String
                
                let position: CGPoint?
                if let posArray = dict["position"] as? [Double], posArray.count >= 2 {
                    position = CGPoint(x: posArray[0], y: posArray[1])
                } else {
                    position = nil
                }
                
                if let error = self.executeNativeAction(actionType: actionType, position: position, value: value) {
                    self.actionHistory.append("- Turn: \(error)")
                    print("DEBUG: \(error)")
                    continue // Skip this action but continue to next (e.g. INPUT after refused CLICK)
                }
                
                // Add to history
                let actionDesc = "\(actionType) at \(String(describing: position))" + (value != nil ? " with value '\(value!)'" : "")
                self.actionHistory.append("- Turn: \(actionDesc)")

                // Allow the OS UI to process the physical action before the next sequence
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s pause
            }
            self.ignoresMouseEvents = false
            if isTaskCompleted {
                self.assistantState = .complete
            }
        }
        
        return (parsedActions.count, isTaskCompleted)
    }

    private func executeNativeAction(actionType: String, position: CGPoint?, value: String?) -> String? {
        print("Executing Native Action: \(actionType) at \(String(describing: position)) with value: \(String(describing: value))")
        
        // Safety Guard: Check if coordinates fall in the Ghosty Zone (Top Center)
        let isInGhostyZone: Bool = {
            guard let pos = position else { return false }
            return pos.x >= 0.3 && pos.x <= 0.7 && pos.y >= 0.0 && pos.y <= 0.4
        }()
        
        // Normalise action types to handle vision model variations
        let normalizedAction = actionType.uppercased()
        
        // For CLICK actions in the Ghosty Zone, refuse entirely
        if isInGhostyZone && normalizedAction == "CLICK" {
            return "Action refused: You tried to CLICK the Ghosty panel at \(position!). Please click the background application instead."
        }
        
        // For INPUT actions in the Ghosty Zone, skip the click but still type the text
        // The cursor should already be in the correct field from a previous successful CLICK
        if isInGhostyZone && normalizedAction == "INPUT" {
            print("WARNING: INPUT position \(position!) is in Ghosty Zone. Skipping click, typing at current cursor position.")
            if let text = value {
                self.performType(text: text)
            }
            return nil // Not an error - we successfully typed
        }

        // ShowUI returns normalized coordinates [0.0 - 1.0] for the main screen. 
        // We need to convert these to absolute screen coordinates.
        guard let screen = NSScreen.main else { return "No screen found" }
        let screenRect = screen.frame
        
        var targetPoint: CGPoint? = nil
        if let pos = position {
            let x = screenRect.origin.x + (pos.x * screenRect.width)
            let y = screenRect.origin.y + (pos.y * screenRect.height)
            targetPoint = CGPoint(x: x, y: y)
        }

        switch normalizedAction {
        case "CLICK":
            if let targetPoint = targetPoint {
                performClick(at: targetPoint)
            }
        case "INPUT":
            if let targetPoint = targetPoint {
                performClick(at: targetPoint)
                usleep(100_000) // 0.1s wait for focus
                if let text = value {
                    self.performType(text: text)
                }
            } else {
                if let text = value {
                    self.performType(text: text)
                }
            }
        case "ENTER":
            performEnterKey()
        default:
            print("Unhandled GUI Action Type: \(actionType)")
            return "Unhandled GUI Action Type: \(actionType)"
        }
        
        return nil
    }

    private func performClick(at point: CGPoint) {
        let eventDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let eventUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        
        // First click to unfocus Ghosty and focus the target application
        eventDown?.post(tap: .cghidEventTap)
        usleep(50_000) // 50ms delay between down and up
        eventUp?.post(tap: .cghidEventTap)
        
        // Small delay to allow macOS to switch window focus
        usleep(100_000) // 100ms
        
        // Second click to actually interact with the target UI element
        eventDown?.post(tap: .cghidEventTap)
        usleep(50_000)
        eventUp?.post(tap: .cghidEventTap)
    }

    private func performType(text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        // Basic implementation: send string via CGEvent
        // Note: Special characters or full unicode might require CGEventKeyboardSetUnicodeString
        for char in text.utf16 {
            var keyCode = char
            let eventDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let eventUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            
            eventDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &keyCode)
            eventUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &keyCode)
            
            eventDown?.post(tap: .cghidEventTap)
            eventUp?.post(tap: .cghidEventTap)
            usleep(10_000)
        }
    }

    private func performEnterKey() {
        let source = CGEventSource(stateID: .hidSystemState)
        let enterKeyCode: CGKeyCode = 36 // Return key
        let eventDown = CGEvent(keyboardEventSource: source, virtualKey: enterKeyCode, keyDown: true)
        let eventUp = CGEvent(keyboardEventSource: source, virtualKey: enterKeyCode, keyDown: false)
        eventDown?.post(tap: .cghidEventTap)
        eventUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Streaming Chat (used by no_backend / conversational mode)

    func submitStreamingIntent(_ intent: String) {
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
