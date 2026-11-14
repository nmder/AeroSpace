@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct CloseCommandTest {
    init() { setUpWorkspacesForTests() }

    @Test func testSimple() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(globalFocus.windowOrNil?.windowId, 1)
        assertEquals(globalFocus.workspace.rootTilingContainer.children.count, 2)

        await parseCommand("close").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(globalFocus.windowOrNil?.windowId, 2)
        assertEquals(globalFocus.workspace.rootTilingContainer.children.count, 1)
    }

    @Test func testCloseFloatingWindowFocusesMostRecentTilingWindow() async {
        let workspace = Workspace.get(byName: name)
        let firstWindow = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let mostRecentTilingWindow = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        let floatingWindow = TestWindow.new(id: 3, parent: workspace.floatingWindowsContainer)
        _ = firstWindow.focusWindow()
        _ = mostRecentTilingWindow.focusWindow()
        _ = floatingWindow.focusWindow()

        await parseCommand("close").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(globalFocus.windowOrNil?.windowId, 2)
    }

    @Test func testCloseViaWindowIdFlag() async {
        Workspace.get(byName: name).rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(globalFocus.windowOrNil?.windowId, 1)
        assertEquals(globalFocus.workspace.rootTilingContainer.children.count, 2)

        await parseCommand("close --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(globalFocus.windowOrNil?.windowId, 1)
        assertEquals(globalFocus.workspace.rootTilingContainer.children.count, 1)
    }
}
