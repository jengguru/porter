import Foundation

/// A global keyboard shortcut: a virtual key code (Carbon `kVK_*`) plus modifiers.
public struct Hotkey: Equatable, Sendable {
    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)

        public static let all: Modifiers = [.command, .option, .control, .shift]
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(.all)
    }

    /// ⌃⌥⌘B (key code 11 is `kVK_ANSI_B`).
    public static let `default` = Hotkey(keyCode: 11, modifiers: [.control, .option, .command])

    /// A global shortcut needs at least one of ⌘ ⌥ ⌃ so it can't swallow ordinary typing,
    /// and must be a key we can name.
    public var isValid: Bool {
        !modifiers.isDisjoint(with: [.command, .option, .control]) && KeyNames.name(for: keyCode) != nil
    }

    public var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + (KeyNames.name(for: keyCode) ?? "?")
    }

    /// The character to show as an `NSMenuItem` key equivalent, if the key has one.
    public var menuKeyEquivalent: String? {
        KeyNames.character(for: keyCode)
    }
}

/// Names for Carbon virtual key codes (`kVK_*` in HIToolbox/Events.h).
/// Escape is deliberately absent: it cancels shortcut recording.
public enum KeyNames {
    private static let table: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete",
        64: "F17", 79: "F18", 80: "F19", 90: "F20",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        115: "Home", 116: "Page Up", 117: "⌦", 118: "F4", 119: "End", 120: "F2",
        121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func name(for keyCode: UInt32) -> String? {
        table[keyCode]
    }

    /// Single printable ASCII character for the key, lower-cased (menu key equivalents are case-sensitive).
    public static func character(for keyCode: UInt32) -> String? {
        guard let name = table[keyCode], name.count == 1, let char = name.first, char.isASCII else { return nil }
        return name.lowercased()
    }
}
