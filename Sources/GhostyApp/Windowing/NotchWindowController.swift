import AppKit
import SwiftUI

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchWindowController {
    private let panel: NSPanel
    private let compactPanelSize = NSSize(width: 204, height: 140)
    private let expandedPanelSize = NSSize(width: 284, height: 474)
    private let peekOffset: CGFloat = 44
    private var panelSize: NSSize
    private var isPeeked = false

    init<Content: View>(rootView: Content) {
        panelSize = compactPanelSize

        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.tabbingMode = .disallowed
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false

        panel.contentView = NSHostingView(rootView: rootView)
        updatePosition(peeked: false, animated: false)
    }

    func showWindow() {
        panel.makeKeyAndOrderFront(nil)
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderOut(nil)
        }
    }

    func setPeeked(_ isPeeked: Bool, animated: Bool) {
        self.isPeeked = isPeeked
        updatePosition(peeked: isPeeked, animated: animated)
    }

    func setTextInputVisible(_ visible: Bool, animated: Bool) {
        panelSize = visible ? expandedPanelSize : compactPanelSize
        updatePosition(peeked: isPeeked, animated: animated)
    }

    func setIgnoresMouseEvents(_ ignores: Bool) {
        panel.ignoresMouseEvents = ignores
    }

    private func updatePosition(peeked: Bool, animated: Bool) {
        guard let screen = NSScreen.main else { return }

        let visibleFrame = screen.frame
        let x = visibleFrame.midX - panelSize.width / 2
        let topY = visibleFrame.maxY - panelSize.height + 10
        let y = peeked ? topY - peekOffset : topY
        let targetFrame = NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }
    }
}
