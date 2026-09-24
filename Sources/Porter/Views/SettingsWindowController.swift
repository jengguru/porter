import AppKit
import SwiftUI

/// Hosts the SwiftUI settings in a plain window. (The SwiftUI `Settings` scene can't be
/// opened reliably from an `NSMenu` in a menu-bar-only app across macOS 13–15.)
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(model: AppModel) {
        model.refreshAll()

        if window == nil {
            let root = SettingsView()
                .environmentObject(model)
                .environmentObject(model.preferences)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = String(localized: "Porter Settings")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
