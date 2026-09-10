@testable import AppBundle
import XCTest

final class FloatingWindowPositionTest: XCTestCase {
    func testPreservesProportionalPosition() {
        let point = floatingWindowTargetTopLeft(
            windowRect: Rect(topLeftX: 480, topLeftY: 270, width: 200, height: 100),
            sourceMonitorRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            targetMonitorRect: Rect(topLeftX: 1920, topLeftY: 25, width: 1280, height: 720),
        )

        XCTAssertEqual(point.x, 2240)
        XCTAssertEqual(point.y, 205)
    }

    func testClampsWindowAtTopLeftVisibleBounds() {
        let point = floatingWindowTargetTopLeft(
            windowRect: Rect(topLeftX: -100, topLeftY: -50, width: 400, height: 300),
            sourceMonitorRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            targetMonitorRect: Rect(topLeftX: 1920, topLeftY: 25, width: 1280, height: 720),
        )

        XCTAssertEqual(point.x, 1920)
        XCTAssertEqual(point.y, 25)
    }

    func testPinsOversizedWindowAtTopLeftVisibleBounds() {
        let point = floatingWindowTargetTopLeft(
            windowRect: Rect(topLeftX: 1700, topLeftY: 900, width: 1600, height: 900),
            sourceMonitorRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            targetMonitorRect: Rect(topLeftX: 1920, topLeftY: 25, width: 1280, height: 720),
        )

        XCTAssertEqual(point.x, 1920)
        XCTAssertEqual(point.y, 25)
    }
}
