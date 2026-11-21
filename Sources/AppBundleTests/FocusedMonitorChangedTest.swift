@testable import AppBundle
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct FocusedMonitorChangedTest {
    init() { setUpWorkspacesForTests() }

    @Test func crossDisplayTransitionRunsConfiguredCallbackForTargetWorkspace() async {
        await checkOnFocusChangedCallbacks_nonCancellable()
        config.onFocusedMonitorChanged = parseCommand("echo -- %{workspace}").cmdOrDie
        let io = CmdIoImpl(stdin: .emptyStdin)
        let focus = globalFocus

        let result = await onFocusedMonitorChangedIfNeeded(
            previousDisplayId: "another-physical-display",
            currentDisplayId: focus.workspace.workspaceMonitorInfo.physicalDisplayId,
            .defaultEnv, io, focus,
        )

        #expect(result.rawValue == 0)
        #expect(io.stdout == [focus.workspace.name])
    }

    @Test func sameDisplayRefreshDoesNotRunCallback() async {
        await checkOnFocusChangedCallbacks_nonCancellable()
        config.onFocusedMonitorChanged = parseCommand("echo -- unexpected-callback").cmdOrDie
        let io = CmdIoImpl(stdin: .emptyStdin)
        let displayId = globalFocus.workspace.workspaceMonitorInfo.physicalDisplayId

        let result = await onFocusedMonitorChangedIfNeeded(
            previousDisplayId: displayId,
            currentDisplayId: displayId,
            .defaultEnv, io, globalFocus,
        )

        #expect(result.rawValue == 0)
        #expect(io.stdout.isEmpty)
    }

    @Test func crossDisplayCallbackWorksForEmptyWorkspace() async {
        await checkOnFocusChangedCallbacks_nonCancellable()
        config.onFocusedMonitorChanged = parseCommand("echo -- %{workspace}").cmdOrDie
        let target = Workspace.get(byName: "empty-target")
        let io = CmdIoImpl(stdin: .emptyStdin)

        _ = await onFocusedMonitorChangedIfNeeded(
            previousDisplayId: "another-physical-display",
            currentDisplayId: target.workspaceMonitorInfo.physicalDisplayId,
            .defaultEnv, io, target.toLiveFocus(),
        )

        #expect(io.stdout == [target.name])
    }
}
