import CoreGraphics

/// Exponential moving average filter to smooth noisy head-position input.
/// alpha: weight given to new sample (0 = ignore new, 1 = no smoothing).
public final class HeadSmoother {
    private let alpha: Double
    private var current: CGPoint?

    public init(alpha: Double = 0.15) {
        self.alpha = min(max(alpha, 0), 1)
    }

    public func update(_ point: CGPoint) -> CGPoint {
        guard let prev = current else {
            current = point
            return point
        }
        let smoothed = CGPoint(
            x: prev.x * (1 - alpha) + point.x * alpha,
            y: prev.y * (1 - alpha) + point.y * alpha
        )
        current = smoothed
        return smoothed
    }

    public func reset() { current = nil }
}
