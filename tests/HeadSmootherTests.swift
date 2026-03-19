import XCTest
import CoreGraphics
@testable import WallpaperApp

final class HeadSmootherTests: XCTestCase {

    func test_firstUpdate_returnsInput() {
        let smoother = HeadSmoother(alpha: 0.5)
        let result = smoother.update(CGPoint(x: 0.8, y: 0.3))
        XCTAssertEqual(result.x, 0.8, accuracy: 0.001)
        XCTAssertEqual(result.y, 0.3, accuracy: 0.001)
    }

    func test_subsequentUpdates_blendTowardNewValue() {
        let smoother = HeadSmoother(alpha: 0.5)
        _ = smoother.update(CGPoint(x: 0.0, y: 0.0))
        let result = smoother.update(CGPoint(x: 1.0, y: 1.0))
        // EMA: 0.0 * (1-0.5) + 1.0 * 0.5 = 0.5
        XCTAssertEqual(result.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(result.y, 0.5, accuracy: 0.001)
    }

    func test_reset_clearsState() {
        let smoother = HeadSmoother(alpha: 0.5)
        _ = smoother.update(CGPoint(x: 1.0, y: 1.0))
        smoother.reset()
        let result = smoother.update(CGPoint(x: 0.2, y: 0.2))
        XCTAssertEqual(result.x, 0.2, accuracy: 0.001)
        XCTAssertEqual(result.y, 0.2, accuracy: 0.001)
    }

    func test_alphaClampedToZeroOne() {
        let smoother = HeadSmoother(alpha: 5.0)  // should clamp to 1.0
        _ = smoother.update(CGPoint(x: 0.0, y: 0.0))
        let result = smoother.update(CGPoint(x: 1.0, y: 1.0))
        // alpha=1.0 → fully adopts new value
        XCTAssertEqual(result.x, 1.0, accuracy: 0.001)
    }
}
