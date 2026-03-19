import AppKit
import SceneKit

/// Street-level view of a rainy cyberpunk city.
/// SCNFloor provides real-time planar reflections of neon lights on wet asphalt.
/// Depth zones: barrier z≈-1, lamps z=-3…-42, buildings z=-2…-50, sky z=-60
public enum MidnightCityPortal {
    private static let roadY: Float = -8

    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.black
        scene.fogColor           = NSColor(red: 0.04, green: 0.00, blue: 0.09, alpha: 1)
        scene.fogStartDistance   = 12
        scene.fogEndDistance     = 55
        scene.fogDensityExponent = 1.0

        addLighting(to: scene.rootNode)
        addSky(to: scene.rootNode)
        addRoad(to: scene.rootNode)
        addBuildings(to: scene.rootNode)
        addStreetLights(to: scene.rootNode)
        addForegroundBarrier(to: scene.rootNode)
        addRain(to: scene.rootNode)

        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        // Deep purple ambient — barely visible
        let amb = SCNNode()
        amb.light = {
            let l = SCNLight(); l.type = .ambient
            l.intensity = 50; l.color = NSColor(red: 0.04, green: 0.00, blue: 0.10, alpha: 1)
            return l
        }()
        parent.addChildNode(amb)

        // Overcast sky fill from above
        let sky = SCNNode()
        sky.light = {
            let l = SCNLight(); l.type = .directional
            l.intensity = 100; l.color = NSColor(red: 0.06, green: 0.04, blue: 0.18, alpha: 1)
            return l
        }()
        sky.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        parent.addChildNode(sky)

        // Hot-pink neon fill from left building face
        let pink = SCNNode()
        pink.light = {
            let l = SCNLight(); l.type = .omni
            l.intensity = 600; l.color = NSColor(red: 1.0, green: 0.05, blue: 0.48, alpha: 1)
            l.attenuationStartDistance = 0; l.attenuationEndDistance = 40
            l.attenuationFalloffExponent = 2
            return l
        }()
        pink.position = SCNVector3(-14, roadY + 8, -8)
        parent.addChildNode(pink)

        // Cyan neon fill from right
        let cyan = SCNNode()
        cyan.light = {
            let l = SCNLight(); l.type = .omni
            l.intensity = 500; l.color = NSColor(red: 0.00, green: 0.80, blue: 1.00, alpha: 1)
            l.attenuationStartDistance = 0; l.attenuationEndDistance = 40
            l.attenuationFalloffExponent = 2
            return l
        }()
        cyan.position = SCNVector3(14, roadY + 8, -12)
        parent.addChildNode(cyan)
    }

    // MARK: - Sky backdrop

    private static func addSky(to parent: SCNNode) {
        let plane = SCNPlane(width: 120, height: 80)
        let img   = NSImage(size: CGSize(width: 2, height: 512))
        img.lockFocus()
        NSGradient(colors: [
            NSColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1),
            NSColor(red: 0.04, green: 0.01, blue: 0.12, alpha: 1),
            NSColor(red: 0.10, green: 0.03, blue: 0.20, alpha: 1),
            NSColor(red: 0.05, green: 0.01, blue: 0.14, alpha: 1),
        ])!.draw(in: NSRect(origin: .zero, size: CGSize(width: 2, height: 512)), angle: 90)
        img.unlockFocus()
        let mat = SCNMaterial()
        mat.lightingModel     = .constant
        mat.diffuse.contents  = img
        mat.emission.contents = img
        mat.emission.intensity = 0.5
        plane.firstMaterial   = mat
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, 22, -60)
        parent.addChildNode(node)
    }

    // MARK: - Road (SCNFloor — real-time planar reflections of neon lights)

    private static func addRoad(to parent: SCNNode) {
        // SCNFloor gives real SceneKit planar reflections — neon lamps reflect on wet asphalt
        let floor = SCNFloor()
        floor.reflectivity         = 0.55
        floor.reflectionFalloffEnd = 18
        let fmat = SCNMaterial()
        fmat.lightingModel      = .physicallyBased
        fmat.diffuse.contents   = makeAsphaltTexture()
        fmat.roughness.contents = CGFloat(0.18)  // low roughness = shiny wet asphalt
        fmat.metalness.contents = CGFloat(0.00)
        floor.firstMaterial = fmat
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, roadY, 0)
        parent.addChildNode(floorNode)

        // Raised sidewalks on both sides (PBR concrete, above the reflective floor)
        for side: Float in [-1, 1] {
            let walk = SCNPlane(width: 8, height: 120)
            let wmat = SCNMaterial()
            wmat.lightingModel      = .physicallyBased
            wmat.diffuse.contents   = NSColor(red: 0.055, green: 0.055, blue: 0.060, alpha: 1)
            wmat.roughness.contents = CGFloat(0.85)
            wmat.metalness.contents = CGFloat(0.00)
            wmat.isDoubleSided = true
            walk.firstMaterial = wmat
            let wNode = SCNNode(geometry: walk)
            wNode.eulerAngles.x = CGFloat(-Float.pi / 2)
            wNode.position = SCNVector3(side * 11, roadY + 0.18, -40)
            parent.addChildNode(wNode)
        }

        // Lane markings floating just above road surface
        let lanes = SCNPlane(width: 14, height: 120)
        let lmat  = SCNMaterial()
        lmat.lightingModel    = .constant
        lmat.diffuse.contents = makeLaneMarkingTexture()
        lmat.blendMode = .add; lmat.isDoubleSided = true
        lanes.firstMaterial = lmat
        let lNode = SCNNode(geometry: lanes)
        lNode.eulerAngles.x = CGFloat(-Float.pi / 2)
        lNode.position = SCNVector3(0, roadY + 0.05, -40)
        parent.addChildNode(lNode)

        // Neon puddle-reflection overlay
        let puddles = SCNPlane(width: 14, height: 120)
        let pmat    = SCNMaterial()
        pmat.lightingModel    = .constant
        pmat.diffuse.contents = makeReflectionTexture()
        pmat.blendMode = .add; pmat.isDoubleSided = true
        puddles.firstMaterial = pmat
        let pNode = SCNNode(geometry: puddles)
        pNode.eulerAngles.x = CGFloat(-Float.pi / 2)
        pNode.position = SCNVector3(0, roadY + 0.08, -40)
        parent.addChildNode(pNode)
    }

    private static func makeAsphaltTexture() -> NSImage {
        let size = CGSize(width: 256, height: 256)
        let img  = NSImage(size: size)
        img.lockFocus()
        NSColor(red: 0.038, green: 0.038, blue: 0.042, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        img.unlockFocus()
        return img
    }

    private static func makeLaneMarkingTexture() -> NSImage {
        let size = CGSize(width: 256, height: 512)
        let img  = NSImage(size: size)
        img.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        // Centre dashed white line
        NSColor(red: 0.58, green: 0.54, blue: 0.28, alpha: 0.65).setFill()
        for y in stride(from: 12.0 as CGFloat, to: size.height, by: 48) {
            NSRect(x: size.width / 2 - 5, y: y, width: 10, height: 26).fill()
        }
        img.unlockFocus()
        return img
    }

    private static func makeReflectionTexture() -> NSImage {
        let size = CGSize(width: 256, height: 256)
        let img  = NSImage(size: size)
        img.lockFocus()
        NSGradient(colors: [
            NSColor(red: 0.60, green: 0.00, blue: 0.30, alpha: 0.18),
            NSColor(red: 0.00, green: 0.30, blue: 0.60, alpha: 0.10),
            NSColor(red: 0.40, green: 0.00, blue: 0.60, alpha: 0.14),
        ])!.draw(in: NSRect(origin: .zero, size: size), angle: 90)
        img.unlockFocus()
        return img
    }

    // MARK: - Buildings (PBR concrete — rough = 0.90, neon roofline bloom)

    private static func addBuildings(to parent: SCNNode) {
        let neonColors: [NSColor] = [
            NSColor(red: 1.0, green: 0.08, blue: 0.50, alpha: 1),
            NSColor(red: 0.0, green: 0.90, blue: 1.00, alpha: 1),
            NSColor(red: 0.6, green: 0.00, blue: 1.00, alpha: 1),
            NSColor(red: 1.0, green: 0.60, blue: 0.00, alpha: 1),
            NSColor(red: 0.0, green: 1.00, blue: 0.50, alpha: 1),
        ]
        let zDepths: [Float] = [-2, -9, -17, -25, -33, -42, -50]

        for (idx, z) in zDepths.enumerated() {
            for side: Float in [-1, 1] {
                let height = Float.random(in: 12...28)
                let width  = Float.random(in: 5...9)
                let depth  = Float.random(in: 4...8)
                let accent = neonColors[idx % neonColors.count]

                let box = SCNBox(width: CGFloat(width), height: CGFloat(height),
                                 length: CGFloat(depth), chamferRadius: 0.04)
                let mat = SCNMaterial()
                mat.lightingModel      = .physicallyBased
                mat.diffuse.contents   = NSColor(
                    red:   CGFloat.random(in: 0.04...0.09),
                    green: CGFloat.random(in: 0.04...0.08),
                    blue:  CGFloat.random(in: 0.06...0.12), alpha: 1)
                mat.roughness.contents = CGFloat(0.90)  // rough poured concrete
                mat.metalness.contents = CGFloat(0.00)
                box.firstMaterial = mat

                let node = SCNNode(geometry: box)
                let xOffset = side * (7 + width / 2 + Float.random(in: 0...2))
                node.position = SCNVector3(xOffset, roadY + height / 2, z)

                addNeonTrim(to: node, width: CGFloat(width), depth: CGFloat(depth),
                            height: CGFloat(height), colour: accent)
                addWindowLights(to: node, width: CGFloat(width), height: CGFloat(height))
                parent.addChildNode(node)
            }
        }
    }

    private static func addNeonTrim(to building: SCNNode,
                                    width: CGFloat, depth: CGFloat,
                                    height: CGFloat, colour: NSColor) {
        let trim = SCNBox(width: width + 0.15, height: 0.16, length: depth + 0.15, chamferRadius: 0)
        let mat  = SCNMaterial()
        mat.lightingModel     = .constant
        mat.diffuse.contents  = colour
        mat.emission.contents = colour
        mat.emission.intensity = 5.0    // roofline neon blooms!
        mat.blendMode = .add
        trim.firstMaterial = mat
        let node = SCNNode(geometry: trim)
        node.position.y = height / 2 + 0.08
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
                let win  = SCNBox(width: 0.36, height: 0.56, length: 0.06, chamferRadius: 0)
                let col  = palette.randomElement()!
                let wmat = SCNMaterial()
                wmat.lightingModel    = .constant
                wmat.diffuse.contents  = col
                wmat.emission.contents = col
                wmat.emission.intensity = 2.0   // windows glow in HDR
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

    // MARK: - Street lights (real omni lights + HDR bloom globes)

    private static func addStreetLights(to parent: SCNNode) {
        let zDepths: [Float] = [-3, -12, -22, -32, -42]
        let warmCol = NSColor(red: 1.0, green: 0.88, blue: 0.60, alpha: 1)

        for z in zDepths {
            for side: Float in [-1, 1] {
                // Pole (PBR metal)
                let pole = SCNCylinder(radius: 0.12, height: 12)
                let pmat = SCNMaterial()
                pmat.lightingModel      = .physicallyBased
                pmat.diffuse.contents   = NSColor(white: 0.10, alpha: 1)
                pmat.roughness.contents = CGFloat(0.65)
                pmat.metalness.contents = CGFloat(0.60)
                pole.firstMaterial = pmat
                let pNode = SCNNode(geometry: pole)
                pNode.position = SCNVector3(side * 7.5, roadY + 6, z)
                parent.addChildNode(pNode)

                // Lamp globe (emission.intensity = 8 → blooms hard in HDR)
                let lamp = SCNSphere(radius: 0.48)
                let lmat = SCNMaterial()
                lmat.lightingModel     = .constant
                lmat.diffuse.contents  = warmCol
                lmat.emission.contents = warmCol
                lmat.emission.intensity = 8.0
                lmat.blendMode = .add
                lamp.firstMaterial = lmat
                let lNode = SCNNode(geometry: lamp)
                lNode.position = SCNVector3(side * 7.5, roadY + 12.6, z)
                parent.addChildNode(lNode)

                // Actual omni light — illuminates road and building faces
                let lightNode = SCNNode()
                lightNode.light = {
                    let l = SCNLight(); l.type = .omni
                    l.intensity = 700
                    l.color = warmCol
                    l.temperature = 3200
                    l.attenuationStartDistance   = 0
                    l.attenuationEndDistance     = 22
                    l.attenuationFalloffExponent = 2
                    return l
                }()
                lightNode.position = SCNVector3(side * 7.5, roadY + 12.6, z)
                parent.addChildNode(lightNode)
            }
        }
    }

    // MARK: - Foreground barrier (z≈-1, extreme parallax depth cue)

    private static func addForegroundBarrier(to parent: SCNNode) {
        // Jersey barrier segments very close to camera — shift dramatically with head movement
        let configs: [(Float, Float)] = [(-6, -1.2), (5, -1.5), (-1, -2.0)]
        for (x, z) in configs {
            let barrier = SCNBox(width: 1.2, height: 1.0, length: 0.5, chamferRadius: 0.06)
            let mat = SCNMaterial()
            mat.lightingModel      = .physicallyBased
            mat.diffuse.contents   = NSColor(red: 0.22, green: 0.22, blue: 0.25, alpha: 1)
            mat.roughness.contents = CGFloat(0.92)
            mat.metalness.contents = CGFloat(0.02)
            barrier.firstMaterial = mat
            let node = SCNNode(geometry: barrier)
            node.position = SCNVector3(x, roadY + 0.5, z)
            parent.addChildNode(node)

            // Orange reflective safety stripe
            let stripe = SCNBox(width: 1.22, height: 0.10, length: 0.06, chamferRadius: 0)
            let smat   = SCNMaterial()
            smat.lightingModel     = .constant
            smat.diffuse.contents  = NSColor(red: 1.0, green: 0.50, blue: 0.0, alpha: 1)
            smat.emission.contents = NSColor(red: 1.0, green: 0.50, blue: 0.0, alpha: 1)
            smat.emission.intensity = 4.0
            smat.blendMode = .add
            stripe.firstMaterial = smat
            let sNode = SCNNode(geometry: stripe)
            sNode.position = SCNVector3(x, roadY + 0.75, z)
            parent.addChildNode(sNode)
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
        emitter.eulerAngles = SCNVector3(-Float.pi / 2 + 0.22, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }
}
