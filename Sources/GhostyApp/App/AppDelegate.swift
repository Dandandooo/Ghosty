import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = GhostAssistantModel()
    private var voiceEnabled = false
    private var heyGhostyEnabled = false
    private var notchWindowController: NotchWindowController?
    private var menuBarController: MenuBarController?
    private var hotkeyManager: GlobalHotkeyManager?
    private var speechListener: SpeechListener?
    private var wakeWordDetector: WakeWordDetector?
    private var micLevelMonitor: MicLevelMonitor?
    private var escapeMonitor: Any?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        model.isVoiceEnabled = voiceEnabled

        let panelView = NotchPanelView(model: model)
        let controller = NotchWindowController(rootView: panelView)
        notchWindowController = controller
        menuBarController = MenuBarController()

        bindModelToWindow()
        configureHotkey()
        configureEscapeKey()
        configureSpeechListener()
        configureMenuBar()
        syncWakeWordDetector()
        model.startStateMonitor()

        NSApp.setActivationPolicy(.accessory)
        controller.setVisible(false)
    }

    private func bindModelToWindow() {
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                guard let self, self.model.isPeeked else { return }
                
                // Don't retreat if we are currently working on a command!
                // This prevents the ghost from disappearing when a GUI action causes the app to lose focus.
                if self.model.assistantState == .working {
                    print("AppDelegate: App resigned active but Assistant is WORKING, skipping retreat.")
                    return
                }
                
                self.model.retreatGhost()
            }
            .store(in: &subscriptions)

        model.$isPeeked
            .removeDuplicates()
            .sink { [weak self] isPeeked in
                self?.notchWindowController?.setPeeked(isPeeked, animated: true)
            }
            .store(in: &subscriptions)

        model.$isVoiceEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.notchWindowController?.setTextInputVisible(!enabled, animated: true)
            }
            .store(in: &subscriptions)

        Publishers.CombineLatest(model.$isPeeked, model.$isVoiceEnabled)
            .map { isPeeked, isVoice in isPeeked && isVoice }
            .removeDuplicates()
            .sink { [weak self] shouldMonitor in
                guard let self else { return }
                if shouldMonitor {
                    let monitor = MicLevelMonitor()
                    monitor.onLevel = { [weak self] level in
                        self?.model.micLevel = level
                    }
                    monitor.start()
                    self.micLevelMonitor = monitor
                } else {
                    self.micLevelMonitor?.stop()
                    self.micLevelMonitor = nil
                    self.model.micLevel = 0
                }
            }
            .store(in: &subscriptions)

        model.$assistantState
            .sink { [weak self] state in
                let sleeping = state == .hidden
                self?.menuBarController?.setSleeping(sleeping)
                self?.notchWindowController?.setVisible(!sleeping)

                guard state == .complete else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self?.model.retreatGhost()
                }
            }
            .store(in: &subscriptions)

        // Stop the wake-word detector while the ghost is visible (its AVAudioEngine
        // conflicts with the active SpeechListener), and restart it once the ghost
        // retreats to sleep so it can wake the ghost again next time.
        model.$ignoresMouseEvents
            .removeDuplicates()
            .sink { [weak self] ignores in
                self?.notchWindowController?.setIgnoresMouseEvents(ignores)
            }
            .store(in: &subscriptions)

        model.$isWindowVisible
            .removeDuplicates()
            .sink { [weak self] isVisible in
                self?.notchWindowController?.setVisible(isVisible)
            }
            .store(in: &subscriptions)

        model.isVoiceEnabled = voiceEnabled
    }

    private func configureHotkey() {
        hotkeyManager = GlobalHotkeyManager(keyDownHandler: { [weak self] in
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
                self?.model.togglePeekAndListenMode()
            }
        })
    }

    private func configureEscapeKey() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.keyCode == 53, self.model.isPeeked else { return event }

            self.model.retreatGhost()
            return nil
        }
    }

    private func configureSpeechListener() {
        model.$assistantState
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self else { return }

                if state == .listening, self.voiceEnabled {
                    if self.speechListener == nil {
                        let listener = SpeechListener(onCommand: { [weak self] phrase in
                            Task { @MainActor in
                                guard let self else { return }
                                switch phrase {
                                case "ghost", "ghost start", "hey ghost", "hey ghosty":
                                    NSApp.activate(ignoringOtherApps: true)
                                    self.model.togglePeekAndListenMode()
                                case "ghost stop", "bye ghost", "bye ghosty":
                                    self.model.retreatGhost()
                                case "ghost status":
                                    self.model.showMessage("It's looking good, brev")
                                default:
                                    self.model.submitIntent(phrase)
                                }
                            }
                        })
                        listener.wakeCommands = ["ghost", "ghost start", "hey ghost", "hey ghosty"]
                        self.speechListener = listener
                    }
                    self.speechListener?.startListening()
                } else {
                    self.speechListener?.stopListening()
                }
            }
            .store(in: &subscriptions)
    }

    private func configureMenuBar() {
        menuBarController?.onToggleGhost = { [weak self] in
            Task { @MainActor in
                self?.model.togglePeekAndListenMode()
            }
        }

        menuBarController?.onRetreatGhost = { [weak self] in
            Task { @MainActor in
                self?.model.retreatGhost()
            }
        }

        menuBarController?.onVoiceEnabledChanged = { [weak self] enabled in
            Task { @MainActor in
                self?.setVoiceEnabled(enabled)
            }
        }

        menuBarController?.onHeyGhostyEnabledChanged = { [weak self] enabled in
            Task { @MainActor in
                self?.setHeyGhostyEnabled(enabled)
            }
        }

        menuBarController?.onQuit = {
            NSApp.terminate(nil)
        }

        menuBarController?.setVoiceEnabled(voiceEnabled)
        menuBarController?.setHeyGhostyEnabled(heyGhostyEnabled)
        menuBarController?.setSleeping(model.isSleeping)
    }

    /// Starts or stops the WakeWordDetector based on the current state.
    /// The detector must only run when voice mode and hey-ghosty are both enabled
    /// *and* the ghost is not currently visible — running it while the ghost is
    /// shown would conflict with the active SpeechListener's audio session.
    private func syncWakeWordDetector() {
        let shouldRun = voiceEnabled && heyGhostyEnabled && model.isSleeping
        if shouldRun, wakeWordDetector == nil {
            startWakeWordDetector()
        } else if !shouldRun, wakeWordDetector != nil {
            wakeWordDetector?.stop()
            wakeWordDetector = nil
        }
    }

    private func startWakeWordDetector() {
        let detector = WakeWordDetector { [weak self] in
            Task { @MainActor in
                guard let self, self.model.isSleeping else { return }
                NSApp.activate(ignoringOtherApps: true)
                self.model.togglePeekAndListenMode()
            }
        }
        detector.start()
        wakeWordDetector = detector
        print("WakeWordDetector: listening for 'hey ghosty'")
    }

    private func setVoiceEnabled(_ enabled: Bool) {
        voiceEnabled = enabled
        model.isVoiceEnabled = enabled

        if !enabled {
            // Stop the wake word detector — it only runs in voice mode
            wakeWordDetector?.stop()
            wakeWordDetector = nil
            speechListener?.stopListening()
            if model.isPeeked, model.assistantState == .listening {
                model.assistantState = .idle
            }
            return
        }

        if model.isPeeked, model.assistantState == .idle {
            model.assistantState = .listening
        }

        syncWakeWordDetector()

        if model.assistantState == .listening {
            if speechListener == nil {
                speechListener = SpeechListener(onCommand: { [weak self] phrase in
                    Task { @MainActor in
                        self?.model.submitIntent(phrase)
                    }
                })
            }
            speechListener?.startListening()
        }
    }

    private func setHeyGhostyEnabled(_ enabled: Bool) {
        heyGhostyEnabled = enabled
        syncWakeWordDetector()
    }
}
