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
                    ShortcutRecorder(hotkey: $preferences.hotkey, isRecording: $model.isRecordingShortcut, validate: { model.problem(for: $0) })
                }
                .disabled(!preferences.hotkeyEnabled)

                HStack {
                    Spacer()
                    Button("Restore Default (\(Hotkey.default.displayString))") {
                        preferences.hotkey = .default
                    }
                    .disabled(preferences.hotkey == .default)
                }

                if preferences.hotkeyEnabled, let problem = model.hotkeyProblem {
                    Label("\(preferences.hotkey.displayString) is turned off: \(problem.message) Choose a different shortcut.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Works from any app, so Porter only accepts a combination of at least two of ⌘ ⌥ ⌃ that isn't used by macOS (System Settings › Keyboard Shortcuts), by common macOS/browser menus, or by another app's global shortcut. Shortcuts inside individual third-party apps can't be detected — if one stops working, pick another here. Porter registers just this one combination; it needs no Accessibility or Input Monitoring access and never sees anything else you type.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// Click, then press the new combination. Esc cancels. Conflicting combinations are
/// refused with the reason, and recording continues.
struct ShortcutRecorder: View {
    @Binding var hotkey: Hotkey
    @Binding var isRecording: Bool
    let validate: (Hotkey) -> HotkeyProblem?
    @State private var monitor: Any?
    @State private var rejection: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button(action: toggleRecording) {
                Text(isRecording ? String(localized: "Type shortcut…") : hotkey.displayString)
                    .frame(minWidth: 110)
                    .monospacedDigit()
            }
            .help(isRecording ? String(localized: "Press Esc to cancel") : String(localized: "Click to record a new shortcut"))

            if let rejection {
                Text(rejection)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        // Porter unregisters its own shortcut while recording (see AppDelegate), so pressing
        // the current combination records it instead of switching browsers.
        isRecording = true
        rejection = nil
        // Local monitor: only sees keys typed into Porter's own window while recording.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                stopRecording()
                return nil
            }
            let candidate = Hotkey(keyCode: UInt32(event.keyCode), modifiers: Self.modifiers(from: event.modifierFlags))
            if let problem = validate(candidate) {
                rejection = "\(candidate.displayString): \(problem.message)"
                NSSound.beep()
            } else {
                rejection = nil
                hotkey = candidate
                stopRecording()
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
