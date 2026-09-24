import Foundation

/// A web browser installed on this Mac.
///
/// Browsers are always referred to by bundle ID, never by path, so moving an app
/// (e.g. from ~/Applications to /Applications) doesn't break favorites.
public struct Browser: Hashable, Identifiable, Sendable {
    public let bundleID: String
    public let name: String
    public let url: URL

    public var id: String { BundleID.normalize(bundleID) }

    public init(bundleID: String, name: String, url: URL) {
        self.bundleID = bundleID
        self.name = name
        self.url = url
    }
}

/// Helpers for comparing and validating bundle identifiers.
///
/// LaunchServices is case-insensitive about bundle IDs and sometimes hands them back
/// lower-cased, so every comparison goes through here.
public enum BundleID {
    public static func normalize(_ id: String) -> String {
        id.lowercased()
    }

    public static func same(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs else { return false }
        return normalize(lhs) == normalize(rhs)
    }

    /// Reverse-DNS characters only. Anything else (e.g. a tampered defaults value) is rejected
    /// before it gets anywhere near LaunchServices.
    public static func isValid(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= 255 else { return false }
        return id.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "." || scalar == "-" || scalar == "_")
        }
    }
}
