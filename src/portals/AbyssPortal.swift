import AppKit
import SceneKit

/// Deep ocean viewed through a submarine porthole.
/// The sandy floor recedes into murky darkness; coral, jellyfish, and fish
/// inhabit different depth layers. Dense fog gives a true underwater feel.
public enum AbyssPortal {
    private static let floorY: Float = -10

    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.00, green: 0.01, blue: 0.04, alpha: 1)

        // Water is naturally murky — heavy fog is essential for depth
        scene.fogColor           = NSColor(red: 0.00, green: 0.03, blue: 0.08, alpha: 1)
        scene.fogStartDistance   = 6
        scene.fogEndDistance     = 32
        scene.fogDensityExponent = 1.0

        addLighting(to: scene.rootNode)
        addOceanFloor(to: scene.rootNode)
        addLightRays(to: scene.rootNode)
        addCoral(to: scene.rootNode)
        addBioluminescence(to: scene.rootNode)
        addJellyfish(to: scene.rootNode)
        addFish(to: scene.rootNode)
        addBubbles(to: scene.rootNode)

        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        let amb = SCNNode()
        amb.light = { let l = SCNLight(); l.type = .ambient
            l.intensity = 120; l.color = NSColor(red: 0.00, green: 0.14, blue: 0.28, alpha: 1)
            return l }()
        parent.addChildNode(amb)

        // Faint directional light from above — sunlight filtering down
        let dir = SCNNode()
        dir.light = { let l = SCNLight(); l.type = .directional
            l.intensity = 250; l.color = NSColor(red: 0.00, green: 0.40, blue: 0.70, alpha: 1)
            return l }()
        dir.eulerAngles = SCNVector3(-0.30, 0, 0)
        parent.addChildNode(dir)
    }

    // MARK: - Ocean floor (extends into the distance)

    private static func addOceanFloor(to parent: SCNNode) {
        let floor = SCNPlane(width: 80, height: 120)
        let mat   = SCNMaterial()
        mat.diffuse.contents  = makeSeabedTexture()
        mat.specular.contents = NSColor(white: 0.08, alpha: 1)
        mat.shininess = 10
        mat.diffuse.wrapS = .repeat; mat.diffuse.wrapT = .repeat
        mat.diffuse.contentsTransform = SCNMatrix4MakeScale(8, 16, 1)
        floor.firstMaterial = mat
        let node = SCNNode(geometry: floor)
        node.eulerAngles.x = CGFloat(-Float.pi / 2)
        // Centred far back so floor visible from near to far
        node.position = SCNVector3(0, floorY, -40)
        parent.addChildNode(node)

        // Side walls (blends into fog, so just need a dark fill)
        for sign: Float in [-1, 1] {
            let wall = SCNPlane(width: 120, height: 30)
            let wmat = SCNMaterial()
            wmat.diffuse.contents = NSColor(red: 0, green: 0.02, blue: 0.06, alpha: 1)
            wall.firstMaterial = wmat
            let wNode = SCNNode(geometry: wall)
            wNode.position = SCNVector3(sign * 40, 5, -40)
            wNode.eulerAngles.y = CGFloat(sign * Float.pi / 2)
            parent.addChildNode(wNode)
        }
    }

    private static func makeSeabedTexture() -> NSImage {
        let size = CGSize(width: 128, height: 128)
        let img  = NSImage(size: size)
        img.lockFocus()
        NSGradient(colors: [
            NSColor(red: 0.08, green: 0.07, blue: 0.05, alpha: 1),
            NSColor(red: 0.05, green: 0.05, blue: 0.04, alpha: 1),
        ])!.draw(in: NSRect(origin: .zero, size: size), angle: 0)
        // Rock speckles
        NSColor(red: 0.10, green: 0.09, blue: 0.07, alpha: 0.6).setFill()
        for _ in 0..<80 {
            let r = CGFloat.random(in: 2...6)
            NSBezierPath(ovalIn: NSRect(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                width: r, height: r * 0.6)).fill()
        }
        img.unlockFocus()
        return img
    }

    // MARK: - Volumetric light rays

    private static func addLightRays(to parent: SCNNode) {
        for i in -4...4 {
            let w    = CGFloat(Float.random(in: 1.0...3.5))
            let ray  = SCNPlane(width: w, height: 36)
            let mat  = SCNMaterial()
            mat.diffuse.contents  = NSColor(red: 0.00, green: 0.35, blue: 0.55, alpha: 0.05)
            mat.emission.contents = NSColor(red: 0.00, green: 0.25, blue: 0.45, alpha: 0.07)
            mat.blendMode = .add; mat.isDoubleSided = true
            ray.firstMaterial = mat
            let node = SCNNode(geometry: ray)
            node.position = SCNVector3(
                Float(i) * 3.5 + Float.random(in: -1.5...1.5),
                4,
                Float.random(in: -8 ... -20)
            )
            node.eulerAngles.z = CGFloat(Float.random(in: -0.20...0.20))
            let sway = SCNAction.repeatForever(.sequence([
                .rotateTo(x: 0, y: 0, z: CGFloat(Float.random(in: -0.14...0.14)),
                          duration: Double.random(in: 4...9), usesShortestUnitArc: true),
                .rotateTo(x: 0, y: 0, z: CGFloat(Float.random(in: -0.14...0.14)),
                          duration: Double.random(in: 4...9), usesShortestUnitArc: true),
            ]))
            node.runAction(sway)
            parent.addChildNode(node)
        }
    }

    // MARK: - Coral formations ON the ocean floor

    private static func addCoral(to parent: SCNNode) {
        let palette: [NSColor] = [
            NSColor(red: 0.95, green: 0.28, blue: 0.12, alpha: 1),
            NSColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1),
            NSColor(red: 0.78, green: 0.08, blue: 0.52, alpha: 1),
            NSColor(red: 0.55, green: 0.00, blue: 0.90, alpha: 1),
            NSColor(red: 0.00, green: 0.78, blue: 0.55, alpha: 1),
        ]
        // Place coral at various x and z positions, rooted on the floor
        let positions: [(Float, Float)] = [
            (-8, -4), (-4, -6), (0, -5), (4, -7), (8, -4),
            (-6, -12), (-2, -10), (3, -11), (7, -13), (-9, -15),
            (-3, -18), (5, -16), (10, -10), (-11, -8), (2, -20),
        ]
        for (x, z) in positions {
            let col    = palette.randomElement()!
            let h      = Float.random(in: 1.5...6.0)
            let cone   = SCNCone(
                topRadius:    CGFloat(Float.random(in: 0...0.15)),
                bottomRadius: CGFloat(Float.random(in: 0.15...0.60)),
                height:       CGFloat(h)
            )
            let mat = SCNMaterial()
            mat.diffuse.contents  = col
            mat.emission.contents = col.withAlphaComponent(0.20)
            cone.firstMaterial = mat
            let node = SCNNode(geometry: cone)
            // Bottom of cone at floorY, tip pointing up
            node.position = SCNVector3(x, floorY + h / 2, z)
            node.eulerAngles.z = CGFloat(Float.random(in: -0.40...0.40))
            parent.addChildNode(node)
        }
    }

    // MARK: - Bioluminescent orbs drifting through mid-water

    private static func addBioluminescence(to parent: SCNNode) {
        let palette: [NSColor] = [
            NSColor(red: 0.00, green: 0.90, blue: 1.00, alpha: 1),
            NSColor(red: 0.00, green: 1.00, blue: 0.52, alpha: 1),
            NSColor(red: 0.12, green: 0.32, blue: 1.00, alpha: 1),
            NSColor(red: 0.55, green: 0.00, blue: 1.00, alpha: 1),
        ]
        for _ in 0..<35 {
            let r   = CGFloat(Float.random(in: 0.08...0.50))
            let orb = SCNSphere(radius: r)
            let col = palette.randomElement()!
            let mat = SCNMaterial()
            mat.diffuse.contents  = col.withAlphaComponent(0.20)
            mat.emission.contents = col; mat.blendMode = .add
            orb.firstMaterial = mat
            let node = SCNNode(geometry: orb)
            node.position = SCNVector3(
                Float.random(in: -18...18),
                Float(floorY) + Float.random(in: 1...12),
                Float.random(in: -5 ... -25)
            )
            let drift = SCNAction.repeatForever(.sequence([
                .moveBy(x: CGFloat.random(in: -1.5...1.5),
                        y: CGFloat.random(in: -0.8...0.8), z: 0,
                        duration: Double.random(in: 3...8)),
                .moveBy(x: CGFloat.random(in: -1.5...1.5),
                        y: CGFloat.random(in: -0.8...0.8), z: 0,
                        duration: Double.random(in: 3...8)),
            ]))
            node.runAction(drift)
            parent.addChildNode(node)
        }
    }

    // MARK: - Jellyfish (pulsing + bobbing at mid-depth)

    private static func addJellyfish(to parent: SCNNode) {
        let palette: [NSColor] = [
            NSColor(red: 0.00, green: 0.90, blue: 0.90, alpha: 0.40),
            NSColor(red: 0.72, green: 0.00, blue: 0.90, alpha: 0.40),
            NSColor(red: 0.00, green: 0.72, blue: 0.42, alpha: 0.40),
            NSColor(red: 0.10, green: 0.38, blue: 1.00, alpha: 0.40),
        ]
        let positions: [(Float, Float, Float)] = [
            (-7, -4, -5), (3, -2, -7), (-2, 1, -10),
            (8, -5, -8), (-5, 2, -14), (4, -3, -18),
            (0, 0, -4), (-9, 1, -11),
        ]
        for (x, y, z) in positions {
            let bodyCol = palette.randomElement()!
            let mat     = SCNMaterial()
            mat.diffuse.contents  = bodyCol
            mat.emission.contents = bodyCol.withAlphaComponent(0.65)
            mat.blendMode = .add; mat.isDoubleSided = true

            let bodyR = Float.random(in: 0.5...1.2)
            let body  = SCNSphere(radius: CGFloat(bodyR))
            body.firstMaterial = mat
            let jelly = SCNNode(geometry: body)
            jelly.position = SCNVector3(x, y, z)

            let tentCount = Int.random(in: 5...8)
            for t in 0..<tentCount {
                let angle = Float(t) * .pi * 2 / Float(tentCount)
                let tentH = Float.random(in: 1.8...3.2)
                let cyl   = SCNCylinder(radius: 0.035, height: CGFloat(tentH))
                cyl.firstMaterial = mat
                let tNode = SCNNode(geometry: cyl)
                let tentY = -(tentH / 2) - bodyR * 0.6
                tNode.position = SCNVector3(cos(angle) * 0.48, tentY, sin(angle) * 0.48)
                jelly.addChildNode(tNode)
            }

            jelly.runAction(.repeatForever(.sequence([
                .scale(to: 0.82, duration: Double.random(in: 0.55...1.10)),
                .scale(to: 1.00, duration: Double.random(in: 0.55...1.10)),
            ])))
            let bobDist = Float.random(in: 0.8...1.6)
            jelly.runAction(.repeatForever(.sequence([
                .moveBy(x: 0, y:  CGFloat(bobDist), z: 0, duration: Double.random(in: 2.5...5.0)),
                .moveBy(x: 0, y: -CGFloat(bobDist), z: 0, duration: Double.random(in: 2.5...5.0)),
            ])))
            parent.addChildNode(jelly)
        }
    }

    // MARK: - Fish (pre-spawned, swim across at varying depths)

    private static func addFish(to parent: SCNNode) {
        let palette: [NSColor] = [
            NSColor(red: 0.00, green: 0.72, blue: 0.92, alpha: 0.92),
            NSColor(red: 0.18, green: 0.90, blue: 0.62, alpha: 0.92),
            NSColor(red: 0.08, green: 0.38, blue: 0.82, alpha: 0.92),
        ]
        // (startX, y, z) pairs — fish swim from one side to the other
        let specs: [(Float, Float, Float)] = [
            (-28,  -5, -4), (28,  -7, -6), (-28, -3, -9),
            ( 28,  -6, -12), (-28, -2, -15), (28,  -8, -5),
            (-28,  -4, -18), (28,  -6, -8), (-28, -3, -22),
            ( 28,  -5, -11), (-28, -7, -7), (28,  -4, -16),
        ]
        for (i, (sx, y, z)) in specs.enumerated() {
            let col      = palette.randomElement()!
            let fromLeft = sx < 0
            let endX: Float = fromLeft ? 28 : -28

            let mat = SCNMaterial()
            mat.diffuse.contents  = col
            mat.emission.contents = col.withAlphaComponent(0.28)

            let body = SCNBox(width: 1.0, height: 0.28, length: 0.18, chamferRadius: 0.10)
            body.firstMaterial = mat
            let fish = SCNNode(geometry: body)

            let tail = SCNBox(width: 0.28, height: 0.35, length: 0.06, chamferRadius: 0.03)
            tail.firstMaterial = mat
            let tNode = SCNNode(geometry: tail)
            tNode.position = SCNVector3(fromLeft ? -0.6 : 0.6, 0, 0)
            fish.addChildNode(tNode)

            fish.position = SCNVector3(sx, y, z)
            if !fromLeft { fish.eulerAngles.y = CGFloat(Float.pi) }
            fish.opacity = 0
            parent.addChildNode(fish)

            let delay = Double(i) * Double.random(in: 1.5...5.0)
            let dur   = Double.random(in: 10...20)
            fish.runAction(.sequence([
                .wait(duration: delay),
                .fadeIn(duration: 0.5),
                .move(to: SCNVector3(CGFloat(endX), CGFloat(y), CGFloat(z)), duration: dur),
                .removeFromParentNode()
            ]))
        }
    }

    // MARK: - Rising bubbles

    private static func addBubbles(to parent: SCNNode) {
        let ps = SCNParticleSystem()
        ps.birthRate = 40; ps.particleLifeSpan = 5.5
        ps.particleVelocity = 2.8; ps.particleVelocityVariation = 1.5
        ps.emitterShape = SCNPlane(width: 22, height: 0)
        ps.particleSize = 0.14
        ps.particleColor = NSColor(red: 0.60, green: 0.92, blue: 1.00, alpha: 0.50)
        ps.blendMode = .additive
        let emitter = SCNNode()
        emitter.position    = SCNVector3(0, floorY + 0.5, -10)
        emitter.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }

}
