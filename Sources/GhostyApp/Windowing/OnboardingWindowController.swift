import AppKit
import SwiftUI

/// Manages the first-run onboarding window.
/// Closing the window without finishing onboarding quits the app so the user
/// can't end up with a ghost that is partially configured and unreachable.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
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
        win.delegate = self
        win.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }

    // MARK: – NSWindowDelegate

    /// If the user closes the onboarding window before finishing, quit the app.
    /// This prevents a zombie state where the ghost is unreachable.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(nil)
        return false
    }

    // MARK: – Private

    private func dismiss() {
        window?.delegate = nil
        window?.close()
        window = nil
        onComplete?()
    }
}
