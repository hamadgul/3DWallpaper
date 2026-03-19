import AVFoundation

/// Captures webcam frames and delivers them for in-memory processing ONLY.
/// Frames are NEVER written to disk, logged, or transmitted — they go directly
/// to the Vision request handler and are released immediately after.
public final class CameraManager: NSObject {
    public var onFrame: ((CMSampleBuffer) -> Void)?

    private let session = AVCaptureSession()
    private let output  = AVCaptureVideoDataOutput()
    private let queue   = DispatchQueue(label: "com.3dwallpaper.camera", qos: .userInteractive)
    private var frameCount = 0

    private var isConfigured = false

    public override init() { super.init() }

    public func start() throws {
        guard !session.isRunning else { return }

        if !isConfigured {
            session.beginConfiguration()
            defer { session.commitConfiguration() }

            session.sessionPreset = .vga640x480   // low res = fast Vision processing

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                      for: .video, position: .front)
                          ?? AVCaptureDevice.default(for: .video),
                let input  = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else { throw CameraError.noCamera }

            session.addInput(input)
            output.setSampleBufferDelegate(self, queue: queue)
            output.alwaysDiscardsLateVideoFrames = true
            guard session.canAddOutput(output) else { throw CameraError.outputFailed }
            session.addOutput(output)
            isConfigured = true
        }

        session.startRunning()
    }

    public func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
        frameCount = 0
    }

    public enum CameraError: Error { case noCamera, outputFailed }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameCount += 1
        guard frameCount % 2 == 0 else { return }   // throttle to ~15fps
        onFrame?(sampleBuffer)
    }
}
