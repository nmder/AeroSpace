@testable import AppBundle
import Testing

@MainActor
@Suite(.serializedGlobally)
struct MacWindowTest {
    init() { setUpWorkspacesForTests() }

    @Test func testForceNativeFocusAfterClosedWindowOnlyWhenNeeded() {
        let closingWorkspace = globalFocus.workspace
        let sameWorkspaceWindow = TestWindow.new(id: 1, parent: closingWorkspace.rootTilingContainer)
        #expect(sameWorkspaceWindow.focusWindow())

        // Preserve the Apple Reminders popup guard: the same app still focused on the same workspace needs no correction.
        #expect(!shouldForceNativeFocusAfterWindowClosed(globalFocus, closingWorkspace, TestApp.shared.pid))

        // A different app taking focus still needs the existing correction.
        #expect(shouldForceNativeFocusAfterWindowClosed(globalFocus, closingWorkspace, TestApp.shared.pid + 1))

        // macOS can focus another window of the closing app on a different monitor/workspace.
        let otherWorkspace = Workspace.get(byName: "other")
        let sameAppOtherWorkspaceWindow = TestWindow.new(id: 2, parent: otherWorkspace.rootTilingContainer)
        #expect(sameAppOtherWorkspaceWindow.focusWindow())
        #expect(shouldForceNativeFocusAfterWindowClosed(globalFocus, closingWorkspace, TestApp.shared.pid))
    }
}
