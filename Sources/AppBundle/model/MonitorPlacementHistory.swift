/// Session-local placement history. Missing displays must not overwrite remembered placement
/// with the temporary fallback monitor chosen during sleep/disconnection.
struct MonitorPlacementHistory {
    private(set) var knownDisplayIds: Set<String> = []
    private(set) var workspaceDisplayIds: [String: String] = [:]
    private var awaitingDisplay: Set<String> = []

    mutating func observe(workspace: String, displayId: String) {
        if !awaitingDisplay.contains(workspace) {
            workspaceDisplayIds[workspace] = displayId
        }
    }

    mutating func recordExplicitMove(workspace: String, displayId: String) {
        awaitingDisplay.remove(workspace)
        workspaceDisplayIds[workspace] = displayId
    }

    mutating func reconcile(availableDisplayIds: Set<String>) -> Set<String> {
        let newDisplayIds = availableDisplayIds.subtracting(knownDisplayIds)
        knownDisplayIds.formUnion(availableDisplayIds)
        awaitingDisplay = Set(workspaceDisplayIds.compactMap { name, displayId in
            availableDisplayIds.contains(displayId) ? nil : name
        })
        return newDisplayIds
    }
}
