import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let contextMenu = NSMenu()
    private let settingsMenuItem = NSMenuItem(title: "Settings…", action: #selector(handleSettings), keyEquivalent: ",")
    private let quitMenuItem = NSMenuItem(title: "Quit Ghosty", action: #selector(handleQuit), keyEquivalent: "q")
    private var sleeping = true
    private var ghostHollowImage: NSImage?
    private var ghostFilledImage: NSImage?

    var onToggleGhost: (() -> Void)?
    var onRetreatGhost: (() -> Void)?
    var onSettings: (() -> Void)?
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

    func setVoiceEnabled(_ enabled: Bool) {}
    func setHeyGhostyEnabled(_ enabled: Bool) {}

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
        settingsMenuItem.target = self

        quitMenuItem.target = self

        contextMenu.addItem(settingsMenuItem)
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
    private func handleSettings() {
        onSettings?()
    }

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
