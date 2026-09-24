import AppKit
import PorterCore
import UniformTypeIdentifiers

/// `WorkspaceProviding` backed by the real `NSWorkspace` / LaunchServices.
/// Only local LaunchServices lookups; no URL is ever opened or fetched.
final class SystemWorkspace: WorkspaceProviding {
    private let workspace = NSWorkspace.shared

    private func probeURL(_ scheme: String) -> URL? {
        URL(string: "\(scheme)://example.com")
    }

    func applicationURLs(forScheme scheme: String) -> [URL] {
        guard let url = probeURL(scheme) else { return [] }
        return workspace.urlsForApplications(toOpen: url)
    }

    func defaultApplicationURL(forScheme scheme: String) -> URL? {
        guard let url = probeURL(scheme) else { return nil }
        return workspace.urlForApplication(toOpen: url)
    }

    func defaultApplicationURL(forContentType identifier: String) -> URL? {
        guard let type = UTType(identifier) else { return nil }
        return workspace.urlForApplication(toOpen: type)
    }

    func applicationURL(forBundleIdentifier bundleID: String) -> URL? {
        workspace.urlForApplication(withBundleIdentifier: bundleID)
    }

    func bundleIdentifier(ofApplicationAt url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }

    func displayName(ofApplicationAt url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    func setDefaultApplication(at appURL: URL, forScheme scheme: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workspace.setDefaultApplication(at: appURL, toOpenURLsWithScheme: scheme) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func setDefaultApplication(at appURL: URL, forContentType identifier: String) async throws {
        guard let type = UTType(identifier) else { throw CocoaError(.featureUnsupported) }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workspace.setDefaultApplication(at: appURL, toOpen: type) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }
}
