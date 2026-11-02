@testable import AppBundle
import XCTest

@MainActor
final class ClosedWindowsCacheTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        resetClosedWindowsCache()
    }

    override func tearDown() async throws {
        resetClosedWindowsCache()
    }

    func testCacheDistinguishesRediscoveredFloatingWindowFromNewWindow() {
        let workspace = focus.workspace
        let tiledWindow = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let floatingWindow = TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer)
        cacheClosedWindowIfNeeded()

        // Temporary AX unavailability detaches windows, but their IDs must remain cached.
        tiledWindow.unbindFromParent()
        floatingWindow.unbindFromParent()
        XCTAssertTrue(isWindowInClosedWindowsCache(tiledWindow.windowId))
        XCTAssertTrue(isWindowInClosedWindowsCache(floatingWindow.windowId))

        let newFloatingWindow = TestWindow.new(id: 3, parent: workspace.floatingWindowsContainer)
        XCTAssertFalse(isWindowInClosedWindowsCache(newFloatingWindow.windowId))
        XCTAssertTrue(isWindowInClosedWindowsCache(tiledWindow.windowId))

        resetClosedWindowsCache()
        XCTAssertFalse(isWindowInClosedWindowsCache(tiledWindow.windowId))
        XCTAssertFalse(isWindowInClosedWindowsCache(floatingWindow.windowId))
    }
}
