import AppKit
import PorterCore
import SwiftUI

struct ShortcutSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        Form {
            Section {
                Toggle("Enable global shortcut", isOn: $preferences.hotkeyEnabled)
                LabeledContent("Switch favorites") {
                    ShortcutRecorder(hotkey: $preferences.hotkey, isRecording: $model.isRecordingShortcut)
                }
                .disabled(!preferences.hotkeyEnabled)

                HStack {
                    Spacer()
                    Button("Restore Default (\(Hotkey.default.displayString))") {
                        preferences.hotkey = .default
                    }
                    .disabled(preferences.hotkey == .default)
                }

                if model.hotkeyRegistrationFailed {
                    Label("This shortcut is already used by macOS or another app. Choose a different one.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Works from any app. Porter registers just this one key combination with macOS; it doesn't need Accessibility or Input Monitoring access and never sees anything else you type.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// Click, then press the new combination. Esc cancels. At least one of ⌘ ⌥ ⌃ is required.
struct ShortcutRecorder: View {
    @Binding var hotkey: Hotkey
    @Binding var isRecording: Bool
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            Text(isRecording ? String(localized: "Type shortcut…") : hotkey.displayString)
                .frame(minWidth: 110)
                .monospacedDigit()
        }
        .help(isRecording ? String(localized: "Press Esc to cancel") : String(localized: "Click to record a new shortcut"))
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        // Porter unregisters its own shortcut while recording (see AppDelegate), so pressing
        // the current combination records it instead of switching browsers.
        isRecording = true
        // Local monitor: only sees keys typed into Porter's own window while recording.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                stopRecording()
                return nil
            }
            let candidate = Hotkey(keyCode: UInt32(event.keyCode), modifiers: Self.modifiers(from: event.modifierFlags))
            if candidate.isValid {
                hotkey = candidate
                stopRecording()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> Hotkey.Modifiers {
        var result: Hotkey.Modifiers = []
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.shift) { result.insert(.shift) }
        return result
    }
}
