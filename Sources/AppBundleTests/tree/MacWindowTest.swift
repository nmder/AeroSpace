@testable import AppBundle
import XCTest

@MainActor
final class MacWindowTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testForceNativeFocusAfterClosedWindowOnlyWhenNeeded() {
        let closingWorkspace = focus.workspace
        let sameWorkspaceWindow = TestWindow.new(id: 1, parent: closingWorkspace.rootTilingContainer)
        assertEquals(sameWorkspaceWindow.focusWindow(), true)

        // Preserve the Apple Reminders popup guard: the same app still focused on the same workspace needs no correction.
        XCTAssertFalse(shouldForceNativeFocusAfterWindowClosed(focus, closingWorkspace, TestApp.shared.pid))

        // A different app taking focus still needs the existing correction.
        XCTAssertTrue(shouldForceNativeFocusAfterWindowClosed(focus, closingWorkspace, TestApp.shared.pid + 1))

        // macOS can focus another window of the closing app on a different monitor/workspace.
        let otherWorkspace = Workspace.get(byName: "other")
        let sameAppOtherWorkspaceWindow = TestWindow.new(id: 2, parent: otherWorkspace.rootTilingContainer)
        assertEquals(sameAppOtherWorkspaceWindow.focusWindow(), true)
        XCTAssertTrue(shouldForceNativeFocusAfterWindowClosed(focus, closingWorkspace, TestApp.shared.pid))
    }
}
