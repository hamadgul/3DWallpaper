import AppKit

/// Watches NSWorkspace notifications to pause camera tracking automatically
/// when a fullscreen app covers the desktop, and resume when the desktop returns.
/// This also releases the webcam so other apps (FaceTime, Zoom) can use it.
public final class AutoPauseManager {
    public var onPause:  (() -> Void)?
    public var onResume: (() -> Void)?

    public private(set) var isPaused = false

    public init() {}

    // MARK: - Lifecycle

    public func start() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appActivated),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDeactivated),
                       name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(spaceChanged),
                       name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    public func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Test seams (callable in unit tests without real NSWorkspace events)

    public func simulatePause()  { pause() }
    public func simulateResume() { resume() }

    // MARK: - Private

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
        else { return }
        if app.activationPolicy == .regular { pause() }
    }

    @objc private func appDeactivated(_ note: Notification) { resume() }
    @objc private func spaceChanged(_ note: Notification)   { evaluateVisibility() }

    private func evaluateVisibility() {
        if NSWorkspace.shared.frontmostApplication?.activationPolicy == .regular {
            pause()
        } else {
            resume()
        }
    }

    private func pause() {
        guard !isPaused else { return }
        isPaused = true
        onPause?()
    }

    private func resume() {
        guard isPaused else { return }
        isPaused = false
        onResume?()
    }
}
