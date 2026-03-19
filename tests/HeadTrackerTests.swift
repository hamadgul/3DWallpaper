import XCTest
import CoreGraphics
@testable import WallpaperApp

final class HeadTrackerTests: XCTestCase {

    /// Vision bounding boxes use bottom-left origin. We flip Y for screen coords (top-left origin).
    func test_centerPoint_flipsY() {
        // Box at x:0.4, y:0.3 size 0.2x0.2
        // Center in Vision: (0.5, 0.4)
        // After Y-flip: y = 1 - 0.4 = 0.6
        let box = CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.2)
        let point = HeadTracker.centerPoint(from: box)
        XCTAssertEqual(point.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(point.y, 0.6, accuracy: 0.001)
    }

    func test_centerPoint_fullFrame_returnsCenter() {
        let box = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let point = HeadTracker.centerPoint(from: box)
        XCTAssertEqual(point.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(point.y, 0.5, accuracy: 0.001)  // 1 - 0.5 = 0.5
    }
}
