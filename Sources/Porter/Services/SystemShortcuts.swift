import Carbon.HIToolbox
import PorterCore

/// The shortcuts currently enabled in System Settings › Keyboard › Keyboard Shortcuts
/// (Spotlight, Mission Control, screenshots, input sources, …), read with the public
/// `CopySymbolicHotKeys` API. Read-only, no permission needed.
enum SystemShortcuts {
    static func enabled() -> [Hotkey] {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr,
              let entries = unmanaged?.takeRetainedValue() as? [[String: Any]]
        else { return [] }

        return entries.compactMap { entry in
            guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let code = entry[kHISymbolicHotKeyCode as String] as? Int,
                  let carbonModifiers = entry[kHISymbolicHotKeyModifiers as String] as? Int,
                  let keyCode = UInt32(exactly: code)
            else { return nil }
            return Hotkey(keyCode: keyCode, modifiers: modifiers(fromCarbon: carbonModifiers))
        }
    }

    private static func modifiers(fromCarbon flags: Int) -> Hotkey.Modifiers {
        var result: Hotkey.Modifiers = []
        if flags & cmdKey != 0 { result.insert(.command) }
        if flags & optionKey != 0 { result.insert(.option) }
        if flags & controlKey != 0 { result.insert(.control) }
        if flags & shiftKey != 0 { result.insert(.shift) }
        return result
    }
}
