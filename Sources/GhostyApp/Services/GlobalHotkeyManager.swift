import AppKit
import HotKey

final class GlobalHotkeyManager {
    private let hotKey: HotKey

    init(keyDownHandler: @escaping () -> Void) {
        hotKey = HotKey(key: .g, modifiers: [.command, .shift])
        hotKey.keyDownHandler = keyDownHandler
    }
}
