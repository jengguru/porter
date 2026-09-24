import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            MenuSettingsView()
                .tabItem { Label("Menu", systemImage: "list.bullet") }
            ShortcutSettingsView()
                .tabItem { Label("Shortcut", systemImage: "keyboard") }
            AdvancedSettingsView()
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 520, height: 480)
    }
}
