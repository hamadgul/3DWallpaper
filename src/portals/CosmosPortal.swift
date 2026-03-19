import AppKit
import SceneKit

/// Deep-space panorama. Viewer floats in open space.
/// Depth zones: foreground rocks z≈-2, asteroids z=-12…-30, planet z=-42, nebulae z=-65…-100, galaxy z=-190
public enum CosmosPortal {
    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.00, green: 0.00, blue: 0.015, alpha: 1)
        // Fog only at extreme depth — stars should be crisp
        scene.fogColor           = NSColor(red: 0.00, green: 0.00, blue: 0.015, alpha: 1)
        scene.fogStartDistance   = 140
        scene.fogEndDistance     = 220
        scene.fogDensityExponent = 1.0

        addLighting(to: scene.rootNode)
        addGalaxyDisc(to: scene.rootNode)
        addStarField(to: scene.rootNode)
        addNebulae(to: scene.rootNode)
        addGasPlanet(to: scene.rootNode)
        addAsteroidField(to: scene.rootNode)
        addForegroundRocks(to: scene.rootNode)     // very close — maximum parallax depth cue
        addMeteorShower(to: scene.rootNode)
        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        // Deep space ambient — almost nothing
        let amb = SCNNode()
        amb.light = {
            let l = SCNLight(); l.type = .ambient
            l.intensity = 50; l.color = NSColor(red: 0.02, green: 0.02, blue: 0.12, alpha: 1)
            return l
        }()
        parent.addChildNode(amb)

        // The star — warm, high-intensity omni at upper-right, physically attenuated
        let starNode = SCNNode()
        starNode.light = {
            let l = SCNLight(); l.type = .omni
            l.intensity   = 4000
            l.color       = NSColor(red: 1.00, green: 0.95, blue: 0.82, alpha: 1)
            l.temperature = 5800
            l.attenuationStartDistance   = 10
            l.attenuationEndDistance     = 300
            l.attenuationFalloffExponent = 2
            return l
        }()
        starNode.position = SCNVector3(65, 35, 8)
        parent.addChildNode(starNode)

        // Cool blue fill from the shadow side
        let fill = SCNNode()
        fill.light = {
            let l = SCNLight(); l.type = .directional
            l.intensity = 180; l.color = NSColor(red: 0.08, green: 0.10, blue: 0.55, alpha: 1)
            return l
        }()
        fill.eulerAngles = SCNVector3(0.25, -0.65, 0)
        parent.addChildNode(fill)
    }

    // MARK: - Galaxy disc backdrop (z=-190, slowly rotating)

    private static func addGalaxyDisc(to parent: SCNNode) {
        let imgSz = CGSize(width: 512, height: 512)
        let img   = NSImage(size: imgSz)
        img.lockFocus()
        NSColor.black.setFill(); NSRect(origin: .zero, size: imgSz).fill()
        // Core → arms → void radial gradient
        NSGradient(colors: [
            NSColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1),
            NSColor(red: 0.32, green: 0.22, blue: 0.52, alpha: 1),
            NSColor(red: 0.06, green: 0.04, blue: 0.14, alpha: 1),
            NSColor.black,
        ], atLocations: [0, 0.18, 0.55, 1.0],
           colorSpace: .genericRGB)!
            .draw(in: NSRect(origin: .zero, size: imgSz),
                  relativeCenterPosition: NSPoint(x: 0, y: 0))
        // Faint spiral arm arcs
        NSColor(red: 0.82, green: 0.78, blue: 0.98, alpha: 0.07).setStroke()
        for off: CGFloat in [0, .pi] {
            let path = NSBezierPath()
            path.lineWidth = 20
            path.appendArc(withCenter: CGPoint(x: imgSz.width / 2, y: imgSz.height / 2),
                           radius: imgSz.width * 0.28,
                           startAngle: off * 180 / .pi,
                           endAngle:   (off + .pi) * 180 / .pi)
            path.stroke()
        }
        img.unlockFocus()

        let plane = SCNPlane(width: 290, height: 290)
        let mat   = SCNMaterial()
        mat.diffuse.contents  = img
        mat.emission.contents = img
        mat.emission.intensity = 0.8
        mat.blendMode = .add; mat.isDoubleSided = true
        plane.firstMaterial  = mat
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, -12, -195)
        node.eulerAngles.x = CGFloat(Float.pi * 0.09)
        node.runAction(.repeatForever(.rotateBy(x: 0, y: 0,
                                                z: CGFloat(Float.pi * 2), duration: 960)))
        parent.addChildNode(node)
    }

    // MARK: - Star field

    private static func addStarField(to parent: SCNNode) {
        let container = SCNNode()
        for i in 0..<1200 {
            let r   = CGFloat(Float.random(in: 0.014...0.11))
            let geo = SCNSphere(radius: r)
            let col = starColour()
            let mat = SCNMaterial()
            mat.lightingModel    = .constant        // unlit — emissive only
            mat.diffuse.contents = col
            mat.emission.contents = col
            mat.emission.intensity = CGFloat(Float.random(in: 3...8))   // triggers HDR bloom!
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float.random(in: -110...110),
                Float.random(in: -65...65),
                Float.random(in: -195 ... -8)
            )
            container.addChildNode(node)
            // Every 6th star gets a bloom halo plane
            if i % 6 == 0 {
                let halo = SCNPlane(width: r * 22, height: r * 22)
                let hmat = SCNMaterial()
                hmat.lightingModel    = .constant
                hmat.diffuse.contents = col.withAlphaComponent(0.15)
                hmat.blendMode = .add; hmat.isDoubleSided = true
                halo.firstMaterial = hmat
                let hNode = SCNNode(geometry: halo)
                hNode.position = node.position
                container.addChildNode(hNode)
            }
        }
        container.runAction(.repeatForever(.rotateBy(x: 0.004, y: 0.018, z: 0, duration: 130)))
        parent.addChildNode(container)
    }

    private static func starColour() -> NSColor {
        let b = CGFloat(Float.random(in: 0.55...1.0))
        switch Float.random(in: 0...1) {
        case ..<0.60: return NSColor(white: b, alpha: 1)
        case ..<0.78: return NSColor(red: b * 0.72, green: b * 0.82, blue: b, alpha: 1)
        case ..<0.90: return NSColor(red: b, green: b * 0.88, blue: b * 0.48, alpha: 1)
        default:      return NSColor(red: b, green: b * 0.38, blue: b * 0.18, alpha: 1)
        }
    }

    // MARK: - Nebulae (layered additive planes)

    private static func addNebulae(to parent: SCNNode) {
        nebulaCloud(parent, hue: NSColor(red: 0.28, green: 0.00, blue: 0.60, alpha: 1),
                    accent: NSColor(red: 0.55, green: 0.00, blue: 0.35, alpha: 1),
                    pos: SCNVector3(14, 8, -95))
        nebulaCloud(parent, hue: NSColor(red: 0.60, green: 0.15, blue: 0.00, alpha: 1),
                    accent: NSColor(red: 0.35, green: 0.00, blue: 0.55, alpha: 1),
                    pos: SCNVector3(-20, -4, -82))
        nebulaCloud(parent, hue: NSColor(red: 0.00, green: 0.22, blue: 0.60, alpha: 1),
                    accent: NSColor(red: 0.00, green: 0.45, blue: 0.30, alpha: 1),
                    pos: SCNVector3(-6, 14, -112))
    }

    /// Three overlapping planes per cloud — looks volumetric due to depth offset
    private static func nebulaCloud(_ parent: SCNNode, hue: NSColor, accent: NSColor, pos: SCNVector3) {
        let configs: [(CGFloat, CGFloat, Float, NSColor)] = [
            (98, 64, 0,  hue),
            (74, 50, 5,  accent),
            (58, 40, -4, hue),
        ]
        for (w, h, zOff, col) in configs {
            let plane = SCNPlane(width: w, height: h)
            let sz    = CGSize(width: 256, height: 256)
            let img   = NSImage(size: sz)
            img.lockFocus()
            NSColor.black.setFill(); NSRect(origin: .zero, size: sz).fill()
            NSGradient(starting: col, ending: .black)!
                .draw(in: NSRect(origin: .zero, size: sz),
                      relativeCenterPosition: NSPoint(x: 0, y: 0))
            img.unlockFocus()
            let mat = SCNMaterial()
            mat.lightingModel    = .constant
            mat.diffuse.contents  = img
            mat.emission.contents = img
            mat.emission.intensity = 1.5          // nebulae glow in HDR
            mat.blendMode = .add; mat.isDoubleSided = true
            plane.firstMaterial  = mat
            let node = SCNNode(geometry: plane)
            node.position = SCNVector3(pos.x, pos.y, pos.z + CGFloat(zOff))
            node.eulerAngles.z = CGFloat(Float.random(in: -0.5...0.5))
            // Very slow drift
            node.runAction(.repeatForever(.sequence([
                .rotateTo(x: 0, y: 0, z: CGFloat(Float.random(in: -0.20...0.20)),
                          duration: Double.random(in: 25...50), usesShortestUnitArc: true),
                .rotateTo(x: 0, y: 0, z: CGFloat(Float.random(in: -0.20...0.20)),
                          duration: Double.random(in: 25...50), usesShortestUnitArc: true),
            ])))
            parent.addChildNode(node)
        }
    }

    // MARK: - Gas planet (PBR — physically based roughness/metalness)

    private static func addGasPlanet(to parent: SCNNode) {
        let planet = SCNNode()
        planet.position = SCNVector3(18, 5, -42)

        // --- Body (PBR, gas giant — rough, no metalness) ---
        let sphere = SCNSphere(radius: 3.2)
        let mat    = SCNMaterial()
        mat.lightingModel       = .physicallyBased
        mat.diffuse.contents    = makeGasBandTexture()
        mat.roughness.contents  = CGFloat(0.70)
        mat.metalness.contents  = CGFloat(0.04)
        mat.emission.contents   = NSColor(red: 0.12, green: 0.08, blue: 0.03, alpha: 1)
        mat.emission.intensity   = 0.4          // faint self-glow from atmospheric heat
        sphere.firstMaterial    = mat
        let body = SCNNode(geometry: sphere)
        body.runAction(.repeatForever(.rotateBy(x: 0, y: 1, z: 0, duration: 18)))
        planet.addChildNode(body)

        // --- Atmosphere haze ---
        let atmo = SCNSphere(radius: 3.65)
        let amat = SCNMaterial()
        amat.lightingModel    = .constant
        amat.diffuse.contents = NSColor(red: 0.85, green: 0.50, blue: 0.15, alpha: 0.08)
        amat.emission.contents = NSColor(red: 0.65, green: 0.35, blue: 0.08, alpha: 1)
        amat.emission.intensity = 0.3
        amat.blendMode = .add; amat.isDoubleSided = true; atmo.firstMaterial = amat
        planet.addChildNode(SCNNode(geometry: atmo))

        // --- Outer broad ring (PBR translucent) ---
        let r1   = SCNTube(innerRadius: 4.4, outerRadius: 8.4, height: 0.08)
        let rmat = SCNMaterial()
        rmat.lightingModel      = .physicallyBased
        rmat.diffuse.contents   = NSColor(red: 0.70, green: 0.52, blue: 0.28, alpha: 0.50)
        rmat.roughness.contents = CGFloat(0.55)
        rmat.metalness.contents = CGFloat(0.10)
        rmat.isDoubleSided = true; r1.firstMaterial = rmat
        let rn1 = SCNNode(geometry: r1)
        rn1.eulerAngles.x = CGFloat(Float.pi / 2 - 0.36)
        rn1.runAction(.repeatForever(.rotateBy(x: 0, y: 0.06, z: 0, duration: 65)))
        planet.addChildNode(rn1)

        // --- Inner bright ring (additive bloom band) ---
        let r2    = SCNTube(innerRadius: 5.0, outerRadius: 6.1, height: 0.06)
        let rmat2 = SCNMaterial()
        rmat2.lightingModel    = .constant
        rmat2.diffuse.contents = NSColor(red: 0.95, green: 0.80, blue: 0.55, alpha: 1)
        rmat2.emission.contents = NSColor(red: 0.95, green: 0.80, blue: 0.55, alpha: 1)
        rmat2.emission.intensity = 4.0            // bright ring blooms!
        rmat2.blendMode = .add; rmat2.isDoubleSided = true; r2.firstMaterial = rmat2
        let rn2 = SCNNode(geometry: r2)
        rn2.eulerAngles.x = CGFloat(Float.pi / 2 - 0.36)
        rn2.runAction(.repeatForever(.rotateBy(x: 0, y: -0.10, z: 0, duration: 48)))
        planet.addChildNode(rn2)

        // --- Outer wisp ---
        let r3    = SCNTube(innerRadius: 8.8, outerRadius: 11.5, height: 0.04)
        let rmat3 = SCNMaterial()
        rmat3.lightingModel    = .constant
        rmat3.diffuse.contents = NSColor(red: 0.55, green: 0.42, blue: 0.22, alpha: 0.18)
        rmat3.blendMode = .add; rmat3.isDoubleSided = true; r3.firstMaterial = rmat3
        let rn3 = SCNNode(geometry: r3)
        rn3.eulerAngles.x = CGFloat(Float.pi / 2 - 0.36)
        planet.addChildNode(rn3)

        // --- Moon (PBR rocky) ---
        let moon = SCNSphere(radius: 0.50)
        let mmat = SCNMaterial()
        mmat.lightingModel      = .physicallyBased
        mmat.diffuse.contents   = NSColor(white: 0.42, alpha: 1)
        mmat.roughness.contents = CGFloat(0.88)
        mmat.metalness.contents = CGFloat(0.01)
        moon.firstMaterial = mmat
        let moonOrbit = SCNNode()
        let moonNode  = SCNNode(geometry: moon)
        moonNode.position = SCNVector3(7.2, 0, 0)
        moonOrbit.addChildNode(moonNode)
        moonOrbit.eulerAngles.z = CGFloat(0.10)
        moonOrbit.runAction(.repeatForever(.rotateBy(x: 0, y: 1, z: 0, duration: 10)))
        planet.addChildNode(moonOrbit)

        // Warm point light on planet from the star direction — casts ring shadow
        let pLight = SCNNode()
        pLight.light = {
            let l = SCNLight(); l.type = .omni
            l.intensity = 1200
            l.color = NSColor(red: 1.0, green: 0.92, blue: 0.78, alpha: 1)
            l.attenuationStartDistance = 2; l.attenuationEndDistance = 80
            l.attenuationFalloffExponent = 2
            return l
        }()
        pLight.position = SCNVector3(12, 8, 18)   // relative to planet node
        planet.addChildNode(pLight)

        parent.addChildNode(planet)
    }

    private static func makeGasBandTexture() -> NSImage {
        let size = CGSize(width: 512, height: 512)
        let img  = NSImage(size: size)
        img.lockFocus()
        let bands: [(CGFloat, NSColor)] = [
            (0.00, NSColor(red: 0.90, green: 0.65, blue: 0.32, alpha: 1)),
            (0.08, NSColor(red: 0.68, green: 0.42, blue: 0.16, alpha: 1)),
            (0.17, NSColor(red: 0.96, green: 0.74, blue: 0.44, alpha: 1)),
            (0.26, NSColor(red: 0.72, green: 0.48, blue: 0.20, alpha: 1)),
            (0.35, NSColor(red: 0.58, green: 0.34, blue: 0.10, alpha: 1)),
            (0.46, NSColor(red: 0.88, green: 0.60, blue: 0.30, alpha: 1)),
            (0.57, NSColor(red: 0.76, green: 0.50, blue: 0.20, alpha: 1)),
            (0.67, NSColor(red: 0.94, green: 0.70, blue: 0.40, alpha: 1)),
            (0.78, NSColor(red: 0.65, green: 0.40, blue: 0.14, alpha: 1)),
            (0.88, NSColor(red: 0.82, green: 0.56, blue: 0.26, alpha: 1)),
            (1.00, NSColor(red: 0.90, green: 0.65, blue: 0.32, alpha: 1)),
        ]
        for i in 0..<bands.count - 1 {
            let sy = bands[i].0 * size.height; let ey = bands[i + 1].0 * size.height
            bands[i].1.setFill()
            NSRect(x: 0, y: sy, width: size.width, height: ey - sy).fill()
        }
        img.unlockFocus()
        return img
    }

    // MARK: - Asteroid field (mid-distance)

    private static func addAsteroidField(to parent: SCNNode) {
        for _ in 0..<45 {
            let sz  = CGFloat(Float.random(in: 0.08...0.55))
            let geo: SCNGeometry = Bool.random()
                ? SCNSphere(radius: sz)
                : SCNBox(width: sz * 1.5, height: sz, length: sz * 0.8, chamferRadius: sz * 0.10)
            let mat = SCNMaterial()
            mat.lightingModel      = .physicallyBased
            mat.diffuse.contents   = NSColor(
                red:   CGFloat.random(in: 0.18...0.42),
                green: CGFloat.random(in: 0.15...0.34),
                blue:  CGFloat.random(in: 0.08...0.22), alpha: 1)
            mat.roughness.contents = CGFloat(Float.random(in: 0.70...0.95))
            mat.metalness.contents = CGFloat(Float.random(in: 0.00...0.12))
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float.random(in: -32...32),
                Float.random(in: -12...12),
                Float.random(in: -30 ... -12)
            )
            node.runAction(.repeatForever(.rotateBy(
                x: CGFloat(Float.random(in: 0.3...2.5)),
                y: CGFloat(Float.random(in: 0.3...2.5)),
                z: CGFloat(Float.random(in: 0...0.8)),
                duration: Double.random(in: 3...14)
            )))
            parent.addChildNode(node)
        }
    }

    // MARK: - Close foreground rocks (extreme parallax depth cue)

    private static func addForegroundRocks(to parent: SCNNode) {
        // These are 22-27 units from the camera — near the DoF focus plane.
        // Moving your head makes them shift dramatically against the background.
        let configs: [(Float, Float, Float, Float)] = [
            // x,   y,   z,   size
            (-7,  -2,  -2,   0.90),
            ( 5,   2,  -3,   0.65),
            (-2,   4,  -4,   0.45),
            ( 9,  -1,  -2,   0.75),
            (-11,  1,  -5,   0.55),
            ( 2,  -3,  -3,   0.38),
        ]
        for (x, y, z, sz) in configs {
            let geo: SCNGeometry = Bool.random()
                ? SCNBox(width: CGFloat(sz)*1.5, height: CGFloat(sz), length: CGFloat(sz)*0.8,
                         chamferRadius: CGFloat(sz)*0.10)
                : SCNSphere(radius: CGFloat(sz))
            let mat = SCNMaterial()
            mat.lightingModel      = .physicallyBased
            mat.diffuse.contents   = NSColor(
                red:   CGFloat.random(in: 0.18...0.38),
                green: CGFloat.random(in: 0.15...0.30),
                blue:  CGFloat.random(in: 0.08...0.20), alpha: 1)
            mat.roughness.contents = CGFloat(0.88)
            mat.metalness.contents = CGFloat(0.02)
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(x, y, z)
            node.runAction(.repeatForever(.rotateBy(
                x: CGFloat(Float.random(in: 0.1...0.8)),
                y: CGFloat(Float.random(in: 0.1...0.8)),
                z: 0, duration: Double.random(in: 12...30)
            )))
            parent.addChildNode(node)
        }
    }

    // MARK: - Meteor shower (repeating forever — not one-shot)

    private static func addMeteorShower(to parent: SCNNode) {
        for i in 0..<14 {
            let len   = CGFloat(Float.random(in: 1.8...5.5))
            let trail = SCNBox(width: len, height: 0.04, length: 0.04, chamferRadius: 0)
            let mat   = SCNMaterial()
            mat.lightingModel    = .constant
            mat.diffuse.contents  = NSColor.white
            mat.emission.contents = NSColor.white
            mat.emission.intensity = 8.0          // bright streaks bloom hard
            mat.blendMode = .add; trail.firstMaterial = mat
            let node = SCNNode(geometry: trail)

            let sx = Float.random(in: -50 ... -8)
            let sy = Float.random(in: -10...18)
            let sz = Float.random(in: -70 ... -28)
            let ex = sx + Float.random(in: 50...70)
            let ey = sy - Float.random(in: 5...14)

            node.position     = SCNVector3(sx, sy, sz)
            node.eulerAngles.z = CGFloat(Float.random(in: -0.25...0.25))
            node.opacity      = 0
            parent.addChildNode(node)

            let initDelay = Double(i) * Double.random(in: 1.5...6.0)
            let flyDur    = Double.random(in: 0.6...1.5)
            let idleDur   = Double.random(in: 18...45)

            node.runAction(.sequence([
                .wait(duration: initDelay),
                .repeatForever(.sequence([
                    .group([
                        .fadeIn(duration: 0.04),
                        .move(to: SCNVector3(ex, ey, sz), duration: flyDur),
                    ]),
                    .fadeOut(duration: 0.06),
                    .run { n in n.position = SCNVector3(sx, sy, sz) },
                    .wait(duration: idleDur),
                ])),
            ]))
        }
    }
}
