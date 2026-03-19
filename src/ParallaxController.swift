import CoreGraphics

/// Maps normalized head position to scene-unit camera offset.
/// Mapping is strictly linear: 2x head displacement = 2x camera displacement.
/// sensitivity scales magnitude; direction is always preserved.
public final class ParallaxController {
    public var sensitivity: Double

    public init(sensitivity: Double = 5.0) {
        self.sensitivity = sensitivity
    }

    /// - Parameter headPosition: Normalized (0–1, origin top-left)
    /// - Returns: Scene-unit camera offset. Head left → camera left (scene shifts right).
    public func cameraOffset(for headPosition: CGPoint) -> CGPoint {
        CGPoint(
            x:  (headPosition.x - 0.5) * sensitivity,
            y: -(headPosition.y - 0.5) * sensitivity   // Y inverted: head up → camera up
        )
    }
}
