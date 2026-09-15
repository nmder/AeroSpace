@testable import AppBundle
import XCTest

final class NSRunningApplicationExTest: XCTestCase {
    func testKeepsValidReportedPidWithoutConsultingCandidates() {
        var matcherWasCalled = false
        let result = resolveProcessIdentifier(reportedPid: 42, candidatePids: [100]) { _ in
            matcherWasCalled = true
            return true
        }

        assertEquals(result, 42)
        assertFalse(matcherWasCalled)
    }

    func testResolvesMinusOneToUniqueMatchingWindowOwnerPid() {
        let result = resolveProcessIdentifier(reportedPid: -1, candidatePids: [100, 200, 200]) { $0 == 200 }
        assertEquals(result, 200)
    }

    func testIgnoresInvalidCandidatePids() {
        let result = resolveProcessIdentifier(reportedPid: -1, candidatePids: [-1, 0, 200]) { _ in true }
        assertEquals(result, 200)
    }

    func testReturnsNilWithoutMatchingWindowOwnerPid() {
        let result = resolveProcessIdentifier(reportedPid: -1, candidatePids: [100, 200]) { _ in false }
        assertNil(result)
    }

    func testReturnsNilForAmbiguousMatchingWindowOwnerPids() {
        let result = resolveProcessIdentifier(reportedPid: -1, candidatePids: [100, 200]) { _ in true }
        assertNil(result)
    }
}
