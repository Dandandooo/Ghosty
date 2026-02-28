import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let contextMenu = NSMenu()
    private let voiceMenuItem = NSMenuItem(title: "Enable Voice", action: #selector(handleVoiceToggle), keyEquivalent: "")
    private let heyGhostyMenuItem = NSMenuItem(title: "Hey Ghosty", action: #selector(handleHeyGhostyToggle), keyEquivalent: "")
    private let skillsMenuItem = NSMenuItem(title: "Skills", action: #selector(handleSkills), keyEquivalent: "")
    private let mcpMenuItem = NSMenuItem(title: "MCP", action: #selector(handleMCP), keyEquivalent: "")
    private let quitMenuItem = NSMenuItem(title: "Quit Ghosty", action: #selector(handleQuit), keyEquivalent: "q")
    private var sleeping = true
    private var voiceEnabled = false
    private var heyGhostyEnabled = false
    private var ghostHollowImage: NSImage?
    private var ghostFilledImage: NSImage?

    var onToggleGhost: (() -> Void)?
    var onRetreatGhost: (() -> Void)?
    var onVoiceEnabledChanged: ((Bool) -> Void)?
    var onHeyGhostyEnabledChanged: ((Bool) -> Void)?
    var onQuit: (() -> Void)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusButton()
        configureContextMenu()
        configurePopover()
        loadGhostIconsIfNeeded()
        setSleeping(true)
    }

    func setVoiceEnabled(_ enabled: Bool) {
        voiceEnabled = enabled
        voiceMenuItem.state = enabled ? .on : .off
        // Hey Ghosty only makes sense in voice mode
        heyGhostyMenuItem.isEnabled = enabled
    }

    func setHeyGhostyEnabled(_ enabled: Bool) {
        heyGhostyEnabled = enabled
        heyGhostyMenuItem.state = enabled ? .on : .off
    }

    func setSleeping(_ isSleeping: Bool) {
        sleeping = isSleeping
        updateIcon(isSleeping: isSleeping)

        if isSleeping {
            popover.performClose(nil)
        }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Ghost in the Machine"
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
        updateIcon(isSleeping: sleeping)
    }

    private func configureContextMenu() {
        voiceMenuItem.target = self
        voiceMenuItem.state = .on

        heyGhostyMenuItem.target = self
        heyGhostyMenuItem.state = .off
        heyGhostyMenuItem.isEnabled = voiceEnabled
        heyGhostyMenuItem.indentationLevel = 1

        skillsMenuItem.target = self
        mcpMenuItem.target = self

        quitMenuItem.target = self

        contextMenu.addItem(voiceMenuItem)
        contextMenu.addItem(heyGhostyMenuItem)
        contextMenu.addItem(skillsMenuItem)
        contextMenu.addItem(mcpMenuItem)
        contextMenu.addItem(.separator())
        contextMenu.addItem(quitMenuItem)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 240, height: 140)

        let content = MenuBarPopoverView(
            onToggleGhost: { [weak self] in
                self?.onToggleGhost?()
            },
            onRetreatGhost: { [weak self] in
                self?.onRetreatGhost?()
            }
        )

        popover.contentViewController = NSHostingController(rootView: content)
    }

    private func updateIcon(isSleeping: Bool) {
        guard let button = statusItem.button else { return }
        let image = isSleeping ? ghostHollowImage : ghostFilledImage

        if let image {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = "👻"
        }
    }

    @objc
    private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        onToggleGhost?()
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func handleVoiceToggle() {
        let enabled = voiceMenuItem.state != .on
        setVoiceEnabled(enabled)
        onVoiceEnabledChanged?(enabled)
    }

    @objc
    private func handleHeyGhostyToggle() {
        let enabled = heyGhostyMenuItem.state != .on
        setHeyGhostyEnabled(enabled)
        onHeyGhostyEnabledChanged?(enabled)
    }

    @objc
    private func handleSkills() {}

    @objc
    private func handleMCP() {}

    @objc
    private func handleQuit() {
        onQuit?()
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        popover.performClose(nil)

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(contextMenu, with: event, for: button)
        }
    }

    private func loadGhostIconsIfNeeded() {
        if let cached = Self.cachedGhostIcons {
            ghostHollowImage = cached.hollow
            ghostFilledImage = cached.filled
            updateIcon(isSleeping: sleeping)
            return
        }

        let hollow = Self.loadSVGImage(named: "ghost-hollow")
        let filled = Self.loadSVGImage(named: "ghost-filled")

        if let hollow, let filled {
            Self.cachedGhostIcons = (hollow, filled)
        }

        ghostHollowImage = hollow
        ghostFilledImage = filled
        updateIcon(isSleeping: sleeping)
    }

    private static var cachedGhostIcons: (hollow: NSImage, filled: NSImage)?

    private static func loadSVGImage(named name: String) -> NSImage? {
        let url =
            Bundle.module.url(forResource: name, withExtension: "svg") ??
            Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "MenuBar")

        guard
            let url,
            let imageRep = NSImageRep(contentsOf: url)
        else {
            return nil
        }

        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.addRepresentation(imageRep)
        image.isTemplate = true
        return image
    }
}
