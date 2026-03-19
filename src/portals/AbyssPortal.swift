import AppKit
import SceneKit

public enum AbyssPortal {
    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0, green: 0.01, blue: 0.04, alpha: 1)

        addOceanDepth(to: scene.rootNode, depth: -30)
        addBioluminescence(to: scene.rootNode, depth: -20)
        addCoral(to: scene.rootNode, depth: -10)
        addJellyfish(to: scene.rootNode, depth: -7)
        addBubbles(to: scene.rootNode, depth: -3)
        addPorthole(to: scene.rootNode, depth: -1)

        return scene
    }

    private static func addOceanDepth(to parent: SCNNode, depth: Float) {
        let plane = SCNPlane(width: 80, height: 50)
        let mat   = SCNMaterial()
        let grad  = NSGradient(colors: [
            NSColor(red: 0, green: 0.02, blue: 0.1, alpha: 1),
            .black
        ])!
        let img = NSImage(size: CGSize(width: 2, height: 256))
        img.lockFocus()
        grad.draw(in: NSRect(origin: .zero, size: CGSize(width: 2, height: 256)), angle: 90)
        img.unlockFocus()
        mat.diffuse.contents = img
        plane.firstMaterial  = mat
        let node = SCNNode(geometry: plane)
        node.position.z = depth
        parent.addChildNode(node)
    }

    private static func addBioluminescence(to parent: SCNNode, depth: Float) {
        let colors: [NSColor] = [
            NSColor(red: 0, green: 0.8, blue: 1, alpha: 1),
            NSColor(red: 0, green: 1, blue: 0.6, alpha: 1),
            NSColor(red: 0.2, green: 0.4, blue: 1, alpha: 1),
        ]
        for _ in 0..<30 {
            let r   = CGFloat(Float.random(in: 0.15...0.6))
            let orb = SCNSphere(radius: r)
            let mat = SCNMaterial()
            let col = colors.randomElement()!
            mat.diffuse.contents  = col.withAlphaComponent(0.3)
            mat.emission.contents = col
            mat.blendMode = .add
            orb.firstMaterial = mat
            let node = SCNNode(geometry: orb)
            node.position = SCNVector3(
                Float.random(in: -20...20),
                Float.random(in: -12...12),
                depth + Float.random(in: -4...4)
            )
            let drift = SCNAction.sequence([
                .moveBy(x: CGFloat.random(in: -1...1), y: CGFloat.random(in: -0.5...0.5), z: 0,
                        duration: Double.random(in: 3...7)),
                .moveBy(x: CGFloat.random(in: -1...1), y: CGFloat.random(in: -0.5...0.5), z: 0,
                        duration: Double.random(in: 3...7)),
            ])
            node.runAction(.repeatForever(drift))
            parent.addChildNode(node)
        }
    }

    private static func addCoral(to parent: SCNNode, depth: Float) {
        let coralColor = NSColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1)
        for i in -5...5 {
            let height  = Float.random(in: 1.5...5)
            let cone    = SCNCone(
                topRadius:    0,
                bottomRadius: CGFloat(Float.random(in: 0.2...0.5)),
                height:       CGFloat(height)
            )
            let mat = SCNMaterial()
            mat.diffuse.contents  = coralColor
            mat.emission.contents = coralColor.withAlphaComponent(0.2)
            cone.firstMaterial = mat
            let node = SCNNode(geometry: cone)
            node.position = SCNVector3(
                Float(i) * 2.5 + Float.random(in: -0.8...0.8),
                -8 + height / 2,
                depth + Float.random(in: -2...2)
            )
            node.eulerAngles.z = Float.random(in: -0.3...0.3)
            parent.addChildNode(node)
        }
    }

    private static func addJellyfish(to parent: SCNNode, depth: Float) {
        let jellyfishColor = NSColor(red: 0, green: 0.9, blue: 0.9, alpha: 0.4)
        let emissionColor  = NSColor(red: 0, green: 0.8, blue: 0.8, alpha: 0.6)
        let mat  = SCNMaterial()
        mat.diffuse.contents  = jellyfishColor
        mat.emission.contents = emissionColor
        mat.blendMode = .add
        mat.isDoubleSided = true

        for _ in 0..<5 {
            let body = SCNSphere(radius: 0.8)
            body.firstMaterial = mat

            let jelly = SCNNode(geometry: body)
            jelly.position = SCNVector3(
                Float.random(in: -8...8),
                Float.random(in: -4...4),
                depth + Float.random(in: -2...2)
            )

            for t in 0..<6 {
                let angle = Float(t) * .pi * 2 / 6
                let cyl   = SCNCylinder(radius: 0.04, height: 2)
                cyl.firstMaterial = mat
                let tNode = SCNNode(geometry: cyl)
                tNode.position = SCNVector3(cos(angle) * 0.5, -1.5, sin(angle) * 0.5)
                jelly.addChildNode(tNode)
            }

            let bob = SCNAction.sequence([
                .moveBy(x: 0, y: 1, z: 0, duration: Double.random(in: 2...4)),
                .moveBy(x: 0, y: -1, z: 0, duration: Double.random(in: 2...4)),
            ])
            jelly.runAction(.repeatForever(bob))
            parent.addChildNode(jelly)
        }
    }

    private static func addBubbles(to parent: SCNNode, depth: Float) {
        let ps = SCNParticleSystem()
        ps.birthRate                 = 25
        ps.particleLifeSpan          = 4
        ps.particleVelocity          = 3
        ps.particleVelocityVariation = 1
        ps.emitterShape              = SCNPlane(width: 15, height: 0)
        ps.particleSize              = 0.15
        ps.particleColor             = NSColor(white: 1, alpha: 0.5)
        ps.blendMode                 = .additive

        let emitter = SCNNode()
        emitter.position    = SCNVector3(0, -8, depth)
        emitter.eulerAngles = SCNVector3(.pi / 2, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }

    private static func addPorthole(to parent: SCNNode, depth: Float) {
        let tube = SCNTube(innerRadius: 7.5, outerRadius: 9, height: 0.8)
        let mat  = SCNMaterial()
        mat.diffuse.contents  = NSColor(red: 0.15, green: 0.18, blue: 0.2, alpha: 1)
        mat.specular.contents = NSColor.white
        mat.shininess = 120
        tube.firstMaterial = mat

        let frame = SCNNode(geometry: tube)
        frame.position.z    = depth
        frame.eulerAngles.x = .pi / 2
        parent.addChildNode(frame)

        for i in 0..<12 {
            let angle = Float(i) * .pi * 2 / 12
            let bolt  = SCNSphere(radius: 0.25)
            bolt.firstMaterial = mat
            let bNode = SCNNode(geometry: bolt)
            bNode.position = SCNVector3(cos(angle) * 8.25, sin(angle) * 8.25, depth)
            parent.addChildNode(bNode)
        }
    }
}
