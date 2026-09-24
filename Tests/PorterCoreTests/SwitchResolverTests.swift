import XCTest
@testable import PorterCore

final class SwitchResolverTests: XCTestCase {
    private let a = KnownBrowsers.chrome
    private let b = KnownBrowsers.safari

    private func plan(current: String?, a: String? = KnownBrowsers.chrome, b: String? = KnownBrowsers.safari,
                      installed: @escaping (String) -> Bool = { _ in true }) -> SwitchPlan {
        SwitchResolver.plan(currentDefault: current, favoriteA: a, favoriteB: b, isInstalled: installed)
    }

    func testDefaultIsFavoriteASwitchesToB() {
        XCTAssertEqual(plan(current: a), .switchTo(bundleID: b))
    }

    func testDefaultIsFavoriteBSwitchesToA() {
        XCTAssertEqual(plan(current: b), .switchTo(bundleID: a))
    }

    func testDefaultOutsideFavoritesSwitchesToA() {
        XCTAssertEqual(plan(current: KnownBrowsers.brave), .switchTo(bundleID: a))
    }

    func testUnknownDefaultSwitchesToA() {
        XCTAssertEqual(plan(current: nil), .switchTo(bundleID: a))
    }

    func testBundleIDsCompareCaseInsensitively() {
        XCTAssertEqual(plan(current: "COM.GOOGLE.CHROME"), .switchTo(bundleID: b))
    }

    func testUninstalledTargetDisablesSwitch() {
        let result = plan(current: a, installed: { !BundleID.same($0, KnownBrowsers.safari) })
        XCTAssertEqual(result, .unavailable(.notInstalled(bundleID: b)))
        XCTAssertNil(result.target)
    }

    func testUninstalledFavoriteAWhenDefaultIsElsewhereDisablesSwitch() {
        let result = plan(current: KnownBrowsers.brave, installed: { !BundleID.same($0, KnownBrowsers.chrome) })
        XCTAssertEqual(result, .unavailable(.notInstalled(bundleID: a)))
    }

    func testUninstalledCurrentFavoriteStillAllowsSwitchingToTheOther() {
        // Default is still A (LaunchServices remembers it) but A was removed; B is fine.
        let result = plan(current: a, installed: { !BundleID.same($0, KnownBrowsers.chrome) })
        XCTAssertEqual(result, .switchTo(bundleID: b))
    }

    func testIdenticalFavoritesAreUnavailable() {
        XCTAssertEqual(plan(current: a, a: a, b: "com.google.chrome"), .unavailable(.favoritesIdentical))
    }

    func testMissingFavoritesAreUnavailable() {
        XCTAssertEqual(plan(current: a, b: nil), .unavailable(.favoritesNotSet))
        XCTAssertEqual(plan(current: a, a: ""), .unavailable(.favoritesNotSet))
    }

    func testChangingFavoritesChangesTargetImmediately() {
        XCTAssertEqual(plan(current: b, a: KnownBrowsers.brave), .switchTo(bundleID: KnownBrowsers.brave))
    }
}
