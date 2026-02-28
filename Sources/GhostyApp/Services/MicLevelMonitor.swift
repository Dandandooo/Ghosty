import AVFoundation

/// Taps the default microphone and emits a smoothed RMS level (0 – 1) via callback.
/// Designed to run while the ghost is visible in voice mode.
final class MicLevelMonitor: @unchecked Sendable {
    private let audioEngine = AVAudioEngine()
    private var isRunning = false

    /// Gain applied to raw RMS before clamping. Tune to taste:
    /// typical conversational voice RMS is ~0.02–0.08; gain of 10 maps that to 0.2–0.8.
    private let gain: Float = 10.0
    private var smoothed: Float = 0.0

    var onLevel: ((Float) -> Void)?

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let rms = Self.rms(buffer: buffer)
            let boosted = min(rms * self.gain, 1.0)
            // Fast attack, slow release – feels natural for voice
            let coeff: Float = boosted > self.smoothed ? 0.4 : 0.12
            self.smoothed = self.smoothed * (1 - coeff) + boosted * coeff
            let level = self.smoothed
            DispatchQueue.main.async { self.onLevel?(level) }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("MicLevelMonitor: failed to start audio engine – \(error)")
            inputNode.removeTap(onBus: 0)
            isRunning = false
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        smoothed = 0
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        onLevel?(0)
    }

    private static func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }
        let channel = data[0]
        var sum: Float = 0
        for i in 0..<frameCount {
            let s = channel[i]
            sum += s * s
        }
        return sqrt(sum / Float(frameCount))
    }
}
