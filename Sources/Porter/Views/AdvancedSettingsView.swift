import Combine
import PorterCore
import SwiftUI

struct AdvancedSettingsView: View {
    @EnvironmentObject private var preferences: Preferences

    @State private var accessibilityGranted = DialogAutoConfirm.isTrusted
    @State private var notificationsDenied = false
    private let trustCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                Toggle("Also open .html files with the chosen browser", isOn: $preferences.setsHTMLHandler)
            } header: {
                Text("File Handler")
            } footer: {
                Text("Sets the default app for HTML files (public.html) together with http and https.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Confirm the macOS prompt automatically", isOn: $preferences.autoConfirmDialog)
                HStack {
                    if accessibilityGranted {
                        Label("Accessibility access granted", systemImage: "checkmark.shield")
                            .foregroundStyle(.green)
                    } else {
                        Label("Accessibility access not granted", systemImage: "exclamationmark.shield")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(accessibilityGranted ? "Manage…" : "Grant Access…") {
                        if !accessibilityGranted { DialogAutoConfirm.requestAccess() }
                        DialogAutoConfirm.openAccessibilitySettings()
                    }
                }
                .disabled(!preferences.autoConfirmDialog && !accessibilityGranted)
            } header: {
                Text("Confirmation Prompt")
            } footer: {
                Text("""
                macOS asks you to confirm every change of default browser. With this on, Porter clicks \
                “Use …” for you through Accessibility — only in Apple's own prompt, only for a few seconds \
                after you switch from Porter, and only on the button naming the browser you picked. If the \
                prompt looks different (for example after a macOS update) Porter leaves it for you.

                Accessibility access lets an app control your Mac. You can revoke it any time in \
                System Settings › Privacy & Security › Accessibility. Rebuilding Porter with ad-hoc signing \
                resets this permission.
                """)
                .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Show a notification after switching", isOn: Binding(
                    get: { preferences.showsNotification },
                    set: { setNotifications($0) }
                ))
                .disabled(!Notifier.isAvailable)
                if !Notifier.isAvailable {
                    Text("Available when Porter runs as an app bundle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if notificationsDenied {
                    Text("Notifications are turned off for Porter in System Settings › Notifications.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Privacy") {
                Text("Porter makes no network connections and collects no data. Settings stay in this Mac's user defaults.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onReceive(trustCheck) { _ in
            let granted = DialogAutoConfirm.isTrusted
            if granted != accessibilityGranted { accessibilityGranted = granted }
        }
    }

    private func setNotifications(_ enabled: Bool) {
        guard enabled else {
            preferences.showsNotification = false
            return
        }
        Notifier.requestAuthorization { granted in
            notificationsDenied = !granted
            preferences.showsNotification = granted
        }
    }
}
