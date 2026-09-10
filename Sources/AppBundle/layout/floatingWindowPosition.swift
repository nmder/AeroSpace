import AppKit

func floatingWindowTargetTopLeft(windowRect: Rect, sourceMonitorRect: Rect, targetMonitorRect: Rect) -> CGPoint {
    let xProportion = (windowRect.topLeftX - sourceMonitorRect.topLeftX) / sourceMonitorRect.width
    let yProportion = (windowRect.topLeftY - sourceMonitorRect.topLeftY) / sourceMonitorRect.height

    let proportionalX = targetMonitorRect.topLeftX + xProportion * targetMonitorRect.width
    let proportionalY = targetMonitorRect.topLeftY + yProportion * targetMonitorRect.height
    let maxX = max(targetMonitorRect.minX, targetMonitorRect.maxX - windowRect.width)
    let maxY = max(targetMonitorRect.minY, targetMonitorRect.maxY - windowRect.height)

    return CGPoint(
        x: proportionalX.coerce(in: targetMonitorRect.minX ... maxX),
        y: proportionalY.coerce(in: targetMonitorRect.minY ... maxY),
    )
}
