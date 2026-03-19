import AppKit
import SceneKit

/// Street-level view of a rainy cyberpunk city.
/// A wet road recedes to a vanishing point; buildings line both sides
/// and fade into purple smog. The parallax makes you feel planted in the street.
public enum MidnightCityPortal {
    // Camera sits at y=0.  Road is at y = roadY. Buildings sit on the road.
    private static let roadY: Float = -8

    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.black

        // Heavy city smog — objects beyond 45 units fade into the purple void
        scene.fogColor           = NSColor(red: 0.04, green: 0.00, blue: 0.09, alpha: 1)
        scene.fogStartDistance   = 12
        scene.fogEndDistance     = 55
        scene.fogDensityExponent = 1.0

        addLighting(to: scene.rootNode)
        addSky(to: scene.rootNode)
        addRoad(to: scene.rootNode)
        addSidewalks(to: scene.rootNode)
        addBuildings(to: scene.rootNode)
        addStreetLights(to: scene.rootNode)
        addRain(to: scene.rootNode)

        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        let amb = SCNNode()
        amb.light = { let l = SCNLight(); l.type = .ambient
            l.intensity = 60; l.color = NSColor(red: 0.04, green: 0.00, blue: 0.10, alpha: 1)
            return l }()
        parent.addChildNode(amb)
    }

    // MARK: - Sky

    private static func addSky(to parent: SCNNode) {
        let plane = SCNPlane(width: 110, height: 70)
        let img   = NSImage(size: CGSize(width: 2, height: 256))
        img.lockFocus()
        NSGradient(colors: [
            NSColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1),
            NSColor(red: 0.04, green: 0.01, blue: 0.10, alpha: 1),
            NSColor(red: 0.08, green: 0.02, blue: 0.15, alpha: 1),
        ])!.draw(in: NSRect(origin: .zero, size: CGSize(width: 2, height: 256)), angle: 90)
        img.unlockFocus()
        let mat = SCNMaterial()
        mat.diffuse.contents = img; plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, 20, -55)
        parent.addChildNode(node)
    }

    // MARK: - Road (wet asphalt, extends into the distance)

    private static func addRoad(to parent: SCNNode) {
        let road = SCNPlane(width: 14, height: 110)
        let mat  = SCNMaterial()
        mat.diffuse.contents  = makeAsphaltTexture()
        mat.specular.contents = NSColor(white: 0.45, alpha: 1)
        mat.shininess = 100
        road.firstMaterial = mat
        let node = SCNNode(geometry: road)
        node.eulerAngles.x = CGFloat(-Float.pi / 2)
        node.position = SCNVector3(0, roadY, -35)
        parent.addChildNode(node)

        // Neon reflection strip running down the centre
        let reflect = SCNPlane(width: 14, height: 110)
        let rmat    = SCNMaterial()
        rmat.diffuse.contents  = makeReflectionTexture()
        rmat.blendMode = .add; rmat.isDoubleSided = true
        reflect.firstMaterial = rmat
        let rNode = SCNNode(geometry: reflect)
        rNode.eulerAngles.x = CGFloat(-Float.pi / 2)
        rNode.position = SCNVector3(0, roadY + 0.05, -35)
        parent.addChildNode(rNode)
    }

    private static func makeAsphaltTexture() -> NSImage {
        let size = CGSize(width: 256, height: 256)
        let img  = NSImage(size: size)
        img.lockFocus()
        NSColor(red: 0.045, green: 0.045, blue: 0.048, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        // Centre dashed white line
        NSColor(red: 0.28, green: 0.26, blue: 0.14, alpha: 0.7).setFill()
        for y in stride(from: 12.0 as CGFloat, to: size.height, by: 44) {
            NSRect(x: size.width / 2 - 7, y: y, width: 14, height: 22).fill()
        }
        img.unlockFocus()
        return img
    }

    private static func makeReflectionTexture() -> NSImage {
        let size = CGSize(width: 256, height: 256)
        let img  = NSImage(size: size)
        img.lockFocus()
        // Pink/cyan/violet gradient reflection — city neon in puddles
        NSGradient(colors: [
            NSColor(red: 0.6, green: 0.0, blue: 0.3, alpha: 0.18),
            NSColor(red: 0.0, green: 0.3, blue: 0.6, alpha: 0.10),
            NSColor(red: 0.4, green: 0.0, blue: 0.6, alpha: 0.14),
        ])!.draw(in: NSRect(origin: .zero, size: size), angle: 90)
        img.unlockFocus()
        return img
    }

    // MARK: - Sidewalks

    private static func addSidewalks(to parent: SCNNode) {
        for sign: Float in [-1, 1] {
            let walk = SCNPlane(width: 8, height: 110)
            let mat  = SCNMaterial()
            mat.diffuse.contents  = NSColor(white: 0.065, alpha: 1)
            mat.specular.contents = NSColor(white: 0.20, alpha: 1)
            mat.shininess = 30
            walk.firstMaterial = mat
            let node = SCNNode(geometry: walk)
            node.eulerAngles.x = CGFloat(-Float.pi / 2)
            node.position = SCNVector3(sign * 11, roadY + 0.15, -35)
            parent.addChildNode(node)
        }
    }

    // MARK: - Buildings lining both sides, converging to vanishing point

    private static func addBuildings(to parent: SCNNode) {
        let neonColors: [NSColor] = [
            NSColor(red: 1.0, green: 0.08, blue: 0.50, alpha: 1),
            NSColor(red: 0.0, green: 0.90, blue: 1.00, alpha: 1),
            NSColor(red: 0.6, green: 0.00, blue: 1.00, alpha: 1),
            NSColor(red: 1.0, green: 0.60, blue: 0.00, alpha: 1),
            NSColor(red: 0.0, green: 1.00, blue: 0.50, alpha: 1),
        ]
        // Z positions: near to far. Buildings get progressively more obscured by fog.
        let zDepths: [Float] = [-2, -9, -17, -25, -33, -42, -50]

        for (idx, z) in zDepths.enumerated() {
            for side: Float in [-1, 1] {
                let height = Float.random(in: 12...28)
                let width  = Float.random(in: 5...9)
                let depth  = Float.random(in: 4...8)
                let accent = neonColors[idx % neonColors.count]

                let box = SCNBox(width: CGFloat(width), height: CGFloat(height),
                                 length: CGFloat(depth), chamferRadius: 0.05)
                let mat = SCNMaterial()
                mat.diffuse.contents  = NSColor(white: 0.038, alpha: 1)
                mat.emission.contents = accent.withAlphaComponent(0.045)
                box.firstMaterial = mat

                let node = SCNNode(geometry: box)
                // x: buildings hug the sides; y: base on road, rise upward
                let xOffset = side * (7 + width / 2 + Float.random(in: 0...2))
                node.position = SCNVector3(xOffset, roadY + height / 2, z)

                // Neon roofline trim
                addNeonTrim(to: node, width: CGFloat(width), depth: CGFloat(depth),
                            height: CGFloat(height), colour: accent)
                // Window lights
                addWindowLights(to: node, width: CGFloat(width), height: CGFloat(height))
                parent.addChildNode(node)
            }
        }
    }

    private static func addNeonTrim(to building: SCNNode,
                                    width: CGFloat, depth: CGFloat,
                                    height: CGFloat, colour: NSColor) {
        let trim = SCNBox(width: width + 0.15, height: 0.14, length: depth + 0.15, chamferRadius: 0)
        let mat  = SCNMaterial()
        mat.diffuse.contents = colour; mat.emission.contents = colour; mat.blendMode = .add
        trim.firstMaterial = mat
        let node = SCNNode(geometry: trim)
        node.position.y = height / 2 + 0.07
        building.addChildNode(node)
    }

    private static func addWindowLights(to building: SCNNode, width: CGFloat, height: CGFloat) {
        let palette: [NSColor] = [
            NSColor(red: 0.95, green: 0.85, blue: 0.55, alpha: 1),
            NSColor(red: 0.50, green: 0.82, blue: 1.00, alpha: 1),
            NSColor(red: 1.00, green: 0.40, blue: 0.65, alpha: 1),
        ]
        let cols = max(1, Int(width  / 0.9))
        let rows = max(1, Int(height / 1.4))
        for c in 0..<cols {
            for r in 0..<rows {
                guard Float.random(in: 0...1) < 0.30 else { continue }
                let win  = SCNBox(width: 0.35, height: 0.55, length: 0.08, chamferRadius: 0)
                let col  = palette.randomElement()!
                let wmat = SCNMaterial()
                wmat.diffuse.contents = col; wmat.emission.contents = col
                win.firstMaterial = wmat
                let wNode = SCNNode(geometry: win)
                wNode.position = SCNVector3(
                    CGFloat(c) * 0.9  - width  * 0.44,
                    CGFloat(r) * 1.4  - height * 0.44,
                    0.52
                )
                building.addChildNode(wNode)
            }
        }
    }

    // MARK: - Street lights

    private static func addStreetLights(to parent: SCNNode) {
        let zDepths: [Float] = [-3, -12, -22, -32, -42]
        let lightCol = NSColor(red: 1.0, green: 0.92, blue: 0.70, alpha: 1)

        for z in zDepths {
            for side: Float in [-1, 1] {
                // Pole
                let pole = SCNCylinder(radius: 0.15, height: 12)
                let pmat = SCNMaterial()
                pmat.diffuse.contents = NSColor(white: 0.12, alpha: 1)
                pole.firstMaterial = pmat
                let pNode = SCNNode(geometry: pole)
                pNode.position = SCNVector3(side * 7.5, roadY + 6, z)
                parent.addChildNode(pNode)

                // Lamp (glowing sphere on top)
                let lamp = SCNSphere(radius: 0.5)
                let lmat = SCNMaterial()
                lmat.diffuse.contents = lightCol; lmat.emission.contents = lightCol
                lmat.blendMode = .add; lamp.firstMaterial = lmat
                let lNode = SCNNode(geometry: lamp)
                lNode.position = SCNVector3(side * 7.5, roadY + 12.6, z)
                parent.addChildNode(lNode)
            }
        }
    }

    // MARK: - Rain

    private static func addRain(to parent: SCNNode) {
        let ps = SCNParticleSystem()
        ps.birthRate = 1600; ps.particleLifeSpan = 0.50
        ps.particleVelocity = 42; ps.particleVelocityVariation = 8
        ps.emitterShape = SCNPlane(width: 60, height: 0)
        ps.particleSize = 0.030
        ps.particleColor = NSColor(red: 0.70, green: 0.82, blue: 1.00, alpha: 0.50)
        ps.blendMode = .additive
        let emitter = SCNNode()
        emitter.position    = SCNVector3(0, 18, -25)
        emitter.eulerAngles = SCNVector3(-.pi / 2 + 0.22, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }

}
