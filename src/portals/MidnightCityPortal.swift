import AppKit
import SceneKit

public enum MidnightCityPortal {
    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.black

        addSky(to: scene.rootNode, depth: -35)
        addTowers(to: scene.rootNode, depth: -22)
        addNeonMidground(to: scene.rootNode, depth: -12)
        addRain(to: scene.rootNode, depth: -5)
        addWindowFrame(to: scene.rootNode, depth: -1)

        return scene
    }

    private static func addSky(to parent: SCNNode, depth: Float) {
        let plane = SCNPlane(width: 80, height: 50)
        let mat   = SCNMaterial()
        let grad  = NSGradient(colors: [
            .black,
            NSColor(red: 0.04, green: 0.0, blue: 0.12, alpha: 1)
        ])!
        let img = NSImage(size: CGSize(width: 2, height: 256))
        img.lockFocus()
        grad.draw(in: NSRect(origin: .zero, size: CGSize(width: 2, height: 256)), angle: 90)
        img.unlockFocus()
        mat.diffuse.contents = img
        plane.firstMaterial  = mat
        let node = SCNNode(geometry: plane)
        node.position.z = CGFloat(depth)
        parent.addChildNode(node)
    }

    private static func addTowers(to parent: SCNNode, depth: Float) {
        let container = SCNNode()
        container.position.z = CGFloat(depth)
        let neonColors: [NSColor] = [
            NSColor(red: 1, green: 0.1, blue: 0.5, alpha: 1),
            NSColor(red: 0, green: 0.9, blue: 1.0, alpha: 1),
            NSColor(red: 0.6, green: 0, blue: 1.0, alpha: 1),
            NSColor(red: 1, green: 0.6, blue: 0, alpha: 1),
        ]
        for i in -15...15 {
            let height = Float.random(in: 4...18)
            let width  = Float.random(in: 0.8...2.2)
            let box    = SCNBox(width: CGFloat(width), height: CGFloat(height), length: 1.5, chamferRadius: 0)
            let mat    = SCNMaterial()
            mat.diffuse.contents  = NSColor(white: 0.05, alpha: 1)
            mat.emission.contents = neonColors.randomElement()!.withAlphaComponent(0.08)
            box.firstMaterial     = mat
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(
                Float(i) * 2.2 + Float.random(in: -0.5...0.5),
                height / 2 - 10,
                Float.random(in: -3...3)
            )
            container.addChildNode(node)
        }
        parent.addChildNode(container)
    }

    private static func addNeonMidground(to parent: SCNNode, depth: Float) {
        let mat = SCNMaterial()
        mat.diffuse.contents  = NSColor(red: 1, green: 0.1, blue: 0.6, alpha: 1)
        mat.emission.contents = NSColor(red: 1, green: 0.1, blue: 0.6, alpha: 1)

        let strip = SCNBox(width: 50, height: 0.4, length: 1, chamferRadius: 0)
        strip.firstMaterial = mat
        let glow = SCNNode(geometry: strip)
        glow.position = SCNVector3(0, -2, Float(depth))
        parent.addChildNode(glow)

        for x: Float in [-12, -4, 4, 12] {
            let pillar = SCNBox(width: 0.3, height: 6, length: 0.3, chamferRadius: 0)
            pillar.firstMaterial = mat
            let p = SCNNode(geometry: pillar)
            p.position = SCNVector3(x, -5, Float(depth))
            parent.addChildNode(p)
        }
    }

    private static func addRain(to parent: SCNNode, depth: Float) {
        let ps = SCNParticleSystem()
        ps.birthRate                 = 800
        ps.particleLifeSpan          = 0.6
        ps.particleVelocity          = 30
        ps.particleVelocityVariation = 5
        ps.emitterShape              = SCNPlane(width: 40, height: 0)
        ps.particleSize              = 0.04
        ps.particleColor             = NSColor(white: 0.8, alpha: 0.6)
        ps.blendMode                 = .additive

        let emitter = SCNNode()
        emitter.position    = SCNVector3(0, 12, Float(depth))
        emitter.eulerAngles = SCNVector3(-.pi / 2 + 0.15, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }

    private static func addWindowFrame(to parent: SCNNode, depth: Float) {
        func bar(w: CGFloat, h: CGFloat, x: Float, y: Float) {
            let box = SCNBox(width: w, height: h, length: 0.2, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents  = NSColor(white: 0.15, alpha: 0.9)
            mat.specular.contents = NSColor.white
            mat.shininess = 60
            box.firstMaterial = mat
            let n = SCNNode(geometry: box)
            n.position = SCNVector3(x, y, Float(depth))
            parent.addChildNode(n)
        }
        bar(w: 22, h: 0.6,  x: 0,   y:  9)
        bar(w: 22, h: 0.6,  x: 0,   y: -9)
        bar(w: 0.6, h: 18,  x: -11, y:  0)
        bar(w: 0.6, h: 18,  x:  11, y:  0)
    }
}
