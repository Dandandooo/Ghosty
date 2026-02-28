import AppKit

final class SpeechListener: NSObject {
    private var recognizer: NSSpeechRecognizer?
    private let onCommand: (String) -> Void
    private var isAcceptingCommands = false
    private var hasStartedRecognizer = false
    /// Commands that are dispatched even when the listener is paused (e.g. wake commands).
    var wakeCommands: Set<String> = []

    init(onCommand: @escaping (String) -> Void) {
        self.onCommand = onCommand
        super.init()
    }

    func startListening() {
        isAcceptingCommands = true

        if recognizer == nil {
            let recognizer = NSSpeechRecognizer()
            recognizer?.commands = [
                "ghost",
                "ghost status",
                "ghost start",
                "ghost stop",
                "hey ghost",
                "hey ghosty",
                "bye ghost",
                "bye ghosty"
            ]
            recognizer?.delegate = self
            recognizer?.listensInForegroundOnly = false
            self.recognizer = recognizer
        }

        if !hasStartedRecognizer {
            recognizer?.startListening()
            hasStartedRecognizer = true
        }
    }

    func stopListening() {
        isAcceptingCommands = false
    }
}

extension SpeechListener: NSSpeechRecognizerDelegate {
    func speechRecognizer(_ sender: NSSpeechRecognizer, didRecognizeCommand command: String) {
        if wakeCommands.contains(command) {
            onCommand(command)
            return
        }
        guard isAcceptingCommands else { return }
        onCommand(command)
    }
}
