import XCTest
@testable import WallpaperApp

final class AutoPauseManagerTests: XCTestCase {

    func test_startsUnpaused() {
        let mgr = AutoPauseManager()
        XCTAssertFalse(mgr.isPaused)
    }

    func test_simulatePause_setsFlagTrue() {
        let mgr = AutoPauseManager()
        mgr.simulatePause()
        XCTAssertTrue(mgr.isPaused)
    }

    func test_simulateResume_clearsFlagToFalse() {
        let mgr = AutoPauseManager()
        mgr.simulatePause()
        mgr.simulateResume()
        XCTAssertFalse(mgr.isPaused)
    }

    func test_pauseCallback_invokedOnce() {
        let mgr = AutoPauseManager()
        var count = 0
        mgr.onPause = { count += 1 }
        mgr.simulatePause()
        mgr.simulatePause()  // double-pause should not double-fire
        XCTAssertEqual(count, 1)
    }

    func test_resumeCallback_invokedOnce() {
        let mgr = AutoPauseManager()
        var count = 0
        mgr.onResume = { count += 1 }
        mgr.simulatePause()
        mgr.simulateResume()
        mgr.simulateResume()  // double-resume should not double-fire
        XCTAssertEqual(count, 1)
    }
}
