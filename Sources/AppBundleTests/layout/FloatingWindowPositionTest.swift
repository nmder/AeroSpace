@testable import AppBundle
import Testing

@Suite
struct FloatingWindowPositionTest {
    @Test func testPreservesProportionalPosition() {
        let point = floatingWindowTargetTopLeft(
            windowRect: Rect(topLeftX: 480, topLeftY: 270, width: 200, height: 100),
            sourceMonitorRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            targetMonitorRect: Rect(topLeftX: 1920, topLeftY: 25, width: 1280, height: 720),
        )

        #expect(point.x == 2240)
        #expect(point.y == 205)
    }

    @Test func testClampsWindowAtTopLeftVisibleBounds() {
        let point = floatingWindowTargetTopLeft(
            windowRect: Rect(topLeftX: -100, topLeftY: -50, width: 400, height: 300),
            sourceMonitorRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            targetMonitorRect: Rect(topLeftX: 1920, topLeftY: 25, width: 1280, height: 720),
        )

        #expect(point.x == 1920)
        #expect(point.y == 25)
    }

    @Test func testPinsOversizedWindowAtTopLeftVisibleBounds() {
        let point = floatingWindowTargetTopLeft(
            windowRect: Rect(topLeftX: 1700, topLeftY: 900, width: 1600, height: 900),
            sourceMonitorRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            targetMonitorRect: Rect(topLeftX: 1920, topLeftY: 25, width: 1280, height: 720),
        )

        #expect(point.x == 1920)
        #expect(point.y == 25)
    }
}
