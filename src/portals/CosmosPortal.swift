import AppKit
import SceneKit

public enum CosmosPortal {
    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.black

        addStarField(to: scene.rootNode, depth: -40)
        addNebula(to: scene.rootNode, depth: -28)
        addPlanet(to: scene.rootNode, depth: -16)
        addAsteroids(to: scene.rootNode, depth: -6)
        addPorthole(to: scene.rootNode, depth: -1)

        return scene
    }

    private static func addStarField(to parent: SCNNode, depth: Float) {
        let container = SCNNode()
        container.position.z = CGFloat(depth)
        for _ in 0..<600 {
            let r = CGFloat(Float.random(in: 0.02...0.12))
            let geo = SCNSphere(radius: r)
            let mat = SCNMaterial()
            mat.diffuse.contents  = NSColor.white
            mat.emission.contents = NSColor(white: 0.9, alpha: 1)
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float.random(in: -30...30),
                Float.random(in: -18...18),
                Float.random(in: -3...3)
            )
            container.addChildNode(node)
        }
        container.runAction(.repeatForever(.rotateBy(x: 0, y: 0.05, z: 0, duration: 60)))
        parent.addChildNode(container)
    }

    private static func addNebula(to parent: SCNNode, depth: Float) {
        let plane = SCNPlane(width: 60, height: 36)
        let mat   = SCNMaterial()
        let grad  = NSGradient(colors: [
            NSColor(red: 0.5, green: 0.0, blue: 0.8, alpha: 0.6),
            NSColor(red: 0.0, green: 0.0, blue: 0.3, alpha: 0.0)
        ])!
        let img = NSImage(size: CGSize(width: 256, height: 256))
        img.lockFocus()
        grad.draw(in: NSRect(origin: .zero, size: CGSize(width: 256, height: 256)), angle: 45)
        img.unlockFocus()
        mat.diffuse.contents  = img
        mat.blendMode         = .add
        mat.isDoubleSided     = true
        plane.firstMaterial   = mat
        let node = SCNNode(geometry: plane)
        node.position.z = CGFloat(depth)
        parent.addChildNode(node)
    }

    private static func addPlanet(to parent: SCNNode, depth: Float) {
        let sphere = SCNSphere(radius: 4)
        let mat    = SCNMaterial()
        mat.diffuse.contents  = makeGradientImage(
            colors: [NSColor.cyan, NSColor.blue, NSColor(red: 0, green: 0.3, blue: 0.6, alpha: 1)]
        )
        mat.specular.contents = NSColor.white
        mat.shininess = 50
        sphere.firstMaterial = mat
        let planet = SCNNode(geometry: sphere)
        planet.position.z = CGFloat(depth)
        planet.runAction(.repeatForever(.rotateBy(x: 0, y: 0.2, z: 0, duration: 8)))

        let atmo = SCNSphere(radius: 4.25)
        let amat = SCNMaterial()
        amat.diffuse.contents  = NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.18)
        amat.emission.contents = NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 0.3)
        amat.blendMode = .add
        amat.isDoubleSided = true
        atmo.firstMaterial = amat
        planet.addChildNode(SCNNode(geometry: atmo))

        parent.addChildNode(planet)
    }

    private static func addAsteroids(to parent: SCNNode, depth: Float) {
        let positions: [(Float, Float)] = [
            (-8,3),(5,-2),(-3,5),(9,1),(-6,-4),(4,6),
            (-10,0),(7,-5),(2,4),(-4,-6),(8,3),(-1,-3)
        ]
        for (x, y) in positions {
            let size = CGFloat(Float.random(in: 0.2...0.7))
            let geo  = SCNSphere(radius: size)
            let mat  = SCNMaterial()
            mat.diffuse.contents = NSColor(white: CGFloat.random(in: 0.3...0.5), alpha: 1)
            geo.firstMaterial    = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(x, y, depth)
            node.runAction(.repeatForever(
                .rotateBy(x: 1, y: 1, z: 0.3, duration: Double.random(in: 4...12))
            ))
            parent.addChildNode(node)
        }
    }

    private static func addPorthole(to parent: SCNNode, depth: Float) {
        let tube = SCNTube(innerRadius: 8, outerRadius: 9.5, height: 0.5)
        let mat  = SCNMaterial()
        mat.diffuse.contents  = NSColor(white: 0.25, alpha: 1)
        mat.specular.contents = NSColor.white
        mat.shininess = 80
        tube.firstMaterial = mat
        let frame = SCNNode(geometry: tube)
        frame.position.z     = CGFloat(depth)
        frame.eulerAngles.x  = .pi / 2
        parent.addChildNode(frame)
    }

    private static func makeGradientImage(colors: [NSColor]) -> NSImage {
        let size = CGSize(width: 256, height: 256)
        let img  = NSImage(size: size)
        img.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext,
              let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map(\.cgColor) as CFArray,
                locations: nil
              )
        else { img.unlockFocus(); return img }
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: 0, y: 0),
                               end:   CGPoint(x: size.width, y: size.height),
                               options: [])
        img.unlockFocus()
        return img
    }
}
