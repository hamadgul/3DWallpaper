import AppKit
import SceneKit

public final class ParallaxScene {
    public let scene: SCNScene
    private let cameraNode: SCNNode
    private var layerNodes: [SCNNode] = []
    private var layerBaseZ: [Float] = []

    public init(scene: SCNScene, sceneSize: CGSize) {
        self.scene      = scene
        self.cameraNode = SCNNode()

        let camera = SCNCamera()
        camera.fieldOfView = 55        // narrower than 60 — more depth compression, cinematic feel
        camera.zNear = 0.1
        camera.zFar  = 500

        // HDR pipeline — required for everything below
        camera.wantsHDR     = true
        camera.exposureOffset = -0.3   // slightly underexpose so bloom highlights pop

        // Bloom — emissive surfaces with emissionIntensity > 1 will bleed light
        camera.bloomThreshold  = 0.75
        camera.bloomIntensity  = 1.4
        camera.bloomBlurRadius = 6.0

        // Depth of field — focus midground, fore/background blur naturally
        // focusDistance is from the camera (camera is at z=20, so distance 25 → world z ≈ -5)
        camera.wantsDepthOfField = true
        camera.focusDistance      = 25.0
        camera.fStop              = 4.5    // moderate blur; lower = more, higher = less
        camera.apertureBladeCount = 6      // hexagonal bokeh

        // Screen-space ambient occlusion — adds depth cues in corners and crevices
        camera.screenSpaceAmbientOcclusionIntensity       = 0.80
        camera.screenSpaceAmbientOcclusionRadius          = 0.08
        camera.screenSpaceAmbientOcclusionBias            = 0.03
        camera.screenSpaceAmbientOcclusionDepthThreshold  = 0.20
        camera.screenSpaceAmbientOcclusionNormalThreshold = 0.30

        cameraNode.camera   = camera
        cameraNode.position = SCNVector3(0, 0, 20)
        scene.rootNode.addChildNode(cameraNode)
    }

    /// Convenience init for image-layer based scenes (not used by portals but kept for future use).
    public convenience init(layers: [WallpaperLayer], sceneSize: CGSize) {
        let s = SCNScene()

        // Ambient light
        let ambient = SCNNode()
        ambient.light = {
            let l = SCNLight(); l.type = .ambient; l.intensity = 1000; return l
        }()
        s.rootNode.addChildNode(ambient)

        self.init(scene: s, sceneSize: sceneSize)

        for layer in layers.sorted().reversed() {
            addImageLayer(layer, sceneSize: sceneSize)
        }
    }

    // MARK: - Public API

    /// Animate camera toward target offset (called each head-position update).
    /// Uses rotation (yaw/pitch) so the camera looks around the scene — this is what
    /// creates genuine 3D parallax: near objects shift much more than far ones, and
    /// you see different faces of geometry as you move.  Pure XY translation just
    /// pans the whole scene like a 2D image.
    public func updateCameraOffset(_ offset: CGPoint) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.08
        // 0.04 rad per scene-unit keeps the range comfortable at default sensitivity=10
        cameraNode.eulerAngles.y = CGFloat( Float(offset.x) * 0.04)   // head right → look right
        cameraNode.eulerAngles.x = CGFloat(-Float(offset.y) * 0.04)   // head up    → look up
        SCNTransaction.commit()
    }

    public var fieldOfView: Double = 60 {
        didSet { cameraNode.camera?.fieldOfView = fieldOfView }
    }

    public var depthIntensity: Double = 1.0 {
        didSet {
            guard oldValue != 0 else { return }
            let ratio = Float(depthIntensity) / Float(oldValue)
            for node in scene.rootNode.childNodes where node !== cameraNode {
                node.position.z *= CGFloat(ratio)
            }
        }
    }

    // MARK: - Private

    private func addImageLayer(_ layer: WallpaperLayer, sceneSize: CGSize) {
        let aspect = sceneSize.width / max(sceneSize.height, 1)
        let planeH: CGFloat = 30
        let planeW = planeH * aspect * (1 + CGFloat(layer.parallaxScale) * 0.5)

        let geometry = SCNPlane(width: planeW, height: planeH)

        if let image = NSImage(named: layer.imageName) {
            geometry.firstMaterial?.diffuse.contents = image
        } else {
            geometry.firstMaterial?.diffuse.contents = NSColor.darkGray
        }
        geometry.firstMaterial?.isDoubleSided = true

        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(0, 0, Float(-layer.depth))
        scene.rootNode.addChildNode(node)
    }
}
