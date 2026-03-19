import AppKit
import SceneKit

public enum AbyssPortal {
    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0, green: 0.01, blue: 0.05, alpha: 1)

        addLighting(to: scene.rootNode)
        addOceanDepth(to: scene.rootNode, depth: -36)
        addLightRays(to: scene.rootNode, depth: -28)
        addBioluminescence(to: scene.rootNode, depth: -20)
        addCoral(to: scene.rootNode, depth: -12)
        addJellyfish(to: scene.rootNode, depth: -7)
        addFish(to: scene.rootNode, depth: -4)
        addBubbles(to: scene.rootNode, depth: -3)
        addPorthole(to: scene.rootNode, depth: -1)

        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        let ambient = SCNNode()
        ambient.light = {
            let l = SCNLight(); l.type = .ambient; l.intensity = 110
            l.color = NSColor(red: 0.00, green: 0.14, blue: 0.28, alpha: 1); return l
        }()
        parent.addChildNode(ambient)

        let dir = SCNNode()
        dir.light = {
            let l = SCNLight(); l.type = .directional; l.intensity = 280
            l.color = NSColor(red: 0.00, green: 0.42, blue: 0.72, alpha: 1); return l
        }()
        dir.eulerAngles = SCNVector3(-0.25, 0, 0)
        parent.addChildNode(dir)
    }

    // MARK: - Deep ocean gradient

    private static func addOceanDepth(to parent: SCNNode, depth: Float) {
        let plane = SCNPlane(width: 90, height: 60)
        let img   = NSImage(size: CGSize(width: 2, height: 512))
        img.lockFocus()
        NSGradient(colors: [
            NSColor(red: 0.00, green: 0.07, blue: 0.20, alpha: 1),
            NSColor(red: 0.00, green: 0.02, blue: 0.08, alpha: 1),
            NSColor.black
        ])!.draw(in: NSRect(origin: .zero, size: CGSize(width: 2, height: 512)), angle: 90)
        img.unlockFocus()
        let mat = SCNMaterial()
        mat.diffuse.contents = img
        plane.firstMaterial  = mat
        let node = SCNNode(geometry: plane)
        node.position.z = CGFloat(depth)
        parent.addChildNode(node)
    }

    // MARK: - Volumetric light rays from surface

    private static func addLightRays(to parent: SCNNode, depth: Float) {
        for i in -4...4 {
            let rayW = CGFloat(Float.random(in: 1.2...3.8))
            let ray  = SCNPlane(width: rayW, height: 32)
            let mat  = SCNMaterial()
            mat.diffuse.contents  = NSColor(red: 0.00, green: 0.38, blue: 0.58, alpha: 0.055)
            mat.emission.contents = NSColor(red: 0.00, green: 0.28, blue: 0.48, alpha: 0.08)
            mat.blendMode   = .add
            mat.isDoubleSided = true
            ray.firstMaterial = mat
            let node = SCNNode(geometry: ray)
            node.position = SCNVector3(
                Float(i) * 3.8 + Float.random(in: -1...1),
                5,
                depth + Float.random(in: -4...4)
            )
            node.eulerAngles.z = CGFloat(Float.random(in: -0.18...0.18))
            // Slow sway
            let sway = SCNAction.repeatForever(.sequence([
                .rotateTo(x: 0, y: 0, z: CGFloat(Float.random(in: -0.12...0.12)), duration: Double.random(in: 4...8), usesShortestUnitArc: true),
                .rotateTo(x: 0, y: 0, z: CGFloat(Float.random(in: -0.12...0.12)), duration: Double.random(in: 4...8), usesShortestUnitArc: true),
            ]))
            node.runAction(sway)
            parent.addChildNode(node)
        }
    }

    // MARK: - Bioluminescent orbs (40, drifting)

    private static func addBioluminescence(to parent: SCNNode, depth: Float) {
        let palette: [NSColor] = [
            NSColor(red: 0.00, green: 0.90, blue: 1.00, alpha: 1),
            NSColor(red: 0.00, green: 1.00, blue: 0.52, alpha: 1),
            NSColor(red: 0.12, green: 0.32, blue: 1.00, alpha: 1),
            NSColor(red: 0.55, green: 0.00, blue: 1.00, alpha: 1),
        ]
        for _ in 0..<40 {
            let r   = CGFloat(Float.random(in: 0.10...0.58))
            let orb = SCNSphere(radius: r)
            let col = palette.randomElement()!
            let mat = SCNMaterial()
            mat.diffuse.contents  = col.withAlphaComponent(0.22)
            mat.emission.contents = col
            mat.blendMode = .add
            orb.firstMaterial = mat
            let node = SCNNode(geometry: orb)
            node.position = SCNVector3(
                Float.random(in: -22...22),
                Float.random(in: -12...12),
                depth + Float.random(in: -5...5)
            )
            let drift = SCNAction.repeatForever(.sequence([
                .moveBy(x: CGFloat.random(in: -1.8...1.8),
                        y: CGFloat.random(in: -0.9...0.9), z: 0,
                        duration: Double.random(in: 3...8)),
                .moveBy(x: CGFloat.random(in: -1.8...1.8),
                        y: CGFloat.random(in: -0.9...0.9), z: 0,
                        duration: Double.random(in: 3...8)),
            ]))
            node.runAction(drift)
            parent.addChildNode(node)
        }
    }

    // MARK: - Coral forest (multi-colour)

    private static func addCoral(to parent: SCNNode, depth: Float) {
        let palette: [NSColor] = [
            NSColor(red: 0.95, green: 0.28, blue: 0.12, alpha: 1),
            NSColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1),
            NSColor(red: 0.78, green: 0.08, blue: 0.52, alpha: 1),
            NSColor(red: 0.55, green: 0.00, blue: 0.90, alpha: 1),
            NSColor(red: 0.00, green: 0.78, blue: 0.55, alpha: 1),
        ]
        for i in -8...8 {
            let col    = palette.randomElement()!
            let height = Float.random(in: 1.5...6.0)
            let cone   = SCNCone(
                topRadius:    CGFloat(Float.random(in: 0...0.12)),
                bottomRadius: CGFloat(Float.random(in: 0.15...0.60)),
                height:       CGFloat(height)
            )
            let mat = SCNMaterial()
            mat.diffuse.contents  = col
            mat.emission.contents = col.withAlphaComponent(0.22)
            cone.firstMaterial = mat
            let node = SCNNode(geometry: cone)
            node.position = SCNVector3(
                Float(i) * 2.3 + Float.random(in: -0.8...0.8),
                -9 + height / 2,
                depth + Float.random(in: -4...4)
            )
            node.eulerAngles.z = CGFloat(Float.random(in: -0.45...0.45))
            parent.addChildNode(node)
        }
    }

    // MARK: - Jellyfish (8, pulsing + bobbing)

    private static func addJellyfish(to parent: SCNNode, depth: Float) {
        let palette: [NSColor] = [
            NSColor(red: 0.00, green: 0.90, blue: 0.90, alpha: 0.40),
            NSColor(red: 0.72, green: 0.00, blue: 0.90, alpha: 0.40),
            NSColor(red: 0.00, green: 0.72, blue: 0.42, alpha: 0.40),
            NSColor(red: 0.10, green: 0.38, blue: 1.00, alpha: 0.40),
        ]
        for _ in 0..<8 {
            let bodyCol = palette.randomElement()!
            let mat     = SCNMaterial()
            mat.diffuse.contents  = bodyCol
            mat.emission.contents = bodyCol.withAlphaComponent(0.65)
            mat.blendMode    = .add
            mat.isDoubleSided = true

            let bodyR = Float.random(in: 0.5...1.25)
            let body  = SCNSphere(radius: CGFloat(bodyR))
            body.firstMaterial = mat
            let jelly = SCNNode(geometry: body)
            jelly.position = SCNVector3(
                Float.random(in: -10...10),
                Float.random(in: -5...5),
                depth + Float.random(in: -3...3)
            )

            // Tentacles
            let tentCount = Int.random(in: 5...8)
            for t in 0..<tentCount {
                let angle  = Float(t) * .pi * 2 / Float(tentCount)
                let tentH  = CGFloat(Float.random(in: 1.8...3.2))
                let cyl    = SCNCylinder(radius: 0.035, height: tentH)
                cyl.firstMaterial = mat
                let tNode = SCNNode(geometry: cyl)
                let tentY = -(Float(tentH) / 2) - bodyR * 0.6
                tNode.position = SCNVector3(cos(angle) * 0.48, tentY, sin(angle) * 0.48)
                jelly.addChildNode(tNode)
            }

            // Pulsing bell
            let pulse = SCNAction.repeatForever(.sequence([
                .scale(to: 0.82, duration: Double.random(in: 0.55...1.10)),
                .scale(to: 1.00, duration: Double.random(in: 0.55...1.10)),
            ]))
            // Bobbing
            let bobUp   = Double.random(in: 1.0...1.8)
            let bobDown = Double.random(in: 2.2...5.0)
            let bob = SCNAction.repeatForever(.sequence([
                .moveBy(x: 0, y: CGFloat(bobUp),   z: 0, duration: Double.random(in: 2.5...5.0)),
                .moveBy(x: 0, y: CGFloat(-bobDown), z: 0, duration: Double.random(in: 2.5...5.0)),
            ]))
            jelly.runAction(pulse)
            jelly.runAction(bob)
            parent.addChildNode(jelly)
        }
    }

    // MARK: - Deep-sea fish (pre-spawned with staggered delays)

    private static func addFish(to parent: SCNNode, depth: Float) {
        let palette: [NSColor] = [
            NSColor(red: 0.00, green: 0.72, blue: 0.92, alpha: 0.92),
            NSColor(red: 0.18, green: 0.90, blue: 0.62, alpha: 0.92),
            NSColor(red: 0.08, green: 0.38, blue: 0.82, alpha: 0.92),
            NSColor(red: 0.55, green: 0.00, blue: 0.90, alpha: 0.92),
        ]
        for i in 0..<20 {
            let delay    = Double(i) * Double.random(in: 1.5...6.0)
            let col      = palette.randomElement()!
            let fromLeft = Bool.random()
            let startX: Float = fromLeft ? -28 : 28
            let endX:   Float = fromLeft ?  28 : -28
            let y       = Float.random(in: -9...7)
            let z       = depth + Float.random(in: -2...2)

            let mat = SCNMaterial()
            mat.diffuse.contents  = col
            mat.emission.contents = col.withAlphaComponent(0.30)

            // Tapered fish body
            let body = SCNBox(width: 1.0, height: 0.28, length: 0.18, chamferRadius: 0.10)
            body.firstMaterial = mat
            let fish = SCNNode(geometry: body)

            // Tail fin
            let tail = SCNBox(width: 0.28, height: 0.35, length: 0.06, chamferRadius: 0.03)
            tail.firstMaterial = mat
            let tailNode = SCNNode(geometry: tail)
            tailNode.position = SCNVector3(fromLeft ? -0.6 : 0.6, 0, 0)
            fish.addChildNode(tailNode)

            fish.position = SCNVector3(startX, y, z)
            if !fromLeft { fish.eulerAngles.y = CGFloat(Float.pi) }
            fish.opacity = 0
            parent.addChildNode(fish)

            let dur = Double.random(in: 10...20)
            fish.runAction(.sequence([
                .wait(duration: delay),
                .fadeIn(duration: 0.5),
                .move(to: SCNVector3(CGFloat(endX), CGFloat(y), CGFloat(z)), duration: dur),
                .removeFromParentNode()
            ]))
        }
    }

    // MARK: - Rising bubbles

    private static func addBubbles(to parent: SCNNode, depth: Float) {
        let ps = SCNParticleSystem()
        ps.birthRate                 = 35
        ps.particleLifeSpan          = 5.5
        ps.particleVelocity          = 2.8
        ps.particleVelocityVariation = 1.4
        ps.emitterShape              = SCNPlane(width: 20, height: 0)
        ps.particleSize              = 0.14
        ps.particleColor             = NSColor(red: 0.60, green: 0.92, blue: 1.00, alpha: 0.52)
        ps.blendMode                 = .additive
        let emitter = SCNNode()
        emitter.position    = SCNVector3(0, -11, Float(depth))
        emitter.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }

    // MARK: - Steel porthole with green bioluminescent glow

    private static func addPorthole(to parent: SCNNode, depth: Float) {
        let tube = SCNTube(innerRadius: 7.5, outerRadius: 9.6, height: 1.0)
        let mat  = SCNMaterial()
        mat.diffuse.contents  = NSColor(red: 0.12, green: 0.16, blue: 0.18, alpha: 1)
        mat.specular.contents = NSColor(white: 0.65, alpha: 1)
        mat.shininess = 110
        tube.firstMaterial = mat
        let frame = SCNNode(geometry: tube)
        frame.position.z    = CGFloat(depth)
        frame.eulerAngles.x = CGFloat(Float.pi / 2)
        parent.addChildNode(frame)

        // Bioluminescent green inner glow
        let glow  = SCNTube(innerRadius: 7.22, outerRadius: 7.75, height: 0.20)
        let gmat  = SCNMaterial()
        gmat.diffuse.contents  = NSColor(red: 0.00, green: 0.82, blue: 0.52, alpha: 0.55)
        gmat.emission.contents = NSColor(red: 0.00, green: 0.82, blue: 0.52, alpha: 1.00)
        gmat.blendMode = .add
        glow.firstMaterial = gmat
        let glowNode = SCNNode(geometry: glow)
        glowNode.position.z    = CGFloat(depth) - 0.12
        glowNode.eulerAngles.x = CGFloat(Float.pi / 2)
        parent.addChildNode(glowNode)

        // 12 barnacle-coloured bolts
        let bmat = SCNMaterial()
        bmat.diffuse.contents  = NSColor(red: 0.14, green: 0.17, blue: 0.15, alpha: 1)
        bmat.specular.contents = NSColor(white: 0.28, alpha: 1)
        bmat.shininess = 30
        for i in 0..<12 {
            let angle = Float(i) * .pi * 2 / 12
            let bolt  = SCNSphere(radius: 0.30)
            bolt.firstMaterial = bmat
            let bNode = SCNNode(geometry: bolt)
            bNode.position = SCNVector3(cos(angle) * 8.55, sin(angle) * 8.55, Float(depth))
            parent.addChildNode(bNode)
        }
    }
}
