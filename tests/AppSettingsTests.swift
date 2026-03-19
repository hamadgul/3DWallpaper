import XCTest
@testable import WallpaperApp

final class AppSettingsTests: XCTestCase {

    var settings: AppSettings!

    override func setUp() {
        // Use ephemeral suite so tests don't pollute real prefs
        settings = AppSettings(suiteName: "test-\(UUID().uuidString)")
    }

    func test_sensitivity_defaultValue() {
        XCTAssertEqual(settings.sensitivity, 10.0, accuracy: 0.001)
    }

    func test_sensitivity_persistsRoundTrip() {
        settings.sensitivity = 11.5
        XCTAssertEqual(settings.sensitivity, 11.5, accuracy: 0.001)
    }

    func test_fieldOfView_defaultIs60() {
        XCTAssertEqual(settings.fieldOfView, 60.0, accuracy: 0.001)
    }

    func test_fieldOfView_clampedToMaximum() {
        settings.fieldOfView = 200
        XCTAssertLessThanOrEqual(settings.fieldOfView, 120)
    }

    func test_fieldOfView_clampedToMinimum() {
        settings.fieldOfView = 5
        XCTAssertGreaterThanOrEqual(settings.fieldOfView, 30)
    }

    func test_depthIntensity_defaultIsOne() {
        XCTAssertEqual(settings.depthIntensity, 1.0, accuracy: 0.001)
    }

    func test_depthIntensity_clampedToZero() {
        settings.depthIntensity = -1
        XCTAssertGreaterThanOrEqual(settings.depthIntensity, 0)
    }

    func test_selectedPortal_defaultIsCosmos() {
        XCTAssertEqual(settings.selectedPortal, "Cosmos")
    }

    func test_launchAtLogin_defaultIsFalse() {
        XCTAssertFalse(settings.launchAtLogin)
    }
}
