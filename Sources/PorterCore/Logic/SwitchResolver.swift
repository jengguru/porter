import Foundation

public enum SwitchUnavailableReason: Equatable {
    case favoritesNotSet
    case favoritesIdentical
    case notInstalled(bundleID: String)
}

public enum SwitchPlan: Equatable {
    case switchTo(bundleID: String)
    case unavailable(SwitchUnavailableReason)

    public var target: String? {
        if case let .switchTo(bundleID) = self { return bundleID }
        return nil
    }
}

/// Decides where "Switch to …", ⌥-click and the global shortcut go.
public enum SwitchResolver {
    /// - Current default is favorite A → B.
    /// - Current default is favorite B → A.
    /// - Anything else (another browser, or unknown) → A.
    /// - The target isn't installed → unavailable; Porter never silently picks something else.
    public static func plan(
        currentDefault: String?,
        favoriteA: String?,
        favoriteB: String?,
        isInstalled: (String) -> Bool
    ) -> SwitchPlan {
        guard let favoriteA, !favoriteA.isEmpty, let favoriteB, !favoriteB.isEmpty else {
            return .unavailable(.favoritesNotSet)
        }
        guard !BundleID.same(favoriteA, favoriteB) else {
            return .unavailable(.favoritesIdentical)
        }

        let target = BundleID.same(currentDefault, favoriteA) ? favoriteB : favoriteA
        guard isInstalled(target) else {
            return .unavailable(.notInstalled(bundleID: target))
        }
        return .switchTo(bundleID: target)
    }
}
