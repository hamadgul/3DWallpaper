import AppKit
import SceneKit

public enum MidnightCityPortal {
    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.black

        addLighting(to: scene.rootNode)
        addSky(to: scene.rootNode, depth: -42)
        addDistantSkyline(to: scene.rootNode, depth: -36)
        addTowers(to: scene.rootNode, depth: -22)
        addNeonSigns(to: scene.rootNode, depth: -13)
        addStreet(to: scene.rootNode, depth: -8)
        addCarLights(to: scene.rootNode, depth: -6)
        addRain(to: scene.rootNode, depth: -4)
        addWindowFrame(to: scene.rootNode, depth: -1)

        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        let ambient = SCNNode()
        ambient.light = {
            let l = SCNLight(); l.type = .ambient; l.intensity = 70
            l.color = NSColor(red: 0.04, green: 0.00, blue: 0.10, alpha: 1); return l
        }()
        parent.addChildNode(ambient)
    }

    // MARK: - Night sky gradient

    private static func addSky(to parent: SCNNode, depth: Float) {
        let plane = SCNPlane(width: 90, height: 60)
        let img   = NSImage(size: CGSize(width: 2, height: 256))
        img.lockFocus()
        NSGradient(colors: [
            .black,
            NSColor(red: 0.02, green: 0.00, blue: 0.09, alpha: 1)
        ])!.draw(in: NSRect(origin: .zero, size: CGSize(width: 2, height: 256)), angle: 90)
        img.unlockFocus()
        let mat = SCNMaterial()
        mat.diffuse.contents = img
        plane.firstMaterial  = mat
        let node = SCNNode(geometry: plane)
        node.position.z = CGFloat(depth)
        parent.addChildNode(node)
    }

    // MARK: - Distant low-detail skyline with lit windows

    private static func addDistantSkyline(to parent: SCNNode, depth: Float) {
        let container = SCNNode()
        container.position.z = CGFloat(depth)
        for i in -22...22 {
            let h = Float.random(in: 2...11)
            let w = Float.random(in: 0.5...1.4)
            let box = SCNBox(width: CGFloat(w), height: CGFloat(h), length: 0.5, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents  = NSColor(white: 0.03, alpha: 1)
            mat.emission.contents = NSColor(white: 0.012, alpha: 1)
            box.firstMaterial = mat
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(Float(i) * 2.0 + Float.random(in: -0.3...0.3),
                                       h / 2 - 14, 0)
            windowLights(on: node, w: CGFloat(w), h: CGFloat(h))
            container.addChildNode(node)
        }
        parent.addChildNode(container)
    }

    private static func windowLights(on building: SCNNode, w: CGFloat, h: CGFloat) {
        let palette: [NSColor] = [
            NSColor(red: 0.95, green: 0.85, blue: 0.55, alpha: 1),
            NSColor(red: 0.50, green: 0.80, blue: 1.00, alpha: 1),
            NSColor(red: 1.00, green: 0.40, blue: 0.65, alpha: 1),
        ]
        let cols = max(1, Int(w / 0.35))
        let rows = max(1, Int(h / 0.70))
        for c in 0..<cols {
            for r in 0..<rows {
                guard Float.random(in: 0...1) < 0.32 else { continue }
                let win  = SCNBox(width: 0.11, height: 0.17, length: 0.06, chamferRadius: 0)
                let col  = palette.randomElement()!
                let wmat = SCNMaterial()
                wmat.diffuse.contents  = col
                wmat.emission.contents = col
                win.firstMaterial = wmat
                let wNode = SCNNode(geometry: win)
                wNode.position = SCNVector3(
                    CGFloat(c) * 0.35 - w * 0.40,
                    CGFloat(r) * 0.70 - h * 0.44,
                    0.28
                )
                building.addChildNode(wNode)
            }
        }
    }

    // MARK: - Main tower district

    private static func addTowers(to parent: SCNNode, depth: Float) {
        let container  = SCNNode()
        container.position.z = CGFloat(depth)
        let neonColors: [NSColor] = [
            NSColor(red: 1.0, green: 0.08, blue: 0.50, alpha: 1),
            NSColor(red: 0.0, green: 0.90, blue: 1.00, alpha: 1),
            NSColor(red: 0.6, green: 0.00, blue: 1.00, alpha: 1),
            NSColor(red: 1.0, green: 0.60, blue: 0.00, alpha: 1),
            NSColor(red: 0.0, green: 1.00, blue: 0.50, alpha: 1),
        ]
        for i in -13...13 {
            let height = Float.random(in: 5...21)
            let width  = Float.random(in: 0.9...2.6)
            let box    = SCNBox(width: CGFloat(width), height: CGFloat(height),
                                length: 1.9, chamferRadius: 0.05)
            let accent = neonColors.randomElement()!
            let mat    = SCNMaterial()
            mat.diffuse.contents  = NSColor(white: 0.04, alpha: 1)
            mat.emission.contents = accent.withAlphaComponent(0.055)
            box.firstMaterial = mat
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(
                Float(i) * 2.5 + Float.random(in: -0.4...0.4),
                height / 2 - 11,
                Float.random(in: -4...4)
            )
            // Roofline neon trim
            let trim  = SCNBox(width: CGFloat(width) + 0.12, height: 0.14, length: 1.92, chamferRadius: 0)
            let tmat  = SCNMaterial()
            tmat.diffuse.contents  = accent
            tmat.emission.contents = accent
            tmat.blendMode = .add
            trim.firstMaterial = tmat
            let trimNode = SCNNode(geometry: trim)
            trimNode.position.y = CGFloat(height) / 2 + 0.07
            node.addChildNode(trimNode)

            windowLights(on: node, w: CGFloat(width), h: CGFloat(height))
            container.addChildNode(node)
        }
        parent.addChildNode(container)
    }

    // MARK: - Neon signs (flickering)

    private static func addNeonSigns(to parent: SCNNode, depth: Float) {
        let signs: [(Float, Float, CGFloat, CGFloat, NSColor)] = [
            (-9,  -1, 3.2, 0.80, NSColor(red: 1.0, green: 0.10, blue: 0.60, alpha: 1)),
            ( 4,   2, 2.2, 0.65, NSColor(red: 0.0, green: 0.90, blue: 1.00, alpha: 1)),
            (-2,  -3, 1.6, 0.50, NSColor(red: 0.8, green: 0.00, blue: 1.00, alpha: 1)),
            ( 9,   0, 2.6, 0.70, NSColor(red: 1.0, green: 0.60, blue: 0.00, alpha: 1)),
            (-5,   3, 1.4, 0.45, NSColor(red: 0.0, green: 1.00, blue: 0.50, alpha: 1)),
        ]
        for (x, y, w, h, col) in signs {
            // Sign body
            let box  = SCNBox(width: w, height: h, length: 0.10, chamferRadius: 0.06)
            let mat  = SCNMaterial()
            mat.diffuse.contents  = col
            mat.emission.contents = col
            mat.blendMode = .add
            box.firstMaterial = mat
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(x, y, depth)

            // Flicker
            let pauseA = Double.random(in: 1.5...5.0)
            let pauseB = Double.random(in: 3.0...9.0)
            let flicker = SCNAction.repeatForever(.sequence([
                .fadeOpacity(to: 1.0, duration: 0.0),
                .wait(duration: pauseA),
                .fadeOpacity(to: 0.35, duration: 0.07),
                .fadeOpacity(to: 1.00, duration: 0.05),
                .wait(duration: 0.12),
                .fadeOpacity(to: 0.25, duration: 0.05),
                .fadeOpacity(to: 1.00, duration: 0.06),
                .wait(duration: pauseB),
            ]))
            node.runAction(flicker)
            parent.addChildNode(node)
        }
    }

    // MARK: - Street with neon puddle reflection

    private static func addStreet(to parent: SCNNode, depth: Float) {
        let road  = SCNBox(width: 55, height: 0.10, length: 6, chamferRadius: 0)
        let rmat  = SCNMaterial()
        rmat.diffuse.contents  = NSColor(white: 0.04, alpha: 1)
        rmat.specular.contents = NSColor(white: 0.35, alpha: 1)
        rmat.shininess = 90
        road.firstMaterial = rmat
        let roadNode = SCNNode(geometry: road)
        roadNode.position = SCNVector3(0, -9.8, Float(depth))
        parent.addChildNode(roadNode)

        // Pink neon puddle strip
        let puddle = SCNBox(width: 55, height: 0.05, length: 5, chamferRadius: 0)
        let pmat   = SCNMaterial()
        pmat.diffuse.contents  = NSColor(red: 1.0, green: 0.10, blue: 0.60, alpha: 0.28)
        pmat.emission.contents = NSColor(red: 0.55, green: 0.05, blue: 0.30, alpha: 0.50)
        pmat.blendMode = .add
        puddle.firstMaterial = pmat
        let puddleNode = SCNNode(geometry: puddle)
        puddleNode.position = SCNVector3(0, -9.74, Float(depth))
        parent.addChildNode(puddleNode)
    }

    // MARK: - Car light streaks (pre-spawned with staggered delays)

    private static func addCarLights(to parent: SCNNode, depth: Float) {
        for i in 0..<18 {
            let delay     = Double(i) * Double.random(in: 0.8...3.0)
            let fromLeft  = Bool.random()
            let isHeads   = Bool.random()
            let col: NSColor = isHeads
                ? NSColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 0.92)
                : NSColor(red: 1.0, green: 0.10, blue: 0.10, alpha: 0.92)
            let startX: Float = fromLeft ? -32 : 32
            let endX:   Float = fromLeft ?  32 : -32
            let laneY:  Float = -9.3

            for offset: Float in [-0.28, 0.28] {
                let streak = SCNBox(width: 1.6, height: 0.09, length: 0.09, chamferRadius: 0)
                let mat    = SCNMaterial()
                mat.diffuse.contents  = col
                mat.emission.contents = col
                mat.blendMode = .add
                streak.firstMaterial = mat
                let node = SCNNode(geometry: streak)
                node.position = SCNVector3(startX, laneY, depth + offset)
                node.opacity  = 0
                parent.addChildNode(node)
                node.runAction(.sequence([
                    .wait(duration: delay),
                    .fadeIn(duration: 0.1),
                    .move(to: SCNVector3(CGFloat(endX), CGFloat(laneY),
                                        CGFloat(depth + offset)),
                          duration: Double.random(in: 1.8...3.2)),
                    .removeFromParentNode()
                ]))
            }
        }
    }

    // MARK: - Angled rain

    private static func addRain(to parent: SCNNode, depth: Float) {
        let ps = SCNParticleSystem()
        ps.birthRate                 = 1400
        ps.particleLifeSpan          = 0.52
        ps.particleVelocity          = 38
        ps.particleVelocityVariation = 7
        ps.emitterShape              = SCNPlane(width: 55, height: 0)
        ps.particleSize              = 0.032
        ps.particleColor             = NSColor(red: 0.70, green: 0.82, blue: 1.00, alpha: 0.52)
        ps.blendMode                 = .additive
        let emitter = SCNNode()
        emitter.position    = SCNVector3(0, 15, Float(depth))
        emitter.eulerAngles = SCNVector3(-.pi / 2 + 0.22, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }

    // MARK: - Concrete window frame

    private static func addWindowFrame(to parent: SCNNode, depth: Float) {
        func bar(w: CGFloat, h: CGFloat, x: Float, y: Float) {
            let box = SCNBox(width: w, height: h, length: 0.35, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents  = NSColor(white: 0.11, alpha: 1)
            mat.specular.contents = NSColor(white: 0.45, alpha: 1)
            mat.shininess = 35
            box.firstMaterial = mat
            let n = SCNNode(geometry: box)
            n.position = SCNVector3(x, y, Float(depth))
            parent.addChildNode(n)
        }
        bar(w: 25, h: 0.75, x:   0, y:  10.5)
        bar(w: 25, h: 0.75, x:   0, y: -10.5)
        bar(w: 0.75, h: 22, x: -12.5, y: 0)
        bar(w: 0.75, h: 22, x:  12.5, y: 0)
    }
}
