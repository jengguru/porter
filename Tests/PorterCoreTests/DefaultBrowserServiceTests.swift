import XCTest
@testable import PorterCore

final class DefaultBrowserServiceTests: XCTestCase {
    private func makeWorkspace(default id: String = KnownBrowsers.safari) -> FakeWorkspace {
        FakeWorkspace(
            apps: [Fixtures.safari, Fixtures.chrome, Fixtures.brave, Fixtures.tor],
            defaults: ["http": id, "https": id, "public.html": id]
        )
    }

    func testReadsCurrentDefault() {
        let service = DefaultBrowserService(workspace: makeWorkspace(default: KnownBrowsers.chrome))
        XCTAssertEqual(service.currentDefault()?.bundleID, KnownBrowsers.chrome)
        XCTAssertEqual(service.currentDefault()?.name, "Google Chrome")
    }

    func testSwitchSetsHTTPAndReportsChanged() async throws {
        let workspace = makeWorkspace()
        let service = DefaultBrowserService(workspace: workspace)

        let outcome = try await service.setDefault(bundleID: KnownBrowsers.chrome, includeHTML: false)

        XCTAssertEqual(outcome, .changed)
        XCTAssertEqual(workspace.defaults["http"], KnownBrowsers.chrome)
        XCTAssertEqual(workspace.defaults["https"], KnownBrowsers.chrome)
        // Confirming http flipped https too, so the user is asked only once.
        XCTAssertEqual(workspace.setCalls, ["http"])
        XCTAssertEqual(workspace.defaults["public.html"], KnownBrowsers.safari, "HTML handler is opt-in")
    }

    func testAlreadyDefaultDoesNothing() async throws {
        let workspace = makeWorkspace(default: KnownBrowsers.chrome)
        let outcome = try await DefaultBrowserService(workspace: workspace).setDefault(bundleID: KnownBrowsers.chrome, includeHTML: false)
        XCTAssertEqual(outcome, .alreadyDefault)
        XCTAssertTrue(workspace.setCalls.isEmpty)
    }

    func testUserKeepingOldBrowserReportsUnchanged() async throws {
        let workspace = makeWorkspace()
        workspace.response = .keep

        let outcome = try await DefaultBrowserService(workspace: workspace).setDefault(bundleID: KnownBrowsers.chrome, includeHTML: true)

        XCTAssertEqual(outcome, .unchanged)
        XCTAssertEqual(workspace.defaults["http"], KnownBrowsers.safari)
        XCTAssertEqual(workspace.setCalls, ["http"], "Must not prompt again for https or touch html")
    }

    func testUserCancellationErrorReportsUnchanged() async throws {
        let workspace = makeWorkspace()
        workspace.response = .fail(CocoaError(.userCancelled))
        let outcome = try await DefaultBrowserService(workspace: workspace).setDefault(bundleID: KnownBrowsers.chrome, includeHTML: false)
        XCTAssertEqual(outcome, .unchanged)
    }

    func testOtherSystemErrorIsReported() async {
        let workspace = makeWorkspace()
        workspace.response = .fail(CocoaError(.fileReadUnknown))
        do {
            _ = try await DefaultBrowserService(workspace: workspace).setDefault(bundleID: KnownBrowsers.chrome, includeHTML: false)
            XCTFail("Expected an error")
        } catch let error as SwitchError {
            guard case .systemRefused(name: "Google Chrome", reason: _) = error else {
                return XCTFail("Unexpected error \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testIncludeHTMLAlsoSetsHTMLHandler() async throws {
        let workspace = makeWorkspace()
        let outcome = try await DefaultBrowserService(workspace: workspace).setDefault(bundleID: KnownBrowsers.brave, includeHTML: true)
        XCTAssertEqual(outcome, .changed)
        XCTAssertEqual(workspace.defaults["public.html"], KnownBrowsers.brave)
    }

    func testIncludeHTMLWhenOnlyHTMLDiffers() async throws {
        let workspace = makeWorkspace(default: KnownBrowsers.chrome)
        workspace.defaults["public.html"] = KnownBrowsers.safari
        let outcome = try await DefaultBrowserService(workspace: workspace).setDefault(bundleID: KnownBrowsers.chrome, includeHTML: true)
        XCTAssertEqual(outcome, .changed)
        XCTAssertEqual(workspace.setCalls, ["public.html"])
    }

    func testUninstalledBrowserThrowsNotInstalled() async {
        let workspace = makeWorkspace()
        await XCTAssertThrowsSwitchError(
            try await DefaultBrowserService(workspace: workspace).setDefault(bundleID: KnownBrowsers.duckDuckGo, includeHTML: false),
            .notInstalled(name: "DuckDuckGo")
        )
        XCTAssertTrue(workspace.setCalls.isEmpty)
    }

    func testAppNotRegisteredForHTTPThrowsClearError() async {
        let workspace = makeWorkspace()
        await XCTAssertThrowsSwitchError(
            try await DefaultBrowserService(workspace: workspace).setDefault(bundleID: KnownBrowsers.tor, includeHTML: false),
            .notABrowser(name: "Tor Browser")
        )
        XCTAssertTrue(workspace.setCalls.isEmpty)
    }

    func testNonBrowserAppIsRefused() async {
        let workspace = makeWorkspace()
        workspace.apps.append(FakeWorkspace.app("com.apple.Terminal", "Terminal", path: "/System/Applications/Utilities/Terminal.app", schemes: []))
        await XCTAssertThrowsSwitchError(
            try await DefaultBrowserService(workspace: workspace).setDefault(bundleID: "com.apple.Terminal", includeHTML: false),
            .notABrowser(name: "Terminal")
        )
    }

    func testMalformedBundleIDIsRejected() async {
        let workspace = makeWorkspace()
        await XCTAssertThrowsSwitchError(
            try await DefaultBrowserService(workspace: workspace).setDefault(bundleID: "../../evil app", includeHTML: false),
            .notInstalled(name: "../../evil app")
        )
    }
}

private func XCTAssertThrowsSwitchError<T>(
    _ expression: @autoclosure () async throws -> T,
    _ expected: SwitchError,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected \(expected)", file: file, line: line)
    } catch let error as SwitchError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Unexpected error \(error)", file: file, line: line)
    }
}
