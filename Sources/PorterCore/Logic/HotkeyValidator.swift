import Foundation

public enum HotkeyProblem: Equatable {
    /// Fewer than two of ⌘ ⌥ ⌃.
    case needsTwoModifiers
    case unsupportedKey
    /// Enabled in System Settings › Keyboard › Keyboard Shortcuts.
    case reservedBySystem
    /// A standard macOS or popular-app shortcut.
    case commonShortcut(name: String)
    /// macOS refused to register it — another app already holds it.
    case inUseByAnotherApp

    public var message: String {
        switch self {
        case .needsTwoModifiers:
            return String(localized: "Use at least two of ⌘ ⌥ ⌃, so it can't clash with app shortcuts or typing.")
        case .unsupportedKey:
            return String(localized: "This key can't be used in a shortcut.")
        case .reservedBySystem:
            return String(localized: "Already used by macOS (System Settings › Keyboard › Keyboard Shortcuts).")
        case let .commonShortcut(name):
            return String(localized: "Already used by macOS or common apps: \(name).")
        case .inUseByAnotherApp:
            return String(localized: "Already used by another app.")
        }
    }
}

public struct KnownShortcut: Sendable {
    public let hotkey: Hotkey
    public let name: String
}

/// Decides whether a shortcut is safe to claim globally.
public enum HotkeyValidator {
    /// - Parameter systemShortcuts: the shortcuts currently enabled in System Settings.
    public static func problem(for hotkey: Hotkey, systemShortcuts: [Hotkey]) -> HotkeyProblem? {
        guard KeyNames.name(for: hotkey.keyCode) != nil else { return .unsupportedKey }
        guard hotkey.hasEnoughModifiers else { return .needsTwoModifiers }
        if systemShortcuts.contains(hotkey) { return .reservedBySystem }
        if let known = commonShortcuts.first(where: { $0.hotkey == hotkey }) {
            return .commonShortcut(name: known.name)
        }
        return nil
    }

    /// Two-modifier shortcuts that ship with macOS menus or the major browsers/Finder and
    /// don't appear in System Settings' shortcut list, so the system check can't catch them.
    public static let commonShortcuts: [KnownShortcut] = {
        let controlCommand: Hotkey.Modifiers = [.control, .command]
        let optionCommand: Hotkey.Modifiers = [.option, .command]
        let entries: [(UInt32, Hotkey.Modifiers, String)] = [
            (12, controlCommand, "Lock Screen"),
            (3, controlCommand, "Enter Full Screen"),
            (49, controlCommand, "Emoji & Symbols"),
            (2, controlCommand, "Look Up"),
            (45, controlCommand, "New Folder with Selection (Finder)"),
            (4, optionCommand, "Hide Others"),
            (46, optionCommand, "Minimize All"),
            (13, optionCommand, "Close All Windows"),
            (2, optionCommand, "Show/Hide Dock"),
            (9, optionCommand, "Move Item Here (Finder)"),
            (17, optionCommand, "Show/Hide Toolbar"),
            (1, optionCommand, "Show/Hide Sidebar"),
            (35, optionCommand, "Show/Hide Path Bar (Finder)"),
            (49, optionCommand, "Finder Search Window"),
            (11, optionCommand, "Show Bookmarks (Safari, Chrome)"),
            (34, optionCommand, "Developer Tools (browsers)"),
            (38, optionCommand, "JavaScript Console (browsers)"),
            (32, optionCommand, "View Source (browsers)"),
            (8, optionCommand, "Inspect Element / Copy Style"),
            (37, optionCommand, "Downloads (browsers)"),
            (3, optionCommand, "Search Field (Finder, Mail)"),
            (31, optionCommand, "Open in New Window (Finder)"),
            (14, optionCommand, "Eject / Emoji (some apps)"),
        ]
        return entries.map { KnownShortcut(hotkey: Hotkey(keyCode: $0.0, modifiers: $0.1), name: $0.2) }
    }()
}
