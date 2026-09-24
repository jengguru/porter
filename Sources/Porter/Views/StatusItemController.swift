import AppKit
import Combine
import PorterCore

/// The menu bar item. Click (or right-click) opens the menu; ⌥-click switches straight
/// to the other favorite without opening it.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let openSettings: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    init(model: AppModel, openSettings: @escaping () -> Void) {
        self.model = model
        self.openSettings = openSettings
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imageScaling = .scaleProportionallyDown
        }

        // objectWillChange fires before the new value lands, so update on the next run loop pass.
        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateButton() }
            .store(in: &cancellables)
        updateButton()
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let current = model.currentDefault
        button.image = model.icons.menuBarImage(for: current, style: model.preferences.iconStyle)

        let description = current.map { String(localized: "Default browser: \($0.name)") }
            ?? String(localized: "Default browser unknown")
        button.toolTip = description + "\n" + String(localized: "⌥-click to switch favorites")
        button.setAccessibilityLabel("Porter — " + description)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent, event.type == .leftMouseUp, event.modifierFlags.contains(.option) {
            model.toggle()
            return
        }
        statusItem.menu = menu
        sender.performClick(nil) // runs the menu; returns once it closes
        statusItem.menu = nil
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        model.refreshAll()
        menu.removeAllItems()

        let current = model.currentDefault
        let browsers = model.menuBrowsers
        for browser in browsers {
            let item = NSMenuItem(title: browser.name, action: #selector(selectBrowser(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = browser.bundleID
            item.image = model.icons.icon(for: browser, size: 16)
            item.state = BundleID.same(browser.bundleID, current?.bundleID) ? .on : .off
            item.isEnabled = !model.isSwitching
            menu.addItem(item)
        }
        if browsers.isEmpty {
            menu.addItem(disabledItem(String(localized: "No browsers found")))
        }
        if current == nil {
            menu.addItem(disabledItem(String(localized: "Default browser unknown")))
        }

        menu.addItem(.separator())
        menu.addItem(switchItem())
        if model.preferences.hotkeyEnabled, model.hotkeyProblem != nil {
            menu.addItem(disabledItem(String(localized: "Shortcut \(model.preferences.hotkey.displayString) is taken — change it in Settings")))
        }
        menu.addItem(.separator())

        let settings = NSMenuItem(title: String(localized: "Settings…"), action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: String(localized: "Quit Porter"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func switchItem() -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(toggleFavorites), keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: nil)

        switch model.switchPlan {
        case let .switchTo(bundleID):
            item.title = String(localized: "Switch to \(model.displayName(for: bundleID))")
            item.isEnabled = !model.isSwitching
        case .unavailable(.favoritesNotSet):
            item.title = String(localized: "Switch: choose two favorites in Settings")
            item.isEnabled = false
        case .unavailable(.favoritesIdentical):
            item.title = String(localized: "Switch: favorites A and B are the same")
            item.isEnabled = false
        case let .unavailable(.notInstalled(bundleID)):
            item.title = String(localized: "Switch: \(model.displayName(for: bundleID)) is not installed")
            item.isEnabled = false
        }

        let hotkey = model.preferences.hotkey
        if model.preferences.hotkeyEnabled, model.hotkeyProblem == nil, let key = hotkey.menuKeyEquivalent {
            item.keyEquivalent = key
            item.keyEquivalentModifierMask = Self.eventModifiers(hotkey.modifiers)
        }
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private static func eventModifiers(_ modifiers: Hotkey.Modifiers) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        return flags
    }

    // MARK: - Actions

    @objc private func selectBrowser(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        model.switchTo(bundleID)
    }

    @objc private func toggleFavorites() {
        model.toggle()
    }

    @objc private func showSettings() {
        openSettings()
    }
}
