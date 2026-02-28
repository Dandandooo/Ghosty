import AppKit

final class SpeechListener: NSObject {
    private var recognizer: NSSpeechRecognizer?
    private let onCommand: (String) -> Void
    private var isAcceptingCommands = false
    private var hasStartedRecognizer = false

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
                "ghost stop"
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
        guard isAcceptingCommands else { return }
        onCommand(command)
    }
}
