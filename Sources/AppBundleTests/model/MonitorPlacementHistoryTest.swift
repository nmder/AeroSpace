@testable import AppBundle
import Testing

struct MonitorPlacementHistoryTest {
    @Test func geometryAndOrderRefreshesDoNotCreateNewDisplays() {
        var history = MonitorPlacementHistory()
        #expect(history.reconcile(availableDisplayIds: ["main", "external"]) == ["main", "external"])
        history.observe(workspace: "work", displayId: "external")
        // UUID sets do not change when coordinates, dimensions, or NSScreen order change.
        #expect(history.reconcile(availableDisplayIds: ["external", "main"]).isEmpty)
        #expect(history.workspaceDisplayIds["work"] == "external")
    }

    @Test func sleepFallbackDoesNotReplaceRememberedPlacement() {
        var history = MonitorPlacementHistory()
        _ = history.reconcile(availableDisplayIds: ["main", "external"])
        history.observe(workspace: "work", displayId: "external")
        _ = history.reconcile(availableDisplayIds: ["main"])
        history.observe(workspace: "work", displayId: "main")

        #expect(history.workspaceDisplayIds["work"] == "external")
        #expect(history.reconcile(availableDisplayIds: ["main", "external"]).isEmpty)
        #expect(history.workspaceDisplayIds["work"] == "external")
    }

    @Test func explicitMoveWhileDisplayIsMissingWinsOnReconnect() {
        var history = MonitorPlacementHistory()
        _ = history.reconcile(availableDisplayIds: ["main", "external"])
        history.observe(workspace: "work", displayId: "external")
        _ = history.reconcile(availableDisplayIds: ["main"])
        history.recordExplicitMove(workspace: "work", displayId: "main")
        #expect(history.reconcile(availableDisplayIds: ["main", "external"]).isEmpty)
        #expect(history.workspaceDisplayIds["work"] == "main")
    }

    @Test func manualPlacementBetweenSleepCyclesIsRemembered() {
        var history = MonitorPlacementHistory()
        _ = history.reconcile(availableDisplayIds: ["main", "external"])
        history.observe(workspace: "work", displayId: "main")
        history.recordExplicitMove(workspace: "work", displayId: "external")
        _ = history.reconcile(availableDisplayIds: ["main"])
        history.observe(workspace: "work", displayId: "main")
        _ = history.reconcile(availableDisplayIds: ["main", "external"])
        #expect(history.workspaceDisplayIds["work"] == "external")
    }

    @Test func onlyPreviouslyUnseenDisplayTriggersDefaults() {
        var history = MonitorPlacementHistory()
        _ = history.reconcile(availableDisplayIds: ["main", "external"])
        _ = history.reconcile(availableDisplayIds: ["main"])
        #expect(history.reconcile(availableDisplayIds: ["main", "external", "new"]) == ["new"])
    }
}
