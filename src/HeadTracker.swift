import AVFoundation
import Vision

public protocol HeadTrackerDelegate: AnyObject {
    /// Called on an arbitrary background queue.
    func headTracker(_ tracker: HeadTracker, didDetectPosition position: CGPoint)
    func headTrackerDidLoseFace(_ tracker: HeadTracker)
}

public final class HeadTracker {
    public weak var delegate: HeadTrackerDelegate?

    private lazy var request = VNDetectFaceRectanglesRequest(completionHandler: handleResults)
    private let requestHandler = VNSequenceRequestHandler()

    public init() {}

    // MARK: - Public

    public func process(sampleBuffer: CMSampleBuffer) {
        try? requestHandler.perform([request], on: sampleBuffer,
                                    orientation: .upMirrored)
    }

    // MARK: - Internal (static so tests can call without AVFoundation hardware)

    public static func centerPoint(from boundingBox: CGRect) -> CGPoint {
        CGPoint(
            x: boundingBox.midX,
            y: 1.0 - boundingBox.midY   // flip Vision's bottom-left origin to top-left
        )
    }

    // MARK: - Private

    private func handleResults(request: VNRequest, error: Error?) {
        guard
            let results = request.results as? [VNFaceObservation],
            let face = results.first   // largest face only (single-person constraint)
        else {
            delegate?.headTrackerDidLoseFace(self)
            return
        }
        let point = Self.centerPoint(from: face.boundingBox)
        delegate?.headTracker(self, didDetectPosition: point)
    }
}
