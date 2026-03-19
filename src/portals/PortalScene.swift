import SceneKit

public enum Portal: String, CaseIterable {
    case cosmos       = "Cosmos"
    case midnightCity = "Midnight City"
    case abyss        = "Abyss"

    public func makeScene() -> SCNScene {
        switch self {
        case .cosmos:       return CosmosPortal.makeScene()
        case .midnightCity: return MidnightCityPortal.makeScene()
        case .abyss:        return AbyssPortal.makeScene()
        }
    }

    public var defaultSensitivity: Double {
        switch self {
        case .cosmos:       return 5.0
        case .midnightCity: return 7.0
        case .abyss:        return 6.0
        }
    }
}
