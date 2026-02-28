import SwiftUI

@main
struct GhostyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Cmd+, is intercepted by AppDelegate to show SettingsWindowController.
        // This empty Settings scene satisfies SwiftUI's requirement for at least
        // one scene but never produces a visible window on its own.
        Settings { EmptyView() }
    }
}
