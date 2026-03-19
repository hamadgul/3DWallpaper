import XCTest
import CoreGraphics
@testable import WallpaperApp

final class ParallaxControllerTests: XCTestCase {

    func test_headAtCenter_producesZeroOffset() {
        let controller = ParallaxController(sensitivity: 5.0)
        let offset = controller.cameraOffset(for: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(offset.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(offset.y, 0.0, accuracy: 0.001)
    }

    func test_headMovesLeft_offsetIsNegativeX() {
        // Head at x=0.2 (left of center). Camera shifts left → negative X.
        let controller = ParallaxController(sensitivity: 10.0)
        let offset = controller.cameraOffset(for: CGPoint(x: 0.2, y: 0.5))
        XCTAssertLessThan(offset.x, 0.0)
    }

    func test_sensitivityScalesOffset() {
        let low  = ParallaxController(sensitivity: 2.0)
        let high = ParallaxController(sensitivity: 8.0)
        let pos  = CGPoint(x: 0.8, y: 0.5)
        XCTAssertGreaterThan(abs(high.cameraOffset(for: pos).x),
                             abs(low.cameraOffset(for: pos).x))
    }

    func test_proportionalMapping_preservesDistance() {
        // Spec: exact direction and distance — 3x displacement = 3x offset
        let controller = ParallaxController(sensitivity: 10.0)
        let small = controller.cameraOffset(for: CGPoint(x: 0.6, y: 0.5))  // 0.1 from center
        let large = controller.cameraOffset(for: CGPoint(x: 0.8, y: 0.5))  // 0.3 from center
        XCTAssertEqual(abs(large.x) / abs(small.x), 3.0, accuracy: 0.01)
    }
}
