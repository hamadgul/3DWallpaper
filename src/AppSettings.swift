import Foundation

public final class AppSettings {
    public static var shared = AppSettings()

    private let defaults: UserDefaults

    public init(suiteName: String = "com.3dwallpaper.prefs") {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    /// 1–15, default 6.
    public var sensitivity: Double {
        get { defaults.double(forKey: "sensitivity").nonZero(default: 6.0) }
        set { defaults.set(newValue, forKey: "sensitivity") }
    }

    /// 30–120 degrees, default 60.
    public var fieldOfView: Double {
        get { min(max(defaults.double(forKey: "fov").nonZero(default: 60), 30), 120) }
        set { defaults.set(min(max(newValue, 30), 120), forKey: "fov") }
    }

    /// 0–1, default 1.
    public var depthIntensity: Double {
        get { min(max(defaults.double(forKey: "depthIntensity").nonZero(default: 1.0), 0), 1) }
        set { defaults.set(min(max(newValue, 0), 1), forKey: "depthIntensity") }
    }

    /// NSScreen.localizedName of the chosen display, nil = primary.
    public var targetDisplayName: String? {
        get { defaults.string(forKey: "targetDisplay") }
        set { defaults.set(newValue, forKey: "targetDisplay") }
    }

    /// Portal.rawValue, default "Cosmos".
    public var selectedPortal: String {
        get { defaults.string(forKey: "portal") ?? "Cosmos" }
        set { defaults.set(newValue, forKey: "portal") }
    }

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }
}

private extension Double {
    func nonZero(default value: Double) -> Double { self == 0 ? value : self }
}
