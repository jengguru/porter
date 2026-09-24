import Foundation

/// Finds every installed app that can open http/https links.
///
/// Nothing is hardcoded: installing Brave (or anything else that registers as a web
/// browser) makes it show up the next time this runs.
public struct BrowserDiscovery {
    private let workspace: WorkspaceProviding

    public init(workspace: WorkspaceProviding) {
        self.workspace = workspace
    }

    /// Installed browsers, one per bundle ID, sorted by name.
    ///
    /// Side-by-side channels (Chrome, Chrome Beta, Chrome Canary) have different bundle
    /// IDs and are listed separately. Several copies of the *same* bundle ID collapse into
    /// the one LaunchServices would actually launch.
    public func installedBrowsers() -> [Browser] {
        var seen = Set<String>()
        var result: [Browser] = []

        let candidates = workspace.applicationURLs(forScheme: "https") + workspace.applicationURLs(forScheme: "http")
        for url in candidates {
            guard let bundleID = workspace.bundleIdentifier(ofApplicationAt: url),
                  BundleID.isValid(bundleID),
                  seen.insert(BundleID.normalize(bundleID)).inserted
            else { continue }

            let preferredURL = workspace.applicationURL(forBundleIdentifier: bundleID) ?? url
            result.append(Browser(bundleID: bundleID, name: workspace.displayName(ofApplicationAt: preferredURL), url: preferredURL))
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
