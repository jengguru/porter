import XCTest
@testable import PorterCore

final class BrowserDiscoveryTests: XCTestCase {
    func testFindsEveryHTTPHandlerSortedByName() {
        let workspace = FakeWorkspace(apps: [Fixtures.safari, Fixtures.chrome, Fixtures.brave])
        let names = BrowserDiscovery(workspace: workspace).installedBrowsers().map(\.name)
        XCTAssertEqual(names, ["Brave Browser", "Google Chrome", "Safari"])
    }

    func testNewlyInstalledBrowserAppearsWithoutCodeChanges() {
        let workspace = FakeWorkspace(apps: [Fixtures.safari, Fixtures.chrome])
        let discovery = BrowserDiscovery(workspace: workspace)
        XCTAssertFalse(discovery.installedBrowsers().contains { $0.bundleID == "org.mozilla.firefox" })

        workspace.apps.append(FakeWorkspace.app("org.mozilla.firefox", "Firefox"))
        XCTAssertTrue(discovery.installedBrowsers().contains { $0.bundleID == "org.mozilla.firefox" })
    }

    func testReleaseChannelsAreListedSeparately() {
        let workspace = FakeWorkspace(apps: [Fixtures.chrome, Fixtures.chromeBeta])
        let ids = BrowserDiscovery(workspace: workspace).installedBrowsers().map(\.bundleID)
        XCTAssertEqual(ids, [KnownBrowsers.chrome, "com.google.Chrome.beta"])
    }

    func testDuplicateCopiesOfOneBundleIDCollapse() {
        let userCopy = FakeWorkspace.app(KnownBrowsers.chrome, "Google Chrome", path: "/Users/me/Applications/Google Chrome.app")
        // applicationURL(forBundleIdentifier:) returns the first match, i.e. /Applications.
        let workspace = FakeWorkspace(apps: [Fixtures.chrome, userCopy])
        let browsers = BrowserDiscovery(workspace: workspace).installedBrowsers()
        XCTAssertEqual(browsers.count, 1)
        XCTAssertEqual(browsers.first?.url, Fixtures.chrome.url)
    }

    func testAppsWithoutHTTPRegistrationAreNotListed() {
        let workspace = FakeWorkspace(apps: [Fixtures.safari, Fixtures.tor])
        XCTAssertEqual(BrowserDiscovery(workspace: workspace).installedBrowsers().map(\.bundleID), [KnownBrowsers.safari])
    }

    func testInvalidBundleIDsAreSkipped() {
        let workspace = FakeWorkspace(apps: [Fixtures.safari, FakeWorkspace.app("bad id!", "Weird")])
        XCTAssertEqual(BrowserDiscovery(workspace: workspace).installedBrowsers().map(\.bundleID), [KnownBrowsers.safari])
    }
}
