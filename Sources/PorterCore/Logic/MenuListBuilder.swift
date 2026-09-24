import Foundation

/// Orders and filters the browser list shown in the menu and in Settings.
public enum MenuListBuilder {
    /// Installed browsers in the user's saved order. Browsers that aren't in the saved order
    /// yet (newly installed) go after it, keeping their incoming (alphabetical) order.
    /// Saved entries that are no longer installed are simply skipped.
    public static func ordered(_ installed: [Browser], savedOrder: [String]) -> [Browser] {
        var rank: [String: Int] = [:]
        for (index, id) in savedOrder.enumerated() where rank[BundleID.normalize(id)] == nil {
            rank[BundleID.normalize(id)] = index
        }
        return installed.enumerated()
            .sorted { lhs, rhs in
                let l = rank[lhs.element.id] ?? Int.max
                let r = rank[rhs.element.id] ?? Int.max
                return l != r ? l < r : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Browsers to list in the menu: ordered, minus the ones the user hid. The current
    /// default is always kept so the ✓ never disappears.
    public static func menuItems(
        installed: [Browser],
        savedOrder: [String],
        hidden: Set<String>,
        currentDefault: String?
    ) -> [Browser] {
        let hiddenIDs = Set(hidden.map(BundleID.normalize))
        return ordered(installed, savedOrder: savedOrder).filter { browser in
            !hiddenIDs.contains(browser.id) || BundleID.same(browser.bundleID, currentDefault)
        }
    }
}
