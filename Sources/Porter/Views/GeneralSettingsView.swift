import PorterCore
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: Preferences

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginNeedsApproval = LoginItem.needsApproval
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                FavoritePicker(title: "Favorite A", selection: $preferences.favoriteA)
                FavoritePicker(title: "Favorite B", selection: $preferences.favoriteB)
                if BundleID.same(preferences.favoriteA, preferences.favoriteB) {
                    Label("Pick two different browsers to switch between.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Favorites")
            } footer: {
                Text("“Switch to …”, ⌥-click on the menu bar icon and the global shortcut toggle between these two. If another browser is the default, they switch to Favorite A.")
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Menu bar icon", selection: $preferences.iconStyle) {
                    Text("App colors").tag(IconStyle.color)
                    Text("Monochrome").tag(IconStyle.monochrome)
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                if loginNeedsApproval {
                    HStack {
                        Text("Allow Porter in System Settings › General › Login Items.")
                            .foregroundStyle(.secondary)
                        Button("Open…") { LoginItem.openLoginItemsSettings() }
                    }
                }
                if let loginError {
                    Text(loginError).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshLoginState)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        refreshLoginState()
    }

    private func refreshLoginState() {
        launchAtLogin = LoginItem.isEnabled || LoginItem.needsApproval
        loginNeedsApproval = LoginItem.needsApproval
    }
}

/// Dropdown of installed browsers. A favorite that has been uninstalled stays selected but
/// is greyed out and marked "Not installed".
struct FavoritePicker: View {
    let title: LocalizedStringKey
    @Binding var selection: String
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let installed = model.isInstalled(selection)
        VStack(alignment: .leading, spacing: 4) {
            Picker(title, selection: canonicalSelection) {
                ForEach(model.installed) { browser in
                    Label {
                        Text(browser.name)
                    } icon: {
                        Image(nsImage: model.icons.icon(for: browser, size: 16))
                    }
                    .tag(browser.bundleID)
                }
                if !installed {
                    Text("\(model.displayName(for: selection)) (Not installed)")
                        .foregroundStyle(.secondary)
                        .tag(selection)
                }
            }
            if !installed {
                Text("Not installed — switching to it is disabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Stored IDs may differ in case from what LaunchServices reports; show the installed match.
    private var canonicalSelection: Binding<String> {
        Binding(
            get: { model.browser(for: selection)?.bundleID ?? selection },
            set: { selection = $0 }
        )
    }
}
