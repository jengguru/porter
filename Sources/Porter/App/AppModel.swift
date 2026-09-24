import AppKit
import Combine
import os
import PorterCore

/// App state shared by the menu bar item, the settings window and the hotkey.
@MainActor
final class AppModel: ObservableObject {
    let preferences: Preferences
    let icons = IconProvider()

    /// Every installed browser, sorted by name.
    @Published private(set) var installed: [Browser] = []
    /// What macOS actually has set right now (not what Porter last asked for).
    @Published private(set) var currentDefault: Browser?
    @Published private(set) var isSwitching = false
    @Published var isRecordingShortcut = false
    /// Why the global shortcut isn't active, if it isn't.
    @Published var hotkeyProblem: HotkeyProblem?

    private let workspace: WorkspaceProviding
    private let discovery: BrowserDiscovery
    private let service: DefaultBrowserService
    private let autoConfirm = DialogAutoConfirm()
    private let logger = Logger(subsystem: "Porter", category: "AppModel")
    private var cancellables = Set<AnyCancellable>()

    init(preferences: Preferences, workspace: WorkspaceProviding = SystemWorkspace()) {
        self.preferences = preferences
        self.workspace = workspace
        discovery = BrowserDiscovery(workspace: workspace)
        service = DefaultBrowserService(workspace: workspace)

        // Views that read preferences through the model redraw when they change.
        preferences.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Derived state

    func browser(for bundleID: String?) -> Browser? {
        guard let bundleID else { return nil }
        return installed.first { BundleID.same($0.bundleID, bundleID) }
    }

    func isInstalled(_ bundleID: String) -> Bool {
        browser(for: bundleID) != nil
    }

    func displayName(for bundleID: String) -> String {
        browser(for: bundleID)?.name ?? KnownBrowsers.displayName(for: bundleID)
    }

    var switchPlan: SwitchPlan {
        let installedIDs = Set(installed.map(\.id))
        return SwitchResolver.plan(
            currentDefault: currentDefault?.bundleID,
            favoriteA: preferences.favoriteA,
            favoriteB: preferences.favoriteB,
            isInstalled: { installedIDs.contains(BundleID.normalize($0)) }
        )
    }

    /// Installed browsers in the user's order (Settings list).
    var orderedBrowsers: [Browser] {
        MenuListBuilder.ordered(installed, savedOrder: preferences.menuOrder)
    }

    /// Browsers to list in the menu.
    var menuBrowsers: [Browser] {
        MenuListBuilder.menuItems(
            installed: installed,
            savedOrder: preferences.menuOrder,
            hidden: preferences.hiddenInMenu,
            currentDefault: currentDefault?.bundleID
        )
    }

    func isShownInMenu(_ browser: Browser) -> Bool {
        !preferences.hiddenInMenu.contains(browser.id)
    }

    func setShownInMenu(_ browser: Browser, _ shown: Bool) {
        if shown {
            preferences.hiddenInMenu.remove(browser.id)
        } else {
            preferences.hiddenInMenu.insert(browser.id)
        }
    }

    func moveBrowsers(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ids = orderedBrowsers.map(\.bundleID)
        ids.move(fromOffsets: source, toOffset: destination)
        preferences.menuOrder = ids
    }

    /// Checked when recording a shortcut and again every time one is registered, since the
    /// user may have changed System Settings in the meantime.
    func problem(for hotkey: Hotkey) -> HotkeyProblem? {
        HotkeyValidator.problem(for: hotkey, systemShortcuts: SystemShortcuts.enabled())
    }

    // MARK: - Refreshing

    func refreshInstalled() {
        let browsers = discovery.installedBrowsers()
        if browsers != installed { installed = browsers }
    }

    func refreshDefault() {
        let browser = service.currentDefault()
        if browser != currentDefault { currentDefault = browser }
    }

    func refreshAll() {
        refreshInstalled()
        refreshDefault()
    }

    // MARK: - Switching

    /// "Switch to …", ⌥-click and the global shortcut all land here.
    func toggle() {
        guard case let .switchTo(bundleID) = switchPlan else {
            NSSound.beep()
            return
        }
        switchTo(bundleID)
    }

    func switchTo(_ bundleID: String) {
        guard !isSwitching else { return }
        refreshInstalled()
        // Only browsers LaunchServices reported can be chosen.
        guard let target = browser(for: bundleID) else {
            present(SwitchError.notInstalled(name: KnownBrowsers.displayName(for: bundleID)))
            return
        }

        isSwitching = true
        if preferences.autoConfirmDialog {
            autoConfirm.arm(targetName: target.name, currentName: currentDefault?.name)
        }

        Task { @MainActor in
            defer {
                isSwitching = false
                autoConfirm.disarm()
            }
            do {
                let outcome = try await service.setDefault(bundleID: target.bundleID, includeHTML: preferences.setsHTMLHandler)
                refreshDefault()
                switch outcome {
                case .changed:
                    announceSwitch(to: target)
                case .alreadyDefault:
                    break
                case .unchanged:
                    // The prompt may still be on screen; keep looking for a little while.
                    await watchForPendingChange(to: target)
                }
            } catch {
                refreshDefault()
                present(error)
            }
        }
    }

    private func watchForPendingChange(to target: Browser) async {
        for _ in 0 ..< 30 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            refreshDefault()
            if BundleID.same(currentDefault?.bundleID, target.bundleID) {
                announceSwitch(to: target)
                return
            }
        }
        logger.info("Default browser left unchanged.")
    }

    private func announceSwitch(to browser: Browser) {
        guard preferences.showsNotification else { return }
        Notifier.post(title: String(localized: "Default browser changed"), body: String(localized: "Links now open in \(browser.name)."))
    }

    private func present(_ error: Error) {
        logger.error("Switch failed: \(error.localizedDescription, privacy: .public)")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = error.localizedDescription
        alert.informativeText = (error as? LocalizedError)?.recoverySuggestion ?? ""
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
