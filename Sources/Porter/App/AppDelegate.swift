import AppKit
import Combine
import PorterCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// There is no notification for default-browser changes, so check this often.
    private static let pollInterval: TimeInterval = 5

    private var model: AppModel!
    private var statusItem: StatusItemController!
    private let settings = SettingsWindowController()
    private let hotkeys = HotkeyService()
    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.makeMainMenu()

        model = AppModel(preferences: Preferences())
        model.refreshAll()

        statusItem = StatusItemController(model: model) { [weak self] in self?.showSettings() }

        hotkeys.onTrigger = { [weak self] in self?.model.toggle() }
        Publishers.CombineLatest3(model.preferences.$hotkeyEnabled, model.preferences.$hotkey, model.$isRecordingShortcut)
            .sink { [weak self] enabled, hotkey, recording in
                self?.updateHotkey(enabled: enabled, hotkey: hotkey, paused: recording)
            }
            .store(in: &cancellables)

        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.model.refreshDefault() }
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    /// Launching Porter again (Finder, Spotlight) opens Settings, since there's no Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    private func showSettings() {
        settings.show(model: model)
    }

    private func updateHotkey(enabled: Bool, hotkey: Hotkey, paused: Bool) {
        hotkeys.unregister()
        guard enabled, !paused else {
            model.hotkeyProblem = nil
            return
        }
        // Never claim a combination macOS or a common app already uses.
        if let problem = model.problem(for: hotkey) {
            model.hotkeyProblem = problem
            return
        }
        model.hotkeyProblem = hotkeys.register(hotkey) ? nil : .inUseByAnotherApp
    }

    /// A minimal main menu so ⌘W / ⌘Q / ⌘C work while the Settings window is focused.
    private static func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "Quit Porter"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: String(localized: "Edit"))
        editMenu.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: String(localized: "Window"))
        windowMenu.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        return mainMenu
    }
}
