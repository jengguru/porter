import Foundation

/// The slice of LaunchServices / `NSWorkspace` Porter depends on.
///
/// The app uses an `NSWorkspace`-backed implementation; tests inject a fake, so all
/// switching logic can be exercised without touching the real system defaults.
public protocol WorkspaceProviding {
    /// Apps registered to open URLs with this scheme (e.g. "https").
    func applicationURLs(forScheme scheme: String) -> [URL]
    /// The app currently set to open URLs with this scheme.
    func defaultApplicationURL(forScheme scheme: String) -> URL?
    /// The app currently set to open files of this uniform type identifier (e.g. "public.html").
    func defaultApplicationURL(forContentType identifier: String) -> URL?
    /// Where LaunchServices would launch the app with this bundle ID from.
    func applicationURL(forBundleIdentifier bundleID: String) -> URL?
    func bundleIdentifier(ofApplicationAt url: URL) -> String?
    func displayName(ofApplicationAt url: URL) -> String

    /// For http/https this makes macOS show its "change default web browser" prompt.
    func setDefaultApplication(at appURL: URL, forScheme scheme: String) async throws
    func setDefaultApplication(at appURL: URL, forContentType identifier: String) async throws
}
