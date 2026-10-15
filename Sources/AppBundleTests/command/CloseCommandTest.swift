@testable import AppBundle
import Common
import XCTest

@MainActor
final class CloseCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSimple() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 2)

        await parseCommand("close").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 2)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 1)
    }

    func testCloseFloatingWindowFocusesMostRecentTilingWindow() async {
        let workspace = Workspace.get(byName: name)
        let firstWindow = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let mostRecentTilingWindow = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        let floatingWindow = TestWindow.new(id: 3, parent: workspace.floatingWindowsContainer)
        _ = firstWindow.focusWindow()
        _ = mostRecentTilingWindow.focusWindow()
        _ = floatingWindow.focusWindow()

        await parseCommand("close").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testCloseViaWindowIdFlag() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 2)

        await parseCommand("close --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.workspace.rootTilingContainer.children.count, 1)
    }
}
