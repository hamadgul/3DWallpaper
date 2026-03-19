import XCTest
@testable import WallpaperApp

final class WallpaperLayerTests: XCTestCase {

    func test_layers_sortedByDepthAscending() {
        let layers = [
            WallpaperLayer(imageName: "sky", depth: 10.0, parallaxScale: 0.2),
            WallpaperLayer(imageName: "mid", depth:  5.0, parallaxScale: 0.5),
            WallpaperLayer(imageName: "fg",  depth:  1.0, parallaxScale: 1.0),
        ]
        let sorted = layers.sorted()
        XCTAssertEqual(sorted.map(\.imageName), ["fg", "mid", "sky"])
    }

    func test_defaultParallaxScale_clampedToValidRange() {
        let layer = WallpaperLayer(imageName: "x", depth: 5, parallaxScale: 3.0)
        XCTAssertLessThanOrEqual(layer.parallaxScale, 1.0)
    }

    func test_negativeparallaxScale_clampedToZero() {
        let layer = WallpaperLayer(imageName: "x", depth: 5, parallaxScale: -0.5)
        XCTAssertGreaterThanOrEqual(layer.parallaxScale, 0.0)
    }
}
