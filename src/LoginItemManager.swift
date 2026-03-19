import ServiceManagement

/// Manages launch-at-login registration using SMAppService (macOS 13+).
/// Requires the app to be a properly signed app bundle to work at runtime,
/// but the API compiles fine in SPM for development.
public enum LoginItemManager {

    /// Register or unregister this app as a login item.
    /// Silently logs if the user has denied access via System Settings.
    public static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // SMAppService throws if the user denied via System Settings → Privacy & Security.
            // We surface this via the system log only — do not crash.
            print("[LoginItem] \(enabled ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
    }

    /// Reflects actual SMAppService status (not just the stored pref).
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
