import AppKit
import SceneKit

public final class DesktopWindowController: NSWindowController {

    // MARK: - Dependencies
    private var parallaxScene: ParallaxScene?
    private var scnView: SCNView?
    private let controller  = ParallaxController()
    private let smoother    = HeadSmoother(alpha: 0.12)
    private let headTracker = HeadTracker()
    private let camera      = CameraManager()
    private let autoPause   = AutoPauseManager()
    private var faceLossCount = 0
    private let faceLossThreshold = 8    // ~0.5s at 15fps before snapping to center
    private var currentSize: CGSize = .zero

    // MARK: - Init

    public convenience init() {
        let screen = DesktopWindowController.targetScreen()
        let window = DesktopWindowController.makeDesktopWindow(for: screen)
        self.init(window: window)
        currentSize = screen.frame.size
        buildScene(for: screen)
        startTracking()
    }

    public override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    /// Called by AppDelegate when any setting changes.
    public func applySettings() {
        controller.sensitivity = AppSettings.shared.sensitivity
        parallaxScene?.fieldOfView    = AppSettings.shared.fieldOfView
        parallaxScene?.depthIntensity = AppSettings.shared.depthIntensity

        // If the user changed portal or monitor, rebuild
        rebuildIfNeeded()
    }

    // MARK: - Private: window

    private static func targetScreen() -> NSScreen {
        if let name = AppSettings.shared.targetDisplayName {
            return NSScreen.screens.first { $0.localizedName == name } ?? NSScreen.main ?? NSScreen.screens[0]
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    private static func makeDesktopWindow(for screen: NSScreen) -> NSWindow {
        let w = NSWindow(
            contentRect: screen.frame,
            styleMask:   .borderless,
            backing:     .buffered,
            defer:       false
        )
        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.isOpaque = true
        w.backgroundColor = .black
        w.ignoresMouseEvents = true
        return w
    }

    // MARK: - Private: scene

    private func buildScene(for screen: NSScreen) {
        let size = screen.frame.size
        currentSize = size

        let portal = Portal(rawValue: AppSettings.shared.selectedPortal) ?? .cosmos
        let scene  = ParallaxScene(scene: portal.makeScene(), sceneSize: size)
        scene.fieldOfView    = AppSettings.shared.fieldOfView
        scene.depthIntensity = AppSettings.shared.depthIntensity
        parallaxScene = scene

        let view = SCNView(frame: NSRect(origin: .zero, size: size))
        view.scene                    = scene.scene
        view.allowsCameraControl      = false
        view.antialiasingMode         = .multisampling4X
        view.preferredFramesPerSecond = 60
        window?.contentView = view
        scnView = view
    }

    private func rebuildIfNeeded() {
        let screen = DesktopWindowController.targetScreen()
        // Move window if monitor changed
        if window?.frame != screen.frame {
            window?.setFrame(screen.frame, display: true)
            buildScene(for: screen)
        } else {
            // Just swap portal scene if that changed
            let portal = Portal(rawValue: AppSettings.shared.selectedPortal) ?? .cosmos
            let newScene = ParallaxScene(scene: portal.makeScene(), sceneSize: currentSize)
            newScene.fieldOfView    = AppSettings.shared.fieldOfView
            newScene.depthIntensity = AppSettings.shared.depthIntensity
            parallaxScene = newScene
            scnView?.scene = newScene.scene
        }
        controller.sensitivity = AppSettings.shared.sensitivity
    }

    // MARK: - Private: tracking

    private func startTracking() {
        headTracker.delegate = self
        camera.onFrame = { [weak self] buffer in
            self?.headTracker.process(sampleBuffer: buffer)
        }

        autoPause.onPause  = { [weak self] in self?.camera.stop() }
        autoPause.onResume = { [weak self] in try? self?.camera.start() }
        autoPause.start()

        try? camera.start()
    }
}

// MARK: - HeadTrackerDelegate

extension DesktopWindowController: HeadTrackerDelegate {

    public func headTracker(_ tracker: HeadTracker, didDetectPosition position: CGPoint) {
        faceLossCount = 0
        let smoothed = smoother.update(position)
        let offset   = controller.cameraOffset(for: smoothed)
        DispatchQueue.main.async { [weak self] in
            self?.parallaxScene?.updateCameraOffset(offset)
        }
    }

    public func headTrackerDidLoseFace(_ tracker: HeadTracker) {
        faceLossCount += 1
        guard faceLossCount >= faceLossThreshold else { return }
        DispatchQueue.main.async { [weak self] in
            self?.parallaxScene?.updateCameraOffset(.zero)
        }
    }
}
