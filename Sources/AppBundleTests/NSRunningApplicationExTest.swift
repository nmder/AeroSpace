@testable import AppBundle
import Testing

@Suite
struct NSRunningApplicationExTest {
    @Test func testKeepsValidReportedPidWithoutConsultingCandidates() {
        var matcherWasCalled = false
        let result = resolveProcessIdentifier(reportedPid: 42, candidatePids: [100]) { _ in
            matcherWasCalled = true
            return true
        }

        #expect(result == 42)
        #expect(!matcherWasCalled)
    }

    @Test func testResolvesMinusOneToUniqueMatchingWindowOwnerPid() {
        let result = resolveProcessIdentifier(reportedPid: -1, candidatePids: [100, 200, 200]) { $0 == 200 }
        #expect(result == 200)
    }

    @Test func testIgnoresInvalidCandidatePids() {
        let result = resolveProcessIdentifier(reportedPid: -1, candidatePids: [-1, 0, 200]) { _ in true }
        #expect(result == 200)
    }

    @Test func testReturnsNilWithoutMatchingWindowOwnerPid() {
        let result = resolveProcessIdentifier(reportedPid: -1, candidatePids: [100, 200]) { _ in false }
        #expect(result == nil)
    }

    @Test func testReturnsNilForAmbiguousMatchingWindowOwnerPids() {
        let result = resolveProcessIdentifier(reportedPid: -1, candidatePids: [100, 200]) { _ in true }
        #expect(result == nil)
    }
}
