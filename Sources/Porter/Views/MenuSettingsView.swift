import PorterCore
import SwiftUI

/// Which browsers appear in the menu, and in what order.
struct MenuSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Browsers shown in the menu. Drag to reorder.")
                .foregroundStyle(.secondary)

            List {
                ForEach(model.orderedBrowsers) { browser in
                    HStack(spacing: 8) {
                        Toggle("", isOn: Binding(
                            get: { model.isShownInMenu(browser) },
                            set: { model.setShownInMenu(browser, $0) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        Image(nsImage: model.icons.icon(for: browser, size: 20))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(browser.name)
                            Text(browser.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if BundleID.same(browser.bundleID, model.currentDefault?.bundleID) {
                            Text("Default")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onMove { source, destination in
                    model.moveBrowsers(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))

            HStack {
                Text("New browsers show up here automatically once installed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { model.refreshAll() }
            }
        }
        .padding(20)
    }
}
