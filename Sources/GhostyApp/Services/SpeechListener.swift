import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechListener: NSObject {
    private enum Constants {
        static let silenceTimeout: TimeInterval = 1.0
    }

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private let onCommand: (String) -> Void

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isAcceptingCommands = false
    private var lastTranscript = ""

    /// Commands that should be dispatched exactly as spoken instead of full dictation.
    var wakeCommands: Set<String> = []

    init(onCommand: @escaping (String) -> Void) {
        self.onCommand = onCommand
        super.init()
    }

    func startListening() {
        isAcceptingCommands = true
        guard recognitionTask == nil else { return }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self, self.isAcceptingCommands else { return }
                guard status == .authorized else {
                    print("SpeechListener: speech recognition not authorised (\(status.rawValue))")
                    return
                }

                do {
                    try self.startRecognitionSession()
                } catch {
                    print("SpeechListener: failed to start recognition session - \(error)")
                    self.stopRecognitionSession()
                }
            }
        }
    }

    func stopListening() {
        isAcceptingCommands = false
        stopRecognitionSession()
    }

    private func startRecognitionSession() throws {
        guard recognitionTask == nil else { return }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
        recognitionRequest = request
        lastTranscript = ""

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.isAcceptingCommands else { return }
                if let result {
                    self.handleRecognitionResult(result)
                }
                if error != nil {
                    self.dispatchTranscriptionIfNeeded()
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let transcript = result.bestTranscription.formattedString
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }

        lastTranscript = transcript
        resetSilenceTimer()

        if result.isFinal {
            dispatchTranscriptionIfNeeded()
        }
    }

    private func resetSilenceTimer() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(handleSilenceTimeout), object: nil)
        perform(#selector(handleSilenceTimeout), with: nil, afterDelay: Constants.silenceTimeout)
    }

    private func dispatchTranscriptionIfNeeded() {
        let transcript = lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAcceptingCommands, !transcript.isEmpty else { return }

        lastTranscript = ""
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(handleSilenceTimeout), object: nil)
        stopRecognitionSession()

        let normalized = transcript.lowercased()
        if wakeCommands.contains(normalized) {
            onCommand(normalized)
        } else {
            onCommand(transcript)
        }
    }

    private func stopRecognitionSession() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(handleSilenceTimeout), object: nil)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
    }

    @objc
    private func handleSilenceTimeout() {
        dispatchTranscriptionIfNeeded()
    }
}
