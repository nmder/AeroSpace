import AppKit
import CoreGraphics

func resolveProcessIdentifier(
    reportedPid: pid_t,
    candidatePids: [pid_t],
    isCandidateMatching: (pid_t) -> Bool,
) -> pid_t? {
    if reportedPid != -1 { return reportedPid }

    let matches = Set(candidatePids.filter { $0 > 0 && isCandidateMatching($0) })
    return matches.count == 1 ? matches.first : nil
}

extension NSRunningApplication {
    var idForDebug: String {
        "PID: \(processIdentifier) ID: \(bundleIdentifier ?? executableURL?.description ?? "")"
    }

    /// macOS 27 can report `-1` for wrapped app executables even though WindowServer
    /// associates the app's windows with the real process identifier.
    var resolvedProcessIdentifier: pid_t? {
        if processIdentifier != -1 { return processIdentifier }
        return resolveProcessIdentifier(
            reportedPid: processIdentifier,
            candidatePids: windowServerOwnerPids,
            isCandidateMatching: { candidatePid in
                guard let candidate = NSRunningApplication(processIdentifier: candidatePid) else { return false }
                return hasSameBundleIdentity(as: candidate)
            },
        )
    }

    private var windowServerOwnerPids: [pid_t] {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
        guard let windowInfos = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [CFDictionary] else { return [] }
        return windowInfos.compactMap { info in
            let dict = info as NSDictionary
            guard let rawPid = dict[kCGWindowOwnerPID] else { return nil }
            return ((rawPid as! CFNumber) as NSNumber).int32Value
        }
    }

    private func hasSameBundleIdentity(as candidate: NSRunningApplication) -> Bool {
        guard bundleIdentifier == candidate.bundleIdentifier else { return false }

        if let bundleURL, let candidateBundleURL = candidate.bundleURL {
            return bundleURL.resolvingSymlinksInPath().standardizedFileURL ==
                candidateBundleURL.resolvingSymlinksInPath().standardizedFileURL
        }
        return bundleIdentifier != nil
    }
}
