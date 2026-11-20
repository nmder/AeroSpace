@testable import AppBundle
import Testing

@MainActor
@Suite(.serializedGlobally)
struct ClosedWindowsCacheTest {
    init() {
        setUpWorkspacesForTests()
        resetClosedWindowsCache()
    }

    @Test func testCacheDistinguishesRediscoveredFloatingWindowFromNewWindow() {
        defer { resetClosedWindowsCache() }
        let workspace = globalFocus.workspace
        let tiledWindow = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let floatingWindow = TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer)
        cacheClosedWindowIfNeeded()

        // Temporary AX unavailability detaches windows, but their IDs must remain cached.
        tiledWindow.unbindFromParent()
        floatingWindow.unbindFromParent()
        #expect(isWindowInClosedWindowsCache(tiledWindow.windowId))
        #expect(isWindowInClosedWindowsCache(floatingWindow.windowId))

        let newFloatingWindow = TestWindow.new(id: 3, parent: workspace.floatingWindowsContainer)
        #expect(!isWindowInClosedWindowsCache(newFloatingWindow.windowId))
        #expect(isWindowInClosedWindowsCache(tiledWindow.windowId))

        resetClosedWindowsCache()
        #expect(!isWindowInClosedWindowsCache(tiledWindow.windowId))
        #expect(!isWindowInClosedWindowsCache(floatingWindow.windowId))
    }

    @Test func testSuccessiveDisappearanceBatchesPreserveEarlierWindows() {
        defer { resetClosedWindowsCache() }
        let firstWorkspace = Workspace.get(byName: "first")
        let secondWorkspace = Workspace.get(byName: "second")
        let firstWindow = TestWindow.new(id: 1, parent: firstWorkspace.rootTilingContainer)
        let secondWindow = TestWindow.new(id: 2, parent: secondWorkspace.floatingWindowsContainer)
        cacheClosedWindowIfNeeded()

        // AX can report disappearance across successive refreshes. Taking the second
        // snapshot must not forget the window detached by the first refresh.
        firstWindow.unbindFromParent()
        cacheClosedWindowIfNeeded()
        secondWindow.unbindFromParent()

        #expect(isWindowInClosedWindowsCache(firstWindow.windowId))
        #expect(isWindowInClosedWindowsCache(secondWindow.windowId))
    }
}
