import Combine
import Foundation

public enum IconStyle: String, CaseIterable, Identifiable, Sendable {
    case color
    case monochrome

    public var id: String { rawValue }
}

/// All user settings, persisted in `UserDefaults`.
///
/// Values read back from disk are validated; anything malformed falls back to the default
/// instead of being trusted.
public final class Preferences: ObservableObject {
    enum Key {
        static let favoriteA = "favoriteA"
        static let favoriteB = "favoriteB"
        static let menuOrder = "menuOrder"
        static let hiddenInMenu = "hiddenInMenu"
        static let iconStyle = "iconStyle"
        static let hotkeyEnabled = "hotkeyEnabled"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let setsHTMLHandler = "setsHTMLHandler"
        static let autoConfirmDialog = "autoConfirmDialog"
        static let showsNotification = "showsNotification"
    }

    private let defaults: UserDefaults

    @Published public var favoriteA: String {
        didSet { defaults.set(favoriteA, forKey: Key.favoriteA) }
    }

    @Published public var favoriteB: String {
        didSet { defaults.set(favoriteB, forKey: Key.favoriteB) }
    }

    /// Bundle IDs in the order the user arranged them in Settings.
    @Published public var menuOrder: [String] {
        didSet { defaults.set(menuOrder, forKey: Key.menuOrder) }
    }

    /// Normalized bundle IDs the user unticked. Stored as "hidden" rather than "shown"
    /// so a newly installed browser appears without any extra step.
    @Published public var hiddenInMenu: Set<String> {
        didSet { defaults.set(hiddenInMenu.sorted(), forKey: Key.hiddenInMenu) }
    }

    @Published public var iconStyle: IconStyle {
        didSet { defaults.set(iconStyle.rawValue, forKey: Key.iconStyle) }
    }

    @Published public var hotkeyEnabled: Bool {
        didSet { defaults.set(hotkeyEnabled, forKey: Key.hotkeyEnabled) }
    }

    @Published public var hotkey: Hotkey {
        didSet {
            defaults.set(Int(hotkey.keyCode), forKey: Key.hotkeyKeyCode)
            defaults.set(hotkey.modifiers.rawValue, forKey: Key.hotkeyModifiers)
        }
    }

    /// Also claim `public.html` files. Off by default.
    @Published public var setsHTMLHandler: Bool {
        didSet { defaults.set(setsHTMLHandler, forKey: Key.setsHTMLHandler) }
    }

    /// Press the system confirmation button via Accessibility. Off by default.
    @Published public var autoConfirmDialog: Bool {
        didSet { defaults.set(autoConfirmDialog, forKey: Key.autoConfirmDialog) }
    }

    @Published public var showsNotification: Bool {
        didSet { defaults.set(showsNotification, forKey: Key.showsNotification) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        favoriteA = Self.validBundleID(defaults.string(forKey: Key.favoriteA)) ?? KnownBrowsers.defaultFavoriteA
        favoriteB = Self.validBundleID(defaults.string(forKey: Key.favoriteB)) ?? KnownBrowsers.defaultFavoriteB
        menuOrder = (defaults.stringArray(forKey: Key.menuOrder) ?? []).filter(BundleID.isValid)
        hiddenInMenu = Set((defaults.stringArray(forKey: Key.hiddenInMenu) ?? []).filter(BundleID.isValid).map(BundleID.normalize))
        iconStyle = defaults.string(forKey: Key.iconStyle).flatMap(IconStyle.init(rawValue:)) ?? .color
        hotkeyEnabled = defaults.object(forKey: Key.hotkeyEnabled) as? Bool ?? true

        var storedHotkey = Hotkey.default
        if let code = defaults.object(forKey: Key.hotkeyKeyCode) as? Int,
           let mods = defaults.object(forKey: Key.hotkeyModifiers) as? Int,
           let keyCode = UInt32(exactly: code) {
            let candidate = Hotkey(keyCode: keyCode, modifiers: Hotkey.Modifiers(rawValue: mods))
            if candidate.isValid { storedHotkey = candidate }
        }
        hotkey = storedHotkey

        setsHTMLHandler = defaults.bool(forKey: Key.setsHTMLHandler)
        autoConfirmDialog = defaults.bool(forKey: Key.autoConfirmDialog)
        showsNotification = defaults.bool(forKey: Key.showsNotification)
    }

    private static func validBundleID(_ value: String?) -> String? {
        guard let value, BundleID.isValid(value) else { return nil }
        return value
    }
}
