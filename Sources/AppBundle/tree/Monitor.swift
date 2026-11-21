import AppKit
import Common

@MainActor private var pointToMonitor: [Point: Monitor] = [:]
@MainActor private var monitorPlacementHistory = MonitorPlacementHistory()
@MainActor private var lastVisibleWorkspaceByDisplay: [String: String] = [:]

final class Monitor: TreeNode, NonLeafTreeNodeObject {
    fileprivate var _info: MonitorInfo
    var info: MonitorInfo { _info }

    @MainActor fileprivate init(_ info: MonitorInfo) {
        self._info = info
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 0, index: 0)
    }

    override func getWeight(_ targetOrientation: Orientation) -> CGFloat {
        info.visibleRectPaddedByOuterGaps.getDimension(targetOrientation)
    }

    override func setWeight(_ targetOrientation: Orientation, _ newValue: CGFloat) {
        die("It's not possible to change weight of Monitor")
    }

    @MainActor static var all: [Monitor] { Array(pointToMonitor.values) }
}

@MainActor func recordExplicitWorkspaceMonitorMove(_ workspace: Workspace) {
    monitorPlacementHistory.recordExplicitMove(workspace: workspace.name, displayId: workspace.workspaceMonitorInfo.physicalDisplayId)
}

@MainActor private func rearrangeMonitors() {
    let newInfos = globalUnsortedMonitorInfos
    // Display enumeration may briefly be empty during wake. Keep the previous tree intact.
    guard !newInfos.isEmpty else { return }
    let oldMonitors = Array(pointToMonitor.values)
    var oldByDisplay = Dictionary(uniqueKeysWithValues: oldMonitors.map { ($0.info.physicalDisplayId, $0) })
    let previouslyPresentIds = Set(oldByDisplay.keys)
    for monitor in oldMonitors {
        let container = monitor.getWorkspacesContainerOrCreate()
        if let visibleName = container.visibleWorkspaceNameOrStale {
            lastVisibleWorkspaceByDisplay[monitor.info.physicalDisplayId] = visibleName
        }
        for workspace in container.children.filterIsInstance(of: Workspace.self) {
            monitorPlacementHistory.observe(workspace: workspace.name, displayId: monitor.info.physicalDisplayId)
        }
    }

    pointToMonitor = [:]
    for info in newInfos {
        let monitor = oldByDisplay.removeValue(forKey: info.physicalDisplayId) ?? Monitor(info)
        monitor._info = info
        pointToMonitor[info.rect.topLeftCorner] = monitor
    }
    let byDisplay = Dictionary(uniqueKeysWithValues: pointToMonitor.values.map { ($0.info.physicalDisplayId, $0) })
    let presentIds = Set(byDisplay.keys)
    let newDisplayIds = monitorPlacementHistory.reconcile(availableDisplayIds: presentIds)
    let fallback = pointToMonitor[.zero] ?? pointToMonitor.values.first.orDie()

    for disconnectedMonitor in oldByDisplay.values {
        for workspace in disconnectedMonitor.getWorkspacesContainerOrCreate().children.filterIsInstance(of: Workspace.self) {
            // This is a temporary fallback, not a new user-selected placement.
            workspace.bind(to: fallback.getWorkspacesContainerOrCreate(), adaptiveWeight: 1, index: INDEX_BIND_LAST)
        }
    }

    for workspace in Workspace.all {
        guard let displayId = monitorPlacementHistory.workspaceDisplayIds[workspace.name],
              let target = byDisplay[displayId]
        else { continue }
        if workspace.parent !== target.getWorkspacesContainerOrCreate() {
            _ = target.info.bindWorkspace(workspace)
        }
    }
    for displayId in presentIds.subtracting(previouslyPresentIds) {
        guard let name = lastVisibleWorkspaceByDisplay[displayId],
              monitorPlacementHistory.workspaceDisplayIds[name] == displayId,
              let workspace = Workspace.all.first(where: { $0.name == name })
        else { continue }
        _ = byDisplay[displayId]?.info.setVisibleWorkspace(workspace)
    }

    // Geometry/order refreshes and known displays returning from sleep are not new connections.
    // Startup applies all defaults explicitly once configuration has loaded.
    if !previouslyPresentIds.isEmpty && !newDisplayIds.isEmpty {
        applyWorkspaceToMonitorAssignmentsOnConnect(onlyDisplayIds: newDisplayIds)
    }
}

extension MonitorInfo {
    @MainActor var visibleWorkspace: Workspace {
        let monitor = toMonitorOrRearrangeMonitors()
        return monitor.getWorkspacesContainerOrCreate().getVisibleWorkspaceOrCreate(parent: monitor)
    }

    @MainActor func toMonitorOrRearrangeMonitors() -> Monitor {
        if let existing = pointToMonitor[rect.topLeftCorner], existing.info.physicalDisplayId == physicalDisplayId {
            return existing
        }
        rearrangeMonitors()
        return pointToMonitor.values.first(where: { $0.info.physicalDisplayId == physicalDisplayId }).orDie("Display is no longer connected")
    }

    @MainActor func setVisibleWorkspace(_ workspace: Workspace) -> Bool {
        let container = toMonitorOrRearrangeMonitors().getWorkspacesContainerOrCreate()
        return container.setVisibleWorkspace(workspace)
    }

    @MainActor func bindWorkspace(_ workspace: Workspace) -> Bool {
        return toMonitorOrRearrangeMonitors().getWorkspacesContainerOrCreate().bindWorkspace(workspace)
    }
}

@MainActor func gcMonitors() {
    func rectEquals(_ lhs: Rect, _ rhs: Rect) -> Bool {
        lhs.topLeftX == rhs.topLeftX && lhs.topLeftY == rhs.topLeftY &&
            lhs.width == rhs.width && lhs.height == rhs.height
    }

    let newMonitorInfos = globalUnsortedMonitorInfos
    let topologyChanged = pointToMonitor.count != newMonitorInfos.count || newMonitorInfos.contains { newInfo in
        guard let oldInfo = pointToMonitor[newInfo.rect.topLeftCorner]?.info else { return true }
        return oldInfo.physicalDisplayId != newInfo.physicalDisplayId ||
            oldInfo.monitorAppKitNsScreenScreensId != newInfo.monitorAppKitNsScreenScreensId ||
            oldInfo.name != newInfo.name ||
            !rectEquals(oldInfo.rect, newInfo.rect) ||
            !rectEquals(oldInfo.visibleRect, newInfo.visibleRect) ||
            oldInfo.isMain != newInfo.isMain
    }
    if topologyChanged {
        rearrangeMonitors()
    }
}
