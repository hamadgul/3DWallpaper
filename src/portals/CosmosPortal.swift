import AppKit
import SceneKit

public enum CosmosPortal {
    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.black

        addLighting(to: scene.rootNode)
        addStarField(to: scene.rootNode, depth: -55)
        addNebulae(to: scene.rootNode)
        addGasPlanet(to: scene.rootNode, depth: -20)
        addAsteroidBelt(to: scene.rootNode, depth: -8)
        addShootingStars(to: scene.rootNode, depth: -42)
        addPorthole(to: scene.rootNode, depth: -1)

        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        let ambient = SCNNode()
        ambient.light = {
            let l = SCNLight(); l.type = .ambient; l.intensity = 120
            l.color = NSColor(red: 0.05, green: 0.05, blue: 0.22, alpha: 1); return l
        }()
        parent.addChildNode(ambient)

        let dir = SCNNode()
        dir.light = {
            let l = SCNLight(); l.type = .directional; l.intensity = 900
            l.color = NSColor(red: 0.88, green: 0.85, blue: 1.0, alpha: 1); return l
        }()
        dir.eulerAngles = SCNVector3(-0.5, 0.5, 0)
        parent.addChildNode(dir)
    }

    // MARK: - Star field (1 200 colour-varied stars)

    private static func addStarField(to parent: SCNNode, depth: Float) {
        let container = SCNNode()
        container.position.z = CGFloat(depth)

        for _ in 0..<1200 {
            let r   = CGFloat(Float.random(in: 0.025...0.13))
            let geo = SCNSphere(radius: r)
            let mat = SCNMaterial()
            let col = starColor()
            mat.diffuse.contents  = col
            mat.emission.contents = col
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float.random(in: -38...38),
                Float.random(in: -24...24),
                Float.random(in: -6...6)
            )
            container.addChildNode(node)
        }

        container.runAction(.repeatForever(.rotateBy(x: 0.01, y: 0.04, z: 0, duration: 110)))
        parent.addChildNode(container)
    }

    private static func starColor() -> NSColor {
        let b = CGFloat(Float.random(in: 0.55...1.0))
        switch Float.random(in: 0...1) {
        case ..<0.65: return NSColor(white: b, alpha: 1)
        case ..<0.82: return NSColor(red: b * 0.78, green: b * 0.88, blue: b,        alpha: 1) // blue-white
        case ..<0.93: return NSColor(red: b,        green: b * 0.90, blue: b * 0.55, alpha: 1) // yellow
        default:      return NSColor(red: b,        green: b * 0.42, blue: b * 0.22, alpha: 1) // red-orange
        }
    }

    // MARK: - Nebulae (3 layered clouds)

    private static func addNebulae(to parent: SCNNode) {
        nebula(parent, depth: -43,
               c1: NSColor(red: 0.50, green: 0.00, blue: 0.88, alpha: 0.55),
               c2: NSColor(red: 0.10, green: 0.00, blue: 0.30, alpha: 0.00), angle: 45)
        nebula(parent, depth: -36,
               c1: NSColor(red: 0.88, green: 0.22, blue: 0.00, alpha: 0.38),
               c2: NSColor.black.withAlphaComponent(0), angle: -28)
        nebula(parent, depth: -30,
               c1: NSColor(red: 0.00, green: 0.45, blue: 0.78, alpha: 0.28),
               c2: NSColor.black.withAlphaComponent(0), angle: 115)
    }

    private static func nebula(_ parent: SCNNode, depth: Float,
                                c1: NSColor, c2: NSColor, angle: CGFloat) {
        let plane = SCNPlane(width: 74, height: 48)
        let img   = NSImage(size: CGSize(width: 512, height: 512))
        img.lockFocus()
        NSGradient(colors: [c1, c2])!.draw(
            in: NSRect(origin: .zero, size: CGSize(width: 512, height: 512)), angle: angle)
        img.unlockFocus()
        let mat = SCNMaterial()
        mat.diffuse.contents = img
        mat.blendMode        = .add
        mat.isDoubleSided    = true
        plane.firstMaterial  = mat
        let node = SCNNode(geometry: plane)
        node.position.z = CGFloat(depth)
        parent.addChildNode(node)
    }

    // MARK: - Gas planet with rings and moon

    private static func addGasPlanet(to parent: SCNNode, depth: Float) {
        let sphere = SCNSphere(radius: 5)
        let mat    = SCNMaterial()
        mat.diffuse.contents  = makeGasBandImage()
        mat.specular.contents = NSColor(white: 0.30, alpha: 1)
        mat.shininess = 28
        sphere.firstMaterial = mat

        let planet = SCNNode(geometry: sphere)
        planet.position = SCNVector3(5.0, 1.5, Float(depth))
        planet.runAction(.repeatForever(.rotateBy(x: 0, y: 0.28, z: 0, duration: 13)))

        // Atmosphere haze
        let atmo  = SCNSphere(radius: 5.6)
        let amat  = SCNMaterial()
        amat.diffuse.contents  = NSColor(red: 0.88, green: 0.52, blue: 0.18, alpha: 0.10)
        amat.emission.contents = NSColor(red: 0.65, green: 0.38, blue: 0.10, alpha: 0.15)
        amat.blendMode    = .add
        amat.isDoubleSided = true
        atmo.firstMaterial = amat
        planet.addChildNode(SCNNode(geometry: atmo))

        // Planetary rings
        let ring  = SCNTube(innerRadius: 7.5, outerRadius: 13.5, height: 0.11)
        let rmat  = SCNMaterial()
        rmat.diffuse.contents  = NSColor(red: 0.72, green: 0.55, blue: 0.30, alpha: 0.58)
        rmat.emission.contents = NSColor(red: 0.30, green: 0.22, blue: 0.10, alpha: 0.18)
        rmat.isDoubleSided = true
        ring.firstMaterial = rmat
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles.x = CGFloat(Float.pi / 2 - 0.45)
        planet.addChildNode(ringNode)

        // Inner bright ring strip
        let ring2  = SCNTube(innerRadius: 8.2, outerRadius: 9.4, height: 0.08)
        let rmat2  = SCNMaterial()
        rmat2.diffuse.contents  = NSColor(red: 0.90, green: 0.75, blue: 0.50, alpha: 0.80)
        rmat2.blendMode = .add
        rmat2.isDoubleSided = true
        ring2.firstMaterial = rmat2
        let ringNode2 = SCNNode(geometry: ring2)
        ringNode2.eulerAngles.x = CGFloat(Float.pi / 2 - 0.45)
        planet.addChildNode(ringNode2)

        // Orbiting moon
        let moon  = SCNSphere(radius: 0.85)
        let mmat  = SCNMaterial()
        mmat.diffuse.contents  = NSColor(white: 0.45, alpha: 1)
        mmat.specular.contents = NSColor(white: 0.20, alpha: 1)
        mmat.shininess = 20
        moon.firstMaterial = mmat
        let moonOrbit = SCNNode()
        let moonNode  = SCNNode(geometry: moon)
        moonNode.position = SCNVector3(11, 0, 0)
        moonOrbit.addChildNode(moonNode)
        moonOrbit.runAction(.repeatForever(.rotateBy(x: 0, y: 1, z: 0.08, duration: 7)))
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
            (0.43, NSColor(red: 0.63, green: 0.37, blue: 0.12, alpha: 1)),
            (0.54, NSColor(red: 0.90, green: 0.62, blue: 0.32, alpha: 1)),
            (0.65, NSColor(red: 0.78, green: 0.50, blue: 0.20, alpha: 1)),
            (0.76, NSColor(red: 0.92, green: 0.68, blue: 0.38, alpha: 1)),
            (0.87, NSColor(red: 0.68, green: 0.42, blue: 0.15, alpha: 1)),
            (1.00, NSColor(red: 0.88, green: 0.62, blue: 0.30, alpha: 1)),
        ]
        for i in 0..<bands.count - 1 {
            let startY = bands[i].0     * size.height
            let endY   = bands[i + 1].0 * size.height
            bands[i].1.setFill()
            NSRect(x: 0, y: startY, width: size.width, height: endY - startY).fill()
        }
        img.unlockFocus()
        return img
    }

    // MARK: - Asteroid belt (mixed shapes, slowly orbiting)

    private static func addAsteroidBelt(to parent: SCNNode, depth: Float) {
        let belt = SCNNode()
        belt.position.z = CGFloat(depth)

        for _ in 0..<24 {
            let angle  = Float.random(in: 0...(.pi * 2))
            let radius = Float.random(in: 17...27)
            let sz     = CGFloat(Float.random(in: 0.14...0.62))
            let geo: SCNGeometry = Bool.random()
                ? SCNSphere(radius: sz)
                : SCNBox(width: sz * 1.4, height: sz, length: sz * 0.75, chamferRadius: sz * 0.08)
            let mat = SCNMaterial()
            mat.diffuse.contents  = NSColor(
                red:   CGFloat.random(in: 0.24...0.48),
                green: CGFloat.random(in: 0.20...0.40),
                blue:  CGFloat.random(in: 0.13...0.28),
                alpha: 1)
            mat.specular.contents = NSColor(white: 0.22, alpha: 1)
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                cos(angle) * radius,
                sin(angle) * radius * 0.18 + Float.random(in: -1.5...1.5),
                Float.random(in: -2...2)
            )
            node.runAction(.repeatForever(.rotateBy(
                x: CGFloat(Float.random(in: 0.5...2.5)),
                y: CGFloat(Float.random(in: 0.5...2.5)),
                z: CGFloat(Float.random(in: 0...1.0)),
                duration: Double.random(in: 3...11)
            )))
            belt.addChildNode(node)
        }

        belt.runAction(.repeatForever(.rotateBy(x: 0, y: 0.12, z: 0, duration: 65)))
        parent.addChildNode(belt)
    }

    // MARK: - Shooting stars (pre-spawned with staggered delays)

    private static func addShootingStars(to parent: SCNNode, depth: Float) {
        for i in 0..<12 {
            let delay = Double(i) * Double.random(in: 2.5...9.0)
            let len   = CGFloat(Float.random(in: 2.5...5.5))
            let trail = SCNBox(width: len, height: 0.055, length: 0.055, chamferRadius: 0)
            let mat   = SCNMaterial()
            mat.diffuse.contents  = NSColor.white
            mat.emission.contents = NSColor.white
            mat.blendMode = .add
            trail.firstMaterial = mat
            let node   = SCNNode(geometry: trail)
            let startX = Float.random(in: -28 ... -6)
            let startY = Float.random(in: -8...13)
            node.position = SCNVector3(startX, startY, depth)
            node.eulerAngles.z = CGFloat(Float.random(in: -0.28...0.28))
            parent.addChildNode(node)
            node.runAction(.sequence([
                .wait(duration: delay),
                .fadeIn(duration: 0.05),
                .move(to: SCNVector3(startX + 52, startY - 9, depth),
                      duration: Double.random(in: 0.7...1.4)),
                .removeFromParentNode()
            ]))
        }
    }

    // MARK: - Porthole (brass with blue glow)

    private static func addPorthole(to parent: SCNNode, depth: Float) {
        let tube = SCNTube(innerRadius: 8.5, outerRadius: 10.6, height: 0.9)
        let mat  = SCNMaterial()
        mat.diffuse.contents  = NSColor(red: 0.62, green: 0.50, blue: 0.30, alpha: 1)
        mat.specular.contents = NSColor(white: 0.95, alpha: 1)
        mat.shininess = 135
        tube.firstMaterial = mat
        let frame = SCNNode(geometry: tube)
        frame.position.z    = CGFloat(depth)
        frame.eulerAngles.x = CGFloat(Float.pi / 2)
        parent.addChildNode(frame)

        // Inner blue glow ring
        let glow  = SCNTube(innerRadius: 8.2, outerRadius: 8.75, height: 0.18)
        let gmat  = SCNMaterial()
        gmat.diffuse.contents  = NSColor(red: 0.10, green: 0.40, blue: 1.00, alpha: 0.55)
        gmat.emission.contents = NSColor(red: 0.10, green: 0.40, blue: 1.00, alpha: 1.00)
        gmat.blendMode = .add
        glow.firstMaterial = gmat
        let glowNode = SCNNode(geometry: glow)
        glowNode.position.z    = CGFloat(depth) - 0.12
        glowNode.eulerAngles.x = CGFloat(Float.pi / 2)
        parent.addChildNode(glowNode)

        // 16 brass bolts
        let bmat = SCNMaterial()
        bmat.diffuse.contents  = NSColor(red: 0.55, green: 0.43, blue: 0.25, alpha: 1)
        bmat.specular.contents = NSColor.white
        bmat.shininess = 80
        for i in 0..<16 {
            let angle = Float(i) * .pi * 2 / 16
            let bolt  = SCNSphere(radius: 0.23)
            bolt.firstMaterial = bmat
            let bNode = SCNNode(geometry: bolt)
            bNode.position = SCNVector3(cos(angle) * 9.55, sin(angle) * 9.55, Float(depth))
            parent.addChildNode(bNode)
        }
    }
}
