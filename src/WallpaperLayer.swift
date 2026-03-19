import Foundation

public struct WallpaperLayer: Comparable {
    public let imageName: String
    /// Distance from camera. Larger = farther away.
    public let depth: Double
    /// How much this layer moves per unit of head offset (0–1). Closer layers move more.
    public let parallaxScale: Double

    public init(imageName: String, depth: Double, parallaxScale: Double) {
        self.imageName     = imageName
        self.depth         = depth
        self.parallaxScale = min(max(parallaxScale, 0), 1)
    }

    public static func < (lhs: WallpaperLayer, rhs: WallpaperLayer) -> Bool {
        lhs.depth < rhs.depth  // ascending: foreground first
    }
}
