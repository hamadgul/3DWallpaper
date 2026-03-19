import AppKit
import SceneKit

/// Deep-space panorama — no frame, no floor. The viewer floats in space.
public enum CosmosPortal {
    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.00, green: 0.00, blue: 0.02, alpha: 1)

        // Very faint depth fog so extreme-distance objects soften naturally
        scene.fogColor           = NSColor(red: 0.00, green: 0.00, blue: 0.02, alpha: 1)
        scene.fogStartDistance   = 80
        scene.fogEndDistance     = 200
        scene.fogDensityExponent = 1.0

        addLighting(to: scene.rootNode)
        addStarField(to: scene.rootNode)
        addNebulae(to: scene.rootNode)
        addGasPlanet(to: scene.rootNode)
        addAsteroidField(to: scene.rootNode)
        addShootingStars(to: scene.rootNode)

        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        let amb = SCNNode()
        amb.light = { let l = SCNLight(); l.type = .ambient
            l.intensity = 80; l.color = NSColor(red: 0.04, green: 0.04, blue: 0.18, alpha: 1); return l }()
        parent.addChildNode(amb)

        let dir = SCNNode()
        dir.light = { let l = SCNLight(); l.type = .directional
            l.intensity = 900; l.color = NSColor(red: 0.92, green: 0.88, blue: 1.00, alpha: 1); return l }()
        dir.eulerAngles = SCNVector3(-0.4, 0.6, 0)
        parent.addChildNode(dir)
    }

    // MARK: - Star field (scattered throughout a large volume)

    private static func addStarField(to parent: SCNNode) {
        let container = SCNNode()
        for _ in 0..<1000 {
            let r   = CGFloat(Float.random(in: 0.018...0.10))
            let geo = SCNSphere(radius: r)
            let mat = SCNMaterial()
            let col = starColour()
            mat.diffuse.contents = col; mat.emission.contents = col
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float.random(in: -80...80),
                Float.random(in: -45...45),
                Float.random(in: -150 ... -8)
            )
            container.addChildNode(node)
        }
        container.runAction(.repeatForever(.rotateBy(x: 0.006, y: 0.025, z: 0, duration: 120)))
        parent.addChildNode(container)
    }

    private static func starColour() -> NSColor {
        let b = CGFloat(Float.random(in: 0.50...1.0))
        switch Float.random(in: 0...1) {
        case ..<0.65: return NSColor(white: b, alpha: 1)
        case ..<0.82: return NSColor(red: b * 0.78, green: b * 0.88, blue: b,        alpha: 1)
        case ..<0.93: return NSColor(red: b,        green: b * 0.90, blue: b * 0.55, alpha: 1)
        default:      return NSColor(red: b,        green: b * 0.42, blue: b * 0.22, alpha: 1)
        }
    }

    // MARK: - Nebulae (radial gradient blobs — no visible rectangle edges)

    private static func addNebulae(to parent: SCNNode) {
        // Each nebula is a large plane with a radial gradient (bright centre → black)
        // With additive blending, the black edges are invisible — only the glow shows.
        nebula(parent, color: NSColor(red: 0.25, green: 0.00, blue: 0.55, alpha: 1),
               size: CGSize(width: 90, height: 58), pos: SCNVector3(12,  6, -88))
        nebula(parent, color: NSColor(red: 0.55, green: 0.10, blue: 0.00, alpha: 1),
               size: CGSize(width: 70, height: 45), pos: SCNVector3(-22, 4, -75))
        nebula(parent, color: NSColor(red: 0.00, green: 0.18, blue: 0.52, alpha: 1),
               size: CGSize(width: 80, height: 50), pos: SCNVector3(5,  -8, -65))
        nebula(parent, color: NSColor(red: 0.18, green: 0.00, blue: 0.38, alpha: 1),
               size: CGSize(width: 100, height: 62), pos: SCNVector3(-8, 10, -100))
    }

    private static func nebula(_ parent: SCNNode, color: NSColor,
                                size: CGSize, pos: SCNVector3) {
        let plane = SCNPlane(width: size.width, height: size.height)
        // Radial gradient: bright center → black at edge
        // Black + additive blend = invisible, so only the glowing centre shows.
        let imgSize = CGSize(width: 256, height: 256)
        let img = NSImage(size: imgSize)
        img.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: imgSize).fill()
        NSGradient(starting: color, ending: .black)!.draw(
            in: NSRect(origin: .zero, size: imgSize),
            relativeCenterPosition: NSPoint(x: 0, y: 0))
        img.unlockFocus()
        let mat = SCNMaterial()
        mat.diffuse.contents = img
        mat.blendMode = .add; mat.isDoubleSided = true
        plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.position = pos
        parent.addChildNode(node)
    }

    // MARK: - Gas planet (Saturn-like, appropriately sized)

    private static func addGasPlanet(to parent: SCNNode) {
        let sphere = SCNSphere(radius: 3.0)
        let mat    = SCNMaterial()
        mat.diffuse.contents  = makeGasBandImage()
        mat.specular.contents = NSColor(white: 0.28, alpha: 1)
        mat.shininess = 25; sphere.firstMaterial = mat

        let planet = SCNNode(geometry: sphere)
        // Offset to upper-right — not centred, feels more natural
        planet.position = SCNVector3(16, 4, -42)
        planet.runAction(.repeatForever(.rotateBy(x: 0, y: 0.25, z: 0, duration: 14)))

        // Atmospheric rim haze
        let atmo  = SCNSphere(radius: 3.4)
        let amat  = SCNMaterial()
        amat.diffuse.contents  = NSColor(red: 0.88, green: 0.52, blue: 0.18, alpha: 0.10)
        amat.emission.contents = NSColor(red: 0.65, green: 0.38, blue: 0.10, alpha: 0.15)
        amat.blendMode = .add; amat.isDoubleSided = true
        atmo.firstMaterial = amat
        planet.addChildNode(SCNNode(geometry: atmo))

        // Rings — proportional to planet, tilted gracefully
        let ring  = SCNTube(innerRadius: 4.2, outerRadius: 7.8, height: 0.10)
        let rmat  = SCNMaterial()
        rmat.diffuse.contents  = NSColor(red: 0.72, green: 0.55, blue: 0.30, alpha: 0.55)
        rmat.emission.contents = NSColor(red: 0.30, green: 0.22, blue: 0.10, alpha: 0.12)
        rmat.isDoubleSided = true; ring.firstMaterial = rmat
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles.x = CGFloat(Float.pi / 2 - 0.38)
        planet.addChildNode(ringNode)

        // Inner bright ring band
        let ring2  = SCNTube(innerRadius: 4.8, outerRadius: 5.8, height: 0.07)
        let rmat2  = SCNMaterial()
        rmat2.diffuse.contents  = NSColor(red: 0.90, green: 0.75, blue: 0.50, alpha: 0.80)
        rmat2.blendMode = .add; rmat2.isDoubleSided = true
        ring2.firstMaterial = rmat2
        let ringNode2 = SCNNode(geometry: ring2)
        ringNode2.eulerAngles.x = CGFloat(Float.pi / 2 - 0.38)
        planet.addChildNode(ringNode2)

        // Small moon
        let moon  = SCNSphere(radius: 0.5)
        let mmat  = SCNMaterial()
        mmat.diffuse.contents  = NSColor(white: 0.44, alpha: 1)
        mmat.specular.contents = NSColor(white: 0.18, alpha: 1); mmat.shininess = 15
        moon.firstMaterial = mmat
        let moonOrbit = SCNNode()
        let moonNode  = SCNNode(geometry: moon)
        moonNode.position = SCNVector3(6.5, 0, 0)
        moonOrbit.addChildNode(moonNode)
        moonOrbit.runAction(.repeatForever(.rotateBy(x: 0, y: 1, z: 0.08, duration: 8)))
        planet.addChildNode(moonOrbit)
        parent.addChildNode(planet)
    }

    private static func makeGasBandImage() -> NSImage {
        let size = CGSize(width: 512, height: 512)
        let img  = NSImage(size: size)
        img.lockFocus()
        let bands: [(CGFloat, NSColor)] = [
            (0.00, NSColor(red: 0.88, green: 0.62, blue: 0.30, alpha: 1)),
            (0.11, NSColor(red: 0.70, green: 0.45, blue: 0.18, alpha: 1)),
            (0.21, NSColor(red: 0.95, green: 0.72, blue: 0.42, alpha: 1)),
            (0.31, NSColor(red: 0.75, green: 0.50, blue: 0.22, alpha: 1)),
            (0.43, NSColor(red: 0.62, green: 0.37, blue: 0.12, alpha: 1)),
            (0.54, NSColor(red: 0.90, green: 0.62, blue: 0.32, alpha: 1)),
            (0.65, NSColor(red: 0.78, green: 0.50, blue: 0.20, alpha: 1)),
            (0.76, NSColor(red: 0.92, green: 0.68, blue: 0.38, alpha: 1)),
            (0.87, NSColor(red: 0.68, green: 0.42, blue: 0.15, alpha: 1)),
            (1.00, NSColor(red: 0.88, green: 0.62, blue: 0.30, alpha: 1)),
        ]
        for i in 0..<bands.count - 1 {
            let sy = bands[i].0 * size.height; let ey = bands[i + 1].0 * size.height
            bands[i].1.setFill()
            NSRect(x: 0, y: sy, width: size.width, height: ey - sy).fill()
        }
        img.unlockFocus()
        return img
    }

    // MARK: - Asteroid field (mid-distance, spread around centre)

    private static func addAsteroidField(to parent: SCNNode) {
        for _ in 0..<30 {
            let sz  = CGFloat(Float.random(in: 0.10...0.55))
            let geo: SCNGeometry = Bool.random()
                ? SCNSphere(radius: sz)
                : SCNBox(width: sz * 1.4, height: sz, length: sz * 0.75, chamferRadius: sz * 0.08)
            let mat = SCNMaterial()
            mat.diffuse.contents  = NSColor(
                red: CGFloat.random(in: 0.20...0.44), green: CGFloat.random(in: 0.17...0.36),
                blue: CGFloat.random(in: 0.10...0.24), alpha: 1)
            mat.specular.contents = NSColor(white: 0.18, alpha: 1)
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float.random(in: -28...10),
                Float.random(in: -10...10),
                Float.random(in: -30 ... -12)
            )
            node.runAction(.repeatForever(.rotateBy(
                x: CGFloat(Float.random(in: 0.5...2.5)),
                y: CGFloat(Float.random(in: 0.5...2.5)),
                z: CGFloat(Float.random(in: 0...1)),
                duration: Double.random(in: 3...12)
            )))
            parent.addChildNode(node)
        }
    }

    // MARK: - Shooting stars

    private static func addShootingStars(to parent: SCNNode) {
        for i in 0..<10 {
            let delay = Double(i) * Double.random(in: 3...10)
            let len   = CGFloat(Float.random(in: 2.0...5.0))
            let trail = SCNBox(width: len, height: 0.05, length: 0.05, chamferRadius: 0)
            let mat   = SCNMaterial()
            mat.diffuse.contents = NSColor.white; mat.emission.contents = NSColor.white
            mat.blendMode = .add; trail.firstMaterial = mat
            let node  = SCNNode(geometry: trail)
            let sx = Float.random(in: -35 ... -5), sy = Float.random(in: -8...15)
            let sz = Float.random(in: -60 ... -25)
            node.position = SCNVector3(sx, sy, sz)
            node.eulerAngles.z = CGFloat(Float.random(in: -0.3...0.3))
            node.opacity = 0
            parent.addChildNode(node)
            node.runAction(.sequence([
                .wait(duration: delay), .fadeIn(duration: 0.05),
                .move(to: SCNVector3(sx + 55, sy - 10, sz),
                      duration: Double.random(in: 0.7...1.4)),
                .removeFromParentNode()
            ]))
        }
    }
}
