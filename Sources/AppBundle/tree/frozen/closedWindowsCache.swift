import AppKit
import Common

/// First line of defence against lock screen
///
/// When you lock the screen, all accessibility API becomes unobservable (all attributes become empty, window id
/// becomes nil, etc.) which tricks AeroSpace into thinking that all windows were closed.
/// That's why every time a window dies AeroSpace caches the "entire world" (unless window is already presented in the cache)
/// so that once the screen is unlocked, AeroSpace could restore windows to where they were
@MainActor private var closedWindowsCache = FrozenWorld(monitors: [], windowIds: [])

// Retain membership independently of the latest tree snapshot: AX can lose windows in batches,
// and genuinely new windows can appear before every previously missing window returns.
private struct CachedWindowBinding {
    let workspaceName: String
    let floating: Bool
}

@MainActor private var cachedWindowBindings: [OpaqueWindowId: CachedWindowBinding] = [:]

struct FrozenMonitor: Sendable {
    let visibleWorkspace: String
    let topLeftCorner: Point
    let workspaces: [FrozenWorkspace]

    @MainActor init(_ monitor: Monitor) {
        self.topLeftCorner = monitor.info.rect.topLeftCorner
        self.workspaces = monitor.getWorkspacesContainerOrCreate().children.map { FrozenWorkspace($0 as! Workspace) }
        self.visibleWorkspace = monitor.getWorkspacesContainerOrCreate().getVisibleWorkspaceOrCreate(parent: monitor).name
    }
}

struct FrozenWorkspace: Sendable {
    let name: String
    let rootTilingNode: FrozenContainer
    let floatingWindows: [FrozenWindow]
    let macosUnconventionalWindows: [FrozenWindow]

    @MainActor init(_ workspace: Workspace) {
        name = workspace.name
        rootTilingNode = FrozenContainer(workspace.rootTilingContainer)
        floatingWindows = workspace.floatingWindows.map(FrozenWindow.init)
        macosUnconventionalWindows =
            workspace.macOsNativeHiddenAppsWindowsContainer.children.map { FrozenWindow($0 as! Window) } +
            workspace.macOsNativeFullscreenWindowsContainer.children.map { FrozenWindow($0 as! Window) }
    }
}

@MainActor func cacheClosedWindowIfNeeded() {
    let allWs = Workspace.all
    let allWindowIds = allWs.flatMap { collectAllWindowIdsRecursive($0) }.toSet()
    if allWindowIds.isSubset(of: closedWindowsCache.windowIds) {
        return // already cached; don't replace the snapshot with a partially detached tree
    }
    for workspace in allWs {
        for window in workspace.allLeafWindowsRecursive {
            cachedWindowBindings[window.windowId] = CachedWindowBinding(
                workspaceName: workspace.name,
                floating: window.isFloating || window.layoutReason == .macos(prevParentKind: .floatingWindowsContainer),
            )
        }
    }
    closedWindowsCache = FrozenWorld(
        monitors: Monitor.all.map(FrozenMonitor.init),
        windowIds: allWindowIds,
    )
}

@MainActor func isWindowInClosedWindowsCache(_ windowId: OpaqueWindowId) -> Bool {
    cachedWindowBindings[windowId] != nil
}

@MainActor func restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: Window) async throws -> Bool {
    if !isWindowInClosedWindowsCache(newlyDetectedWindow.windowId) {
        return false
    }
    let monitors = globalUnsortedMonitorInfos
    let topLeftCornerToMonitorInfo = monitors.grouped { $0.rect.topLeftCorner }
    // Keep references while rebuilding trees, including temporarily detached roots.
    let windowsById = Dictionary(uniqueKeysWithValues: Workspace.all.flatMap(\.allLeafWindowsRecursive).map { ($0.windowId, $0) })

    for monitor in closedWindowsCache.monitors {
        for frozenWorkspace in monitor.workspaces {
            let workspace = Workspace.get(byName: frozenWorkspace.name)
            _ = topLeftCornerToMonitorInfo[monitor.topLeftCorner]?
                .singleOrNil()?
                .bindWorkspace(workspace)
            for frozenWindow in frozenWorkspace.floatingWindows {
                windowsById[frozenWindow.id]?.bindAsFloatingWindow(to: workspace)
            }
            for frozenWindow in frozenWorkspace.macosUnconventionalWindows { // Will get fixed by normalizations
                windowsById[frozenWindow.id]?.bindAsFloatingWindow(to: workspace)
            }
            let prevRoot = workspace.rootTilingContainer // Save prevRoot into a variable to avoid it being garbage collected earlier than needed
            let potentialOrphans = prevRoot.allLeafWindowsRecursive
            prevRoot.unbindFromParent()
            restoreTreeRecursive(frozenContainer: frozenWorkspace.rootTilingNode, parent: workspace, index: INDEX_BIND_LAST, windowsById: windowsById)
            for window in (potentialOrphans - workspace.rootTilingContainer.allLeafWindowsRecursive) {
                try await window.relayoutWindow(on: workspace, .cancellable, forceTile: true)
            }
        }

        _ = topLeftCornerToMonitorInfo[monitor.topLeftCorner]?
            .singleOrNil()?
            .setVisibleWorkspace(Workspace.get(byName: monitor.visibleWorkspace))
    }

    // The latest tree may omit windows lost in an earlier AX refresh. Restore their membership
    // as well, and correct any temporary binding to the focused workspace during rediscovery.
    for (id, binding) in cachedWindowBindings {
        guard let window = windowsById[id] else { continue }
        let workspace = Workspace.get(byName: binding.workspaceName)
        if window.nodeWorkspace != workspace {
            if binding.floating {
                window.bindAsFloatingWindow(to: workspace)
            } else {
                window.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
            }
        }
    }
    return true
}

@discardableResult
@MainActor
private func restoreTreeRecursive(
    frozenContainer: FrozenContainer,
    parent: NonLeafTreeNodeObject,
    index: Int,
    windowsById: [OpaqueWindowId: Window],
) -> Bool {
    let container = TilingContainer(
        parent: parent,
        adaptiveWeight: frozenContainer.weight,
        frozenContainer.orientation,
        frozenContainer.layout,
        index: index,
    )

    for child in frozenContainer.children {
        switch child {
            case .window(let w):
                // Missing siblings may return later. Restore all available windows in snapshot
                // order instead of leaving the remainder on the focused workspace.
                guard let window = windowsById[w.id] else { continue }
                window.bind(to: container, adaptiveWeight: w.weight, index: INDEX_BIND_LAST)
            case .container(let c):
                restoreTreeRecursive(frozenContainer: c, parent: container, index: INDEX_BIND_LAST, windowsById: windowsById)
        }
    }
    return true
}

// Consider the following case:
// 1. Close window
// 2. The previous step lead to caching the whole world
// 3. Change something in the layout
// 4. Lock the screen
// 5. The cache won't be updated because all alive windows are already cached
// 6. Unlock the screen
// 7. The wrong cache is used
//
// That's why we have to reset the cache every time layout changes. The layout can only be changed by running commands
// and with mouse manipulations
@MainActor func resetClosedWindowsCache() {
    closedWindowsCache = FrozenWorld(monitors: [], windowIds: [])
    cachedWindowBindings = [:]
}
