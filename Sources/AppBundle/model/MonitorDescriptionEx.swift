import Common

extension WorkspaceToMonitorAssignmentOnConnect {
    @MainActor func resolveMonitor(sortedMonitors: [MonitorInfo]) -> MonitorInfo? {
        guard let candidate = target.resolveMonitor(sortedMonitors: sortedMonitors) else { return nil }
        if let largerThan {
            guard let compared = largerThan.resolveMonitor(sortedMonitors: sortedMonitors),
                  candidate.rect.area > compared.rect.area
            else { return nil }
        }
        if let smallerThan {
            guard let compared = smallerThan.resolveMonitor(sortedMonitors: sortedMonitors),
                  candidate.rect.area < compared.rect.area
            else { return nil }
        }
        return candidate
    }
}

extension [MonitorDescription] {
    @MainActor func resolveMonitor(sortedMonitors: [MonitorInfo]) -> MonitorInfo? {
        lazy.compactMap { $0.resolveMonitor(sortedMonitors: sortedMonitors) }.first
    }
}

extension MonitorDescription {
    @MainActor func resolveMonitor(sortedMonitors: [MonitorInfo]) -> MonitorInfo? {
        switch self {
            case .sequenceNumber(let number): sortedMonitors.getOrNil(atIndex: number - 1)
            case .main: mainMonitorInfo
            case .pattern(let regex): sortedMonitors.first { $0.name.contains(caseInsensitiveRegex: regex) }
            case .secondary:
                sortedMonitors.takeIf { $0.count == 2 }?
                    .first { $0.rect.topLeftCorner != mainMonitorInfo.rect.topLeftCorner }
        }
    }
}
