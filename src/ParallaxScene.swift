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
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar  = 500
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
    public func updateCameraOffset(_ offset: CGPoint) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.08
        cameraNode.position.x = CGFloat(Float(offset.x))
        cameraNode.position.y = CGFloat(Float(offset.y))
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
