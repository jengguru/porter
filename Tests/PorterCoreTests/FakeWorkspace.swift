import Foundation
@testable import PorterCore

/// In-memory LaunchServices stand-in.
final class FakeWorkspace: WorkspaceProviding {
    struct App {
        var bundleID: String
        var name: String
        var url: URL
        var schemes: Set<String> = ["http", "https"]
    }

    enum UserResponse {
        /// Clicks "Use …" — http and https both change, as macOS does.
        case accept
        /// Clicks "Keep …" — nothing changes, no error.
        case keep
        /// Nothing changes and the call fails with this error.
        case fail(Error)
    }

    var apps: [App]
    /// scheme or content type -> bundle ID
    var defaults: [String: String]
    var response: UserResponse = .accept
    private(set) var setCalls: [String] = []

    init(apps: [App], defaults: [String: String] = [:]) {
        self.apps = apps
        self.defaults = defaults
    }

    static func app(_ bundleID: String, _ name: String, path: String? = nil, schemes: Set<String> = ["http", "https"]) -> App {
        App(bundleID: bundleID, name: name, url: URL(fileURLWithPath: path ?? "/Applications/\(name).app"), schemes: schemes)
    }

    private func app(at url: URL) -> App? {
        apps.first { $0.url == url }
    }

    func applicationURLs(forScheme scheme: String) -> [URL] {
        apps.filter { $0.schemes.contains(scheme) }.map(\.url)
    }

    func defaultApplicationURL(forScheme scheme: String) -> URL? {
        defaults[scheme].flatMap(applicationURL(forBundleIdentifier:))
    }

    func defaultApplicationURL(forContentType identifier: String) -> URL? {
        defaults[identifier].flatMap(applicationURL(forBundleIdentifier:))
    }

    func applicationURL(forBundleIdentifier bundleID: String) -> URL? {
        apps.first { BundleID.same($0.bundleID, bundleID) }?.url
    }

    func bundleIdentifier(ofApplicationAt url: URL) -> String? {
        app(at: url)?.bundleID
    }

    func displayName(ofApplicationAt url: URL) -> String {
        app(at: url)?.name ?? url.deletingPathExtension().lastPathComponent
    }

    func setDefaultApplication(at appURL: URL, forScheme scheme: String) async throws {
        setCalls.append(scheme)
        switch response {
        case .accept:
            guard let id = bundleIdentifier(ofApplicationAt: appURL) else { return }
            defaults["http"] = id
            defaults["https"] = id
        case .keep:
            break
        case let .fail(error):
            throw error
        }
    }

    func setDefaultApplication(at appURL: URL, forContentType identifier: String) async throws {
        setCalls.append(identifier)
        defaults[identifier] = bundleIdentifier(ofApplicationAt: appURL)
    }
}

enum Fixtures {
    static let safari = FakeWorkspace.app(KnownBrowsers.safari, "Safari")
    static let chrome = FakeWorkspace.app(KnownBrowsers.chrome, "Google Chrome")
    static let chromeBeta = FakeWorkspace.app("com.google.Chrome.beta", "Google Chrome Beta")
    static let brave = FakeWorkspace.app(KnownBrowsers.brave, "Brave Browser")
    /// Some Tor Browser builds don't register for http.
    static let tor = FakeWorkspace.app(KnownBrowsers.tor, "Tor Browser", schemes: [])
}
