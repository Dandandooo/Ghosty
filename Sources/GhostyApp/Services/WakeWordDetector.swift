import Speech
import AVFoundation

/// Always-on wake-word detector for "hey ghosty".
///
/// Uses `SFSpeechRecognizer` with on-device recognition (no network, private).
/// Audio is captured once via `AVAudioEngine` and fed into a rolling series of
/// 5-second recognition windows. Partial results are scanned for the wake phrase,
/// so detection fires within ~1 second of the user finishing the phrase.
///
/// Resource profile: ~1–3 % CPU on Apple Silicon at idle speech.
final class WakeWordDetector: NSObject, @unchecked Sendable {

    // Substrings to match in the lowercased transcript.
    // "ghost" catches ghost / ghosty / ghostie; the "hey" variants add precision.
    private static let matchTokens: [String] = ["hey ghost", "ghosty", "hey go"]

    // Minimum gap between consecutive triggers (avoids double-firing in one window).
    private static let triggerCooldown: TimeInterval = 2

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Rolling window keeps memory bounded: a new recognition task is started every N seconds.
    private let windowDuration: TimeInterval = 5
    private var windowTimer: Timer?

    private var lastTrigger: Date = .distantPast
    private let onWakeWord: @Sendable () -> Void
    private(set) var isRunning = false

    init(onWakeWord: @escaping @Sendable () -> Void) {
        self.onWakeWord = onWakeWord
        super.init()
    }

    deinit { stopEngine() }

    // MARK: - Public API

    func start() {
        guard !isRunning else { return }
        isRunning = true

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                guard status == .authorized else {
                    print("WakeWordDetector: speech recognition not authorised (\(status.rawValue))")
                    return
                }
                do {
                    try self.startAudioEngine()
                    self.startRecognitionWindow()
                    self.scheduleWindowReset()
                } catch {
                    print("WakeWordDetector: failed to start – \(error)")
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopEngine()
    }

    // MARK: - Audio engine (started once, lives for the detector's lifetime)

    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopEngine() {
        windowTimer?.invalidate()
        windowTimer = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
    }

    // MARK: - Recognition windows

    /// Opens a fresh recognition task. Called at startup and by the rolling timer.
    private func startRecognitionWindow() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // On-device: no data leaves the device, lower latency, works offline.
        request.requiresOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
        recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, self.isRunning, let result else { return }
            let text = result.bestTranscription.formattedString.lowercased()
            if Self.matchTokens.contains(where: { text.contains($0) }) {
                let now = Date()
                guard now.timeIntervalSince(self.lastTrigger) > Self.triggerCooldown else { return }
                self.lastTrigger = now
                let cb = self.onWakeWord
                Task { @MainActor in cb() }
            }
        }
    }

    private func scheduleWindowReset() {
        windowTimer = Timer.scheduledTimer(withTimeInterval: windowDuration, repeats: true) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.startRecognitionWindow()
        }
    }
}
