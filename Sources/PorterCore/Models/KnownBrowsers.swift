import Foundation

/// Bundle IDs of browsers Porter knows by name.
///
/// Detection never depends on this list — any app registered for http/https shows up.
/// It only supplies the default favorites and a friendly name for a favorite that
/// is no longer installed.
public enum KnownBrowsers {
    public static let safari = "com.apple.Safari"
    public static let chrome = "com.google.Chrome"
    public static let brave = "com.brave.Browser"
    public static let duckDuckGo = "com.duckduckgo.macos.browser"
    public static let tor = "org.torproject.torbrowser"

    public static let defaultFavoriteA = chrome
    public static let defaultFavoriteB = safari

    private static let names: [String: String] = [
        BundleID.normalize(safari): "Safari",
        BundleID.normalize(chrome): "Google Chrome",
        BundleID.normalize(brave): "Brave Browser",
        BundleID.normalize(duckDuckGo): "DuckDuckGo",
        BundleID.normalize(tor): "Tor Browser",
    ]

    /// A human-readable name for a bundle ID, falling back to the ID itself.
    public static func displayName(for bundleID: String) -> String {
        names[BundleID.normalize(bundleID)] ?? bundleID
    }
}
