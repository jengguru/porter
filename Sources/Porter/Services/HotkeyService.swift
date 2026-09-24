import Carbon.HIToolbox
import Foundation
import PorterCore

private let porterHotkeySignature: OSType = 0x5052_5452 // 'PRTR'

/// Registers one global shortcut with the Carbon hot-key API.
///
/// `RegisterEventHotKey` only delivers the one registered key combination to Porter, so
/// it needs no Accessibility or Input Monitoring permission and never sees other keystrokes.
final class HotkeyService {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Returns false when the combination is taken (e.g. by another app).
    @discardableResult
    func register(_ hotkey: Hotkey) -> Bool {
        unregister()
        guard hotkey.isValid, installHandlerIfNeeded() else { return false }

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            Self.carbonModifiers(hotkey.modifiers),
            EventHotKeyID(signature: porterHotkeySignature, id: 1),
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    fileprivate func fire() {
        onTrigger?()
    }

    private func installHandlerIfNeeded() -> Bool {
        if handlerRef != nil { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        return status == noErr
    }

    private static func carbonModifiers(_ modifiers: Hotkey.Modifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

private func hotKeyEventHandler(_: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == porterHotkeySignature else { return OSStatus(eventNotHandledErr) }

    let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { service.fire() }
    return noErr
}
