# Code Context

## Files Retrieved
1. `Sources/AppBundle/tree/TreeNode.swift` (lines 1-162) - base mutable tree node, binding/unbinding, MRU, weights, layout rect caches.
2. `Sources/AppBundle/tree/Workspace.swift` (lines 1-221) - workspace registry, visible-workspace-to-monitor mapping, workspace monitor assignment/rearrangement.
3. `Sources/AppBundle/tree/Window.swift` (lines 1-71) - abstract window leaf model and layout reason/native AX surface.
4. `Sources/AppBundle/tree/MacApp.swift` (lines 1-440) - per-app AX thread, AX subscriptions, app/window discovery, frame/focus/native state AX operations.
5. `Sources/AppBundle/tree/MacWindow.swift` (lines 1-369) - concrete window registration, initial parent selection, GC, native focus/AX adapters, detected-window callbacks.
6. `Sources/AppBundle/layout/refresh.swift` (lines 1-210) - heavy/light refresh sessions, model refresh, app/window GC/registration, layout orchestration.
7. `Sources/AppBundle/layout/layoutRecursive.swift` (lines 1-176) - workspace recursive tiling/floating/fullscreen layout and AX frame application.
8. `Sources/AppBundle/focus.swift` (lines 1-196) - global focus model, frozen/live focus conversion, workspace activation, focus/workspace/monitor change callbacks.
9. `Sources/AppBundle/focusCache.swift` (lines 1-15) - sync native macOS focused window into AeroSpace focus cache.
10. `Sources/AppBundle/GlobalObserver.swift` (lines 1-79) - NSWorkspace/global mouse observers that schedule refresh/light sessions.
11. `Sources/AppBundle/initAppBundle.swift` (lines 1-112) - startup lifecycle: config, monitor assignment, observers, initial refresh/session.
12. `Sources/AppBundle/model/Monitor.swift` (lines 1-115) - monitor abstraction over NSScreen plus normalized coordinates and sorted monitor list.
13. `Sources/AppBundle/tree/TreeNodeEx.swift` (lines 1-112) - recursive tree helpers: workspace/monitor resolution, MRU/leaf lookup, resize traversal.
14. `Sources/AppBundle/tree/TreeNodeCases.swift` (lines 1-221) - tree case taxonomy and legal child-parent relations.
15. `Sources/AppBundle/mouse/moveWithMouse.swift` (lines 1-102) - AX moved notifications, light sessions, mouse-driven rebind/swap.
16. `Sources/AppBundle/mouse/resizeWithMouse.swift` (lines 1-88) - AX resized notifications, light sessions, adaptive weight updates.
17. `Sources/Common/util/commonUtil.swift` (lines 87-123) - `RefreshSessionEvent` enum and startup/focus-follows-mouse flags.

## Key Code

- Tree identity/mutation is centralized in `TreeNode.bind`/`unbindFromParent` (`TreeNode.swift` lines 68-126). Binding validates parent-child relation, inserts into parent children, updates adaptive weight, clears unbound stacktrace, and propagates MRU.
- Legal topology is explicit in `TreeNodeCases.swift` lines 156-221. Important constraints: `Workspace` cannot be child of anything meaningful; `Window` cannot be direct child of `Workspace`; root tiling container, floating/fullscreen/hidden containers are shim children of workspace; popup/minimized containers are separate global/unconventional places.
- Workspaces are singleton-like by name (`Workspace.get`, lines 31-49). Visibility is not tree-derived; it is tracked by `visibleWorkspaceToScreenPoint` and `screenPointToVisibleWorkspace` (`Workspace.swift` lines 91-105, 126-153).
- Monitor assignment flow: `Monitor.activeWorkspace` (`Workspace.swift` lines 107-119) reads visible mapping and calls `rearrangeWorkspacesOnMonitors` on cache mismatch. `applyWorkspaceToMonitorAssignmentsOnConnect` (`Workspace.swift` lines 194-204) uses config assignment to set `assignedMonitorPoint` and possibly activate the workspace on target monitor. Forced assignment is in `WorkspaceEx.swift` lines 42-48.
- `MacApp` owns per-process AX state and a dedicated run-loop thread (`MacApp.swift` lines 6-37, 50-110). It subscribes app notifications to `refreshObs`; each `AxWindow` subscribes destroyed/miniaturized to `refreshObs`, moved to `movedObs`, resized to `resizedObs` (`MacApp.swift` lines 372-391).
- Window discovery is two-stage: `MacApp.refreshAllAndGetAliveWindowIds` scans running apps and AX windows (`MacApp.swift` lines 262-334); `refresh()` registers missing IDs via `MacWindow.getOrRegister` (`refresh.swift` lines 124-139).
- `MacWindow.getOrRegister` chooses initial workspace as startup monitor under cursor/rect monitor active workspace or current focus workspace, classifies AX type, binds to popup/floating/tiling, inserts into `allWindowsMap`, then restores closed-window cache or runs on-window-detected callbacks (`MacWindow.swift` lines 13-56, 235-264, 266-297).
- Refresh sessions:
  - Heavy: `scheduleCancellableCompleteRefreshSession` cancels prior task and runs `runHeavyCompleteRefreshSession` (`refresh.swift` lines 4-55). Heavy session pulls native focus, updates focus cache, optionally prelayouts, refreshes model, scans AX, GCs monitors, normalizes layout reasons, layouts workspaces.
  - Light: `runLightSession` (`refresh.swift` lines 58-91) cancels heavy refresh, syncs native focus, refreshes model before/after caller body, layouts, native-focuses changed focus, and schedules a follow-up heavy refresh unless focus-follows-mouse.
- Layout: `Workspace.layoutWorkspace` uses `workspaceMonitor.visibleRectPaddedByOuterGaps` (`layoutRecursive.swift` lines 3-12). Recursive layout writes last-applied rect caches, applies AX frame for windows, handles floating windows separately, and skips unconventional containers (`layoutRecursive.swift` lines 14-57). Tiling weights are normalized per parent orientation before child recursion (`layoutRecursive.swift` lines 102-139).
- Focus: global focus is stored as `FrozenFocus` (`focus.swift` lines 31-56) and exposed as live objects. `setFocus` updates active workspace on the target workspace monitor and MRU (`focus.swift` lines 63-75). `updateFocusCache` syncs macOS native focus into AeroSpace unless focused window is a popup (`focusCache.swift` lines 1-15). Callbacks are emitted in `checkOnFocusChangedCallbacks_nonCancellable` (`focus.swift` lines 119-164).

## Architecture

AeroSpace maintains an in-memory tree model on the main actor. `Workspace` nodes are roots for conventional trees and own lazily-created root tiling and shim containers. `Window` leaves represent AX windows; `MacWindow` is the runtime implementation and delegates native operations to its owning `MacApp`. `MacApp` isolates AX calls on a per-app thread and mirrors AX window IDs in a thread-guarded map.

The model is refreshed from macOS events, not continuously. NSWorkspace notifications, AX app/window notifications, and mouse events schedule heavy or light sessions. Heavy sessions reconcile the whole AX world: register/destroy apps and windows, update workspace GC, normalize containers/layout reasons, then apply layout. Light sessions wrap command/mouse mutations with before/after model refresh and usually schedule a follow-up heavy reconciliation.

Monitor membership is indirect. A workspace's monitor comes from forced config assignment, current visible mapping, remembered assigned point, or main monitor fallback. Active workspace per monitor is keyed by monitor top-left point. Display reconfiguration triggers `rearrangeWorkspacesOnMonitors`, which maps old screen points to nearest new screen points, applies connect assignments, then fills every monitor with an existing or stub workspace.

Layout is a projection from tree + monitor geometry to AX frames. Visible workspaces are unhidden and laid out first; invisible workspaces have windows hidden in an off-screen-ish monitor corner. Tiling containers split virtual/physical rects by weights and gaps. Floating windows preserve proportional position when moved between monitors/workspaces.

Focus is separate from native macOS focus but synchronized at session boundaries. Native focus is read through frontmost app's AX focused window, then `updateFocusCache` updates AeroSpace focus and per-app `lastNativeFocusedWindowId`. Commands/mutations call `setFocus`; after light sessions, if AeroSpace focus changed, `nativeFocus()` pushes focus back to macOS.

## Start Here

Open `Sources/AppBundle/layout/refresh.swift` first. It is the lifecycle hub that connects native event scheduling, focus sync, model reconciliation, workspace/monitor GC, and layout. Then follow into `MacApp.refreshAllAndGetAliveWindowIds` and `MacWindow.getOrRegister` for model creation, and `Workspace.swift` for monitor assignment.

## Constraints, Risks, Open Questions

- Almost all model mutation is `@MainActor`; AX calls are bridged to per-app threads. Avoid introducing off-main mutation of `TreeNode`, `Workspace`, `MacWindow.allWindowsMap`, or focus globals.
- `Window.get(byId:)` uses `MacWindow.allWindowsMap` outside tests, so any new window-like model must keep that registry coherent.
- Visibility is monitor-point mapping, not tree placement. Changing workspace monitor semantics must update `screenPointToVisibleWorkspace`, `visibleWorkspaceToScreenPoint`, `assignedMonitorPoint`, and force assignment behavior together.
- Refresh cancellation is expected only for cancellable heavy sessions. Non-cancellable startup session must preserve `isStartup` semantics.
- Layout uses `lastAppliedLayoutPhysicalRect`/`VirtualRect` for mouse move/resize and focus-follows-mouse. Any layout change should preserve these caches.
- `MacWindow.getOrRegister` has startup vs non-startup behavior and special cross-workspace floating behavior; changes here can affect on-window-detected callbacks and closed-window-cache restoration.
- Popup/minimized/fullscreen/hidden containers intentionally do not participate in normal layout/focus in several places.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Scouted requested AppBundle model/lifecycle areas only and wrote implementation-oriented notes to appbundle_model_scout.md."
    }
  ],
  "changedFiles": [
    "appbundle_model_scout.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "find Sources -path '**/*.swift' and targeted grep/read inspections",
      "result": "passed",
      "summary": "Located and read relevant AppBundle/Common source files."
    },
    {
      "command": "git status --short",
      "result": "passed",
      "summary": "No pre-existing tracked changes reported before writing scout output."
    }
  ],
  "validationOutput": [
    "Scout report written to /Users/<username>/AeroSpace/appbundle_model_scout.md"
  ],
  "residualRisks": [
    "Progress file update was blocked by tool access outside working directory."
  ],
  "noStagedFiles": true,
  "diffSummary": "Added scout findings markdown only.",
  "reviewFindings": [
    "no blockers"
  ],
  "manualNotes": "No source implementation changes were made; this was a code-context scouting task."
}
```
