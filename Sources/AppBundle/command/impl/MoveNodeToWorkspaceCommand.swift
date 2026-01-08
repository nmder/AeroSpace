import Common
import AppKit

struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else { return io.err(noWindowIsFocused) }
        let subjectWs = window.nodeWorkspace
        let targetWorkspace: Workspace
        switch args.target.val {
            case .relative(let nextPrev):
                guard let subjectWs else { return io.err("Window \(window.windowId) doesn't belong to any workspace") }
                let ws = getNextPrevWorkspace(
                    current: subjectWs,
                    isNext: nextPrev == .next,
                    wrapAround: args.wrapAround,
                    stdin: args.useStdin ? io.readStdin() : nil,
                    target: target,
                )
                guard let ws else { return io.err("Can't resolve next or prev workspace") }
                targetWorkspace = ws
            case .direct(let name):
                targetWorkspace = Workspace.get(byName: name.raw)
        }
        return try await moveWindowToWorkspace(window, targetWorkspace, io, focusFollowsWindow: args.focusFollowsWindow, failIfNoop: args.failIfNoop)
    }
}

@MainActor
func moveWindowToWorkspace(_ window: Window, _ targetWorkspace: Workspace, _ io: CmdIo, focusFollowsWindow: Bool,
    failIfNoop: Bool, index: Int = INDEX_BIND_LAST) async throws -> Bool {
    if window.nodeWorkspace == targetWorkspace {
        if !failIfNoop {
            io.err("Window '\(window.windowId)' already belongs to workspace '\(targetWorkspace.name)'. Tip: use --fail-if-noop to exit with non-zero code")
        }
        return !failIfNoop
    }
    let targetContainer: NonLeafTreeNodeObject = window.isFloating ? targetWorkspace : targetWorkspace.rootTilingContainer
    if window.isFloating {
        guard let size = try await window.getAxSize(),
            let topLeft = try await window.getAxTopLeftCorner()
            else { return true }
        let dTopX = max(0,
            topLeft.x - focus.workspace.workspaceMonitor.rect.topLeftX
            + size.width - targetWorkspace.workspaceMonitor.width)
        let dTopY = max(0,
            topLeft.y - focus.workspace.workspaceMonitor.rect.topLeftY
            + size.height - targetWorkspace.workspaceMonitor.height)
        window.setAxFrame(CGPoint(
            x: topLeft.x - focus.workspace.workspaceMonitor.rect.topLeftX
            - dTopX + targetWorkspace.workspaceMonitor.rect.topLeftX,
            y: topLeft.y - focus.workspace.workspaceMonitor.rect.topLeftY
            - dTopY + targetWorkspace.workspaceMonitor.rect.topLeftY),
            nil)
    }
    window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)
    return focusFollowsWindow ? window.focusWindow() : true
}
