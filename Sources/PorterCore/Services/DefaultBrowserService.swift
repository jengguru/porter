import Foundation

public enum SwitchError: LocalizedError, Equatable {
    /// No app with this bundle ID is installed.
    case notInstalled(name: String)
    /// The app exists but hasn't registered itself for http (seen with some Tor Browser builds).
    case notABrowser(name: String)
    /// LaunchServices returned an error other than the user declining.
    case systemRefused(name: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case let .notInstalled(name):
            return String(localized: "\(name) is not installed.")
        case let .notABrowser(name):
            return String(localized: "\(name) can't be made the default browser.")
        case let .systemRefused(name, _):
            return String(localized: "macOS couldn't make \(name) the default browser.")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notInstalled:
            return String(localized: "Pick a different favorite in Porter Settings.")
        case let .notABrowser(name):
            return String(localized: "\(name) hasn't registered itself with macOS to open web links. Open it once, or use its own “Make default browser” setting, then try again.")
        case let .systemRefused(_, reason):
            return reason
        }
    }
}

public enum SwitchOutcome: Equatable {
    /// The default browser is now the requested one.
    case changed
    /// It already was; nothing was touched.
    case alreadyDefault
    /// The request went through but the default is still something else — usually because
    /// the user chose "Keep" in the system prompt, or the prompt is still on screen.
    case unchanged
}

/// Reads and changes the default web browser, and always reports what macOS actually
/// has set rather than what was asked for.
public final class DefaultBrowserService {
    public static let schemes = ["http", "https"]
    public static let htmlContentType = "public.html"

    private let workspace: WorkspaceProviding

    public init(workspace: WorkspaceProviding) {
        self.workspace = workspace
    }

    /// The browser that currently opens http links.
    public func currentDefault() -> Browser? {
        guard let url = workspace.defaultApplicationURL(forScheme: "http") ?? workspace.defaultApplicationURL(forScheme: "https"),
              let bundleID = workspace.bundleIdentifier(ofApplicationAt: url)
        else { return nil }
        return Browser(bundleID: bundleID, name: workspace.displayName(ofApplicationAt: url), url: url)
    }

    public func isDefault(_ bundleID: String, forScheme scheme: String) -> Bool {
        BundleID.same(workspace.defaultApplicationURL(forScheme: scheme).flatMap(workspace.bundleIdentifier(ofApplicationAt:)), bundleID)
    }

    public func isDefaultForHTML(_ bundleID: String) -> Bool {
        BundleID.same(workspace.defaultApplicationURL(forContentType: Self.htmlContentType).flatMap(workspace.bundleIdentifier(ofApplicationAt:)), bundleID)
    }

    /// Makes `bundleID` the default for http and https (and `public.html` if asked), then
    /// reads the result back.
    public func setDefault(bundleID: String, includeHTML: Bool) async throws -> SwitchOutcome {
        guard BundleID.isValid(bundleID), let appURL = workspace.applicationURL(forBundleIdentifier: bundleID) else {
            throw SwitchError.notInstalled(name: KnownBrowsers.displayName(for: bundleID))
        }
        let name = workspace.displayName(ofApplicationAt: appURL)

        // Only apps that registered for http may become the default browser. This is also
        // what stops a tampered favorite from pointing Porter at an arbitrary app.
        let httpHandlers = workspace.applicationURLs(forScheme: "http").compactMap(workspace.bundleIdentifier(ofApplicationAt:))
        guard httpHandlers.contains(where: { BundleID.same($0, bundleID) }) else {
            throw SwitchError.notABrowser(name: name)
        }

        if isFullyDefault(bundleID, includeHTML: includeHTML) {
            return .alreadyDefault
        }

        for scheme in Self.schemes where !isDefault(bundleID, forScheme: scheme) {
            do {
                try await workspace.setDefaultApplication(at: appURL, forScheme: scheme)
            } catch {
                // Confirming http usually flips https as well, so judge by the result, not the error.
                if isDefault(bundleID, forScheme: scheme) { continue }
                if Self.isUserCancellation(error) { break }
                throw SwitchError.systemRefused(name: name, reason: error.localizedDescription)
            }
            // The user kept the old browser: don't ask a second time for https.
            if scheme == "http" && !isDefault(bundleID, forScheme: "http") { break }
        }

        if includeHTML && !isDefaultForHTML(bundleID) && isDefault(bundleID, forScheme: "http") {
            do {
                try await workspace.setDefaultApplication(at: appURL, forContentType: Self.htmlContentType)
            } catch {
                throw SwitchError.systemRefused(name: name, reason: error.localizedDescription)
            }
        }

        return isDefault(bundleID, forScheme: "http") ? .changed : .unchanged
    }

    private func isFullyDefault(_ bundleID: String, includeHTML: Bool) -> Bool {
        Self.schemes.allSatisfy { isDefault(bundleID, forScheme: $0) } && (!includeHTML || isDefaultForHTML(bundleID))
    }

    private static func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == CocoaError.userCancelled.rawValue
    }
}
