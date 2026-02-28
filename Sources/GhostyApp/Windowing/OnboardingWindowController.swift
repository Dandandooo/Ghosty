import AppKit
import SwiftUI

/// Manages the first-run onboarding window.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    var onComplete: (() -> Void)?

    func showWindow() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let onboardingView = OnboardingView(onComplete: { [weak self] in
            self?.dismiss()
        })

        let hostingController = NSHostingController(rootView: onboardingView)

        let win = NSWindow(contentViewController: hostingController)
        win.title = "Welcome to Ghosty"
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.setContentSize(NSSize(width: 520, height: 440))
        win.minSize = NSSize(width: 480, height: 400)
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }

    private func dismiss() {
        window?.close()
        window = nil
        onComplete?()
    }
}
