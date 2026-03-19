# Portal Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completely rewrite all three portals (Cosmos, Midnight City, Abyss) to be dense, immersive, visually stunning 3D environments worthy of a premium macOS wallpaper app.

**Architecture:** Each portal is a self-contained Swift `enum` in `src/portals/` that returns an `SCNScene`. All improvements are pure SceneKit — no external assets, no additional dependencies. Textures are generated procedurally with `NSImage`/`NSGradient`/`NSBezierPath`, particles use `SCNParticleSystem`, and animations use `SCNAction` chains.

**Tech Stack:** Swift 5.9+, SceneKit (SCNScene, SCNNode, SCNGeometry, SCNMaterial, SCNParticleSystem, SCNAction, SCNLight), AppKit (NSImage, NSGradient, NSBezierPath, NSColor)

---

## Design Principles for All Portals

Before touching any file, internalize these rules — they're the difference between "floating objects" and "a real place":

1. **Layered depth**: Objects must span at least 5 distinct Z bands (e.g., z=-2, -8, -18, -35, -60). Parallax only feels real when depth varies widely.
2. **Everything moves**: If an object is static the scene feels dead. Every element gets at least a gentle SCNAction (sway, drift, pulse, rotate).
3. **Multiple coloured lights**: At least one ambient + one directional + 2–3 coloured point lights to give mood and prevent flat-lit look.
4. **Additive glow on emitters**: Any light-source geometry (neon, stars, bioluminescence) uses `mat.blendMode = .add` so black = invisible. Never use alpha alone.
5. **Fog is mandatory for ground environments**: Fog turns a flat room into a world. Set `fogStartDistance` to ~30% of scene depth and `fogEndDistance` to ~80%.
6. **Procedural textures > flat colours**: Even a simple 2-colour gradient on a geometry makes it look hand-crafted vs. toy-like.
7. **Never place objects in a grid**: Use explicit position lists or scatter with intentional gaps. Avoid `for i in 0..<N { random() }` for principal elements.

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `src/portals/CosmosPortal.swift` | **Rewrite** | Deep space: galaxy, nebulae volumes, ringed planet with storm, comets, repeating meteors |
| `src/portals/MidnightCityPortal.swift` | **Rewrite** | Cyberpunk city: deep building canyons, holo-billboards, moving vehicles, steam vents, aerial traffic |
| `src/portals/AbyssPortal.swift` | **Rewrite** | Deep ocean: caustic floor, kelp forest, whale, thermal vent, bioluminescent jellyfish swarm |
| `src/portals/PortalScene.swift` | No change | Portal enum — untouched |
| `tests/` | No change | All 28 existing tests must still pass |

---

## Task 1: CosmosPortal — Deep Space Overhaul

**Files:**
- Modify: `src/portals/CosmosPortal.swift` (full rewrite)

### What makes it better

Current problems: flat rectangle nebulae, only 1000 stars all at same depth band, planet has okay rings but no personality, shooting stars fire once and stop, no sense of "galaxy scale".

New design:
- **Galaxy disc** at z=-180: large flat plane with a swirling spiral texture (dark → star-white radial gradient, rotated slowly)
- **Three nebula layers** per cloud (3 overlapping planes at ±z=2 offset, different scale/rotation) using radial gradient + `.add` blend → looks volumetric
- **Star halos**: every 5th star gets a large faint additive plane behind it for a bloom effect
- **Stars in a sphere**: scatter stars in all directions (x ±100, y ±60, z -200 to -5) not just a flat band
- **Gas planet improvements**: storm spot (small ellipse geometry on planet surface), rings have 3 bands with different opacity + independent slow rotation, moons at two different orbital radii
- **Comet**: single SCNNode that moves across scene pulling a particle trail, repeats on long delay
- **Repeating meteors**: shooting stars use `.sequence([...]).repeatForever` with randomised wait, not `.removeFromParentNode()`
- **Deep space point light**: warm off-axis `SCNLight.spot` mimicking a distant star casting shadows on planet

- [ ] **Step 1: Replace `CosmosPortal.swift` with the new implementation**

```swift
import AppKit
import SceneKit

/// Deep-space panorama. The viewer floats in open space.
/// Scene depth: z = 0 (camera) → z = -200 (galaxy disc backdrop)
public enum CosmosPortal {
    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.00, green: 0.00, blue: 0.015, alpha: 1)
        // Very gentle fog only at extreme depth so stars don't vanish
        scene.fogColor           = NSColor(red: 0.00, green: 0.00, blue: 0.015, alpha: 1)
        scene.fogStartDistance   = 140
        scene.fogEndDistance     = 220
        scene.fogDensityExponent = 1.0

        addLighting(to: scene.rootNode)
        addGalaxyDisc(to: scene.rootNode)
        addStarField(to: scene.rootNode)
        addNebulae(to: scene.rootNode)
        addGasPlanet(to: scene.rootNode)
        addAsteroidBelt(to: scene.rootNode)
        addComet(to: scene.rootNode)
        addMeteorShower(to: scene.rootNode)
        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        // Deep blue-black ambient
        let amb = SCNNode()
        amb.light = {
            let l = SCNLight(); l.type = .ambient
            l.intensity = 60; l.color = NSColor(red: 0.03, green: 0.03, blue: 0.14, alpha: 1)
            return l
        }()
        parent.addChildNode(amb)

        // Main star: warm directional from upper-left
        let sun = SCNNode()
        sun.light = {
            let l = SCNLight(); l.type = .directional
            l.intensity = 1100; l.color = NSColor(red: 1.00, green: 0.92, blue: 0.80, alpha: 1)
            return l
        }()
        sun.eulerAngles = SCNVector3(-0.35, 0.70, 0)
        parent.addChildNode(sun)

        // Subtle fill from opposite side (blue-violet bounce)
        let fill = SCNNode()
        fill.light = {
            let l = SCNLight(); l.type = .directional
            l.intensity = 200; l.color = NSColor(red: 0.10, green: 0.10, blue: 0.55, alpha: 1)
            return l
        }()
        fill.eulerAngles = SCNVector3(0.20, -0.60, 0)
        parent.addChildNode(fill)
    }

    // MARK: - Galaxy disc backdrop

    private static func addGalaxyDisc(to parent: SCNNode) {
        let size = CGSize(width: 512, height: 512)
        let img  = NSImage(size: size)
        img.lockFocus()
        // Black fill
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()
        // Layered radial gradients: core → arms → outer void
        let centre = NSPoint(x: 0, y: 0)           // NSGradient uses -1…1
        NSGradient(colors: [
            NSColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1),
            NSColor(red: 0.30, green: 0.20, blue: 0.50, alpha: 1),
            NSColor(red: 0.06, green: 0.04, blue: 0.15, alpha: 1),
            NSColor.black,
        ], atLocations: [0, 0.20, 0.55, 1.0],
           colorSpace: .genericRGB)!
            .draw(in: NSRect(origin: .zero, size: size), relativeCenterPosition: centre)
        // Spiral arm suggestion: two faint arcs using partial-ring strokes
        let arcCol = NSColor(red: 0.80, green: 0.75, blue: 0.95, alpha: 0.08)
        arcCol.setStroke()
        for offset: CGFloat in [0, .pi] {
            let path = NSBezierPath()
            path.lineWidth = 22
            path.appendArc(withCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                           radius: size.width * 0.30,
                           startAngle: offset * 180 / .pi,
                           endAngle:   (offset + .pi) * 180 / .pi)
            path.stroke()
        }
        img.unlockFocus()

        let plane = SCNPlane(width: 280, height: 280)
        let mat   = SCNMaterial()
        mat.diffuse.contents = img; mat.blendMode = .add; mat.isDoubleSided = true
        plane.firstMaterial  = mat
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, -10, -190)
        node.eulerAngles.x = CGFloat(Float.pi * 0.08)   // slight tilt for drama
        node.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: CGFloat(Float.pi * 2), duration: 900)))
        parent.addChildNode(node)
    }

    // MARK: - Star field (sphere distribution, 1500 stars)

    private static func addStarField(to parent: SCNNode) {
        let container = SCNNode()
        for i in 0..<1500 {
            let r   = CGFloat(Float.random(in: 0.012...0.12))
            let geo = SCNSphere(radius: r)
            let col = starColour()
            let mat = SCNMaterial()
            mat.diffuse.contents = col; mat.emission.contents = col
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float.random(in: -110...110),
                Float.random(in: -65...65),
                Float.random(in: -195 ... -6)
            )
            container.addChildNode(node)

            // Every 7th star: large faint bloom halo behind it
            if i % 7 == 0 {
                let halo = SCNPlane(width: r * 18, height: r * 18)
                let hmat = SCNMaterial()
                hmat.diffuse.contents  = col.withAlphaComponent(0.18)
                hmat.blendMode = .add; hmat.isDoubleSided = true
                halo.firstMaterial = hmat
                let hNode = SCNNode(geometry: halo)
                hNode.position = node.position
                container.addChildNode(hNode)
            }
        }
        container.runAction(.repeatForever(.rotateBy(x: 0.004, y: 0.018, z: 0, duration: 120)))
        parent.addChildNode(container)
    }

    private static func starColour() -> NSColor {
        let b = CGFloat(Float.random(in: 0.50...1.0))
        switch Float.random(in: 0...1) {
        case ..<0.60: return NSColor(white: b, alpha: 1)                                      // white
        case ..<0.78: return NSColor(red: b * 0.72, green: b * 0.82, blue: b,        alpha: 1) // blue-white
        case ..<0.90: return NSColor(red: b,        green: b * 0.88, blue: b * 0.48, alpha: 1) // yellow
        default:      return NSColor(red: b,        green: b * 0.38, blue: b * 0.18, alpha: 1) // red giant
        }
    }

    // MARK: - Nebulae (3 clouds, each 3 overlapping planes for volume)

    private static func addNebulae(to parent: SCNNode) {
        nebulaCloud(parent, hue: NSColor(red: 0.28, green: 0.00, blue: 0.60, alpha: 1),
                    accentHue: NSColor(red: 0.55, green: 0.00, blue: 0.35, alpha: 1),
                    pos: SCNVector3(14, 8, -95))
        nebulaCloud(parent, hue: NSColor(red: 0.60, green: 0.15, blue: 0.00, alpha: 1),
                    accentHue: NSColor(red: 0.35, green: 0.00, blue: 0.55, alpha: 1),
                    pos: SCNVector3(-20, -4, -80))
        nebulaCloud(parent, hue: NSColor(red: 0.00, green: 0.22, blue: 0.60, alpha: 1),
                    accentHue: NSColor(red: 0.00, green: 0.45, blue: 0.30, alpha: 1),
                    pos: SCNVector3(-5, 14, -110))
    }

    /// Three overlapping radial-gradient planes at slightly different Z/rotation — looks volumetric.
    private static func nebulaCloud(_ parent: SCNNode, hue: NSColor, accentHue: NSColor, pos: SCNVector3) {
        let sizes: [(CGFloat, CGFloat)] = [(95, 62), (72, 48), (55, 38)]
        let zOffsets: [Float]           = [0, 4, -4]
        let colours: [NSColor]          = [hue, accentHue, hue]

        for (i, ((w, h), zOff, col)) in zip(zip(sizes, zOffsets), colours).enumerated() {
            let plane = SCNPlane(width: w, height: h)
            let imgSz = CGSize(width: 256, height: 256)
            let img   = NSImage(size: imgSz)
            img.lockFocus()
            NSColor.black.setFill(); NSRect(origin: .zero, size: imgSz).fill()
            NSGradient(starting: col, ending: .black)!
                .draw(in: NSRect(origin: .zero, size: imgSz), relativeCenterPosition: NSPoint(x: 0, y: 0))
            img.unlockFocus()
            let mat = SCNMaterial()
            mat.diffuse.contents = img; mat.blendMode = .add; mat.isDoubleSided = true
            plane.firstMaterial  = mat
            let node = SCNNode(geometry: plane)
            node.position = SCNVector3(pos.x, pos.y, pos.z + zOff)
            node.eulerAngles.z   = CGFloat(Float(i) * 0.38)
            node.eulerAngles.y   = CGFloat(Float(i) * 0.15)
            // Slow drift
            node.runAction(.repeatForever(.sequence([
                .rotateTo(x: CGFloat(Float.random(in: -0.05...0.05)),
                          y: CGFloat(Float.random(in: -0.08...0.08)),
                          z: node.eulerAngles.z + CGFloat(Float.random(in: -0.12...0.12)),
                          duration: Double.random(in: 20...40), usesShortestUnitArc: true),
                .rotateTo(x: CGFloat(Float.random(in: -0.05...0.05)),
                          y: CGFloat(Float.random(in: -0.08...0.08)),
                          z: node.eulerAngles.z + CGFloat(Float.random(in: -0.12...0.12)),
                          duration: Double.random(in: 20...40), usesShortestUnitArc: true),
            ])))
            parent.addChildNode(node)
        }
    }

    // MARK: - Gas planet

    private static func addGasPlanet(to parent: SCNNode) {
        let planet = SCNNode()
        planet.position = SCNVector3(18, 5, -45)

        // Body
        let sphere = SCNSphere(radius: 3.2)
        let mat    = SCNMaterial()
        mat.diffuse.contents  = makeGasBandTexture()
        mat.specular.contents = NSColor(white: 0.30, alpha: 1)
        mat.shininess = 28; sphere.firstMaterial = mat
        let body = SCNNode(geometry: sphere)
        body.runAction(.repeatForever(.rotateBy(x: 0, y: 1, z: 0, duration: 18)))
        planet.addChildNode(body)

        // Storm spot overlay (small emissive ellipse on planet surface)
        let storm = SCNSphere(radius: 3.22)
        let smat  = SCNMaterial()
        smat.diffuse.contents  = makeStormTexture()
        smat.blendMode = .add; smat.isDoubleSided = false
        storm.firstMaterial = smat
        let stormNode = SCNNode(geometry: storm)
        stormNode.runAction(.repeatForever(.rotateBy(x: 0, y: 1, z: 0, duration: 22)))
        planet.addChildNode(stormNode)

        // Atmosphere haze
        let atmo = SCNSphere(radius: 3.65)
        let amat = SCNMaterial()
        amat.diffuse.contents  = NSColor(red: 0.85, green: 0.50, blue: 0.15, alpha: 0.08)
        amat.emission.contents = NSColor(red: 0.65, green: 0.35, blue: 0.08, alpha: 0.12)
        amat.blendMode = .add; amat.isDoubleSided = true; atmo.firstMaterial = amat
        planet.addChildNode(SCNNode(geometry: atmo))

        // Ring system: outer broad ring, gap, inner bright ring
        addRings(to: planet)

        // Two moons at different radii
        addMoon(to: planet, radius: 0.48, distance: 7.2, orbitDuration: 9,  tilt: 0.08)
        addMoon(to: planet, radius: 0.28, distance: 10.5, orbitDuration: 16, tilt: -0.14)

        parent.addChildNode(planet)
    }

    private static func addRings(to planet: SCNNode) {
        // Outer broad ring
        let r1 = SCNTube(innerRadius: 4.4, outerRadius: 8.2, height: 0.08)
        let m1 = SCNMaterial()
        m1.diffuse.contents  = NSColor(red: 0.70, green: 0.52, blue: 0.28, alpha: 0.50)
        m1.isDoubleSided = true; r1.firstMaterial = m1
        let rn1 = SCNNode(geometry: r1)
        rn1.eulerAngles.x = CGFloat(Float.pi / 2 - 0.36)
        rn1.runAction(.repeatForever(.rotateBy(x: 0, y: 0.08, z: 0, duration: 60)))
        planet.addChildNode(rn1)

        // Inner bright band
        let r2 = SCNTube(innerRadius: 5.0, outerRadius: 6.0, height: 0.06)
        let m2 = SCNMaterial()
        m2.diffuse.contents  = NSColor(red: 0.92, green: 0.78, blue: 0.52, alpha: 0.85)
        m2.emission.contents = NSColor(red: 0.40, green: 0.28, blue: 0.10, alpha: 0.20)
        m2.blendMode = .add; m2.isDoubleSided = true; r2.firstMaterial = m2
        let rn2 = SCNNode(geometry: r2)
        rn2.eulerAngles.x = CGFloat(Float.pi / 2 - 0.36)
        rn2.runAction(.repeatForever(.rotateBy(x: 0, y: -0.12, z: 0, duration: 45)))
        planet.addChildNode(rn2)

        // Faint outer wisp
        let r3 = SCNTube(innerRadius: 8.5, outerRadius: 11.0, height: 0.05)
        let m3 = SCNMaterial()
        m3.diffuse.contents = NSColor(red: 0.55, green: 0.42, blue: 0.22, alpha: 0.20)
        m3.blendMode = .add; m3.isDoubleSided = true; r3.firstMaterial = m3
        let rn3 = SCNNode(geometry: r3)
        rn3.eulerAngles.x = CGFloat(Float.pi / 2 - 0.36)
        planet.addChildNode(rn3)
    }

    private static func addMoon(to planet: SCNNode, radius: CGFloat, distance: Float,
                                 orbitDuration: Double, tilt: Float) {
        let moon = SCNSphere(radius: radius)
        let mat  = SCNMaterial()
        mat.diffuse.contents  = NSColor(white: 0.42, alpha: 1)
        mat.specular.contents = NSColor(white: 0.15, alpha: 1); mat.shininess = 12
        moon.firstMaterial = mat
        let orbit = SCNNode()
        let node  = SCNNode(geometry: moon)
        node.position = SCNVector3(distance, 0, 0)
        orbit.addChildNode(node)
        orbit.eulerAngles.z = CGFloat(tilt)
        orbit.runAction(.repeatForever(.rotateBy(x: 0, y: 1, z: 0, duration: orbitDuration)))
        planet.addChildNode(orbit)
    }

    private static func makeGasBandTexture() -> NSImage {
        let size = CGSize(width: 512, height: 512)
        let img  = NSImage(size: size)
        img.lockFocus()
        let bands: [(CGFloat, NSColor)] = [
            (0.00, NSColor(red: 0.90, green: 0.65, blue: 0.32, alpha: 1)),
            (0.08, NSColor(red: 0.68, green: 0.42, blue: 0.16, alpha: 1)),
            (0.16, NSColor(red: 0.96, green: 0.74, blue: 0.44, alpha: 1)),
            (0.26, NSColor(red: 0.72, green: 0.48, blue: 0.20, alpha: 1)),
            (0.36, NSColor(red: 0.58, green: 0.34, blue: 0.10, alpha: 1)),
            (0.47, NSColor(red: 0.88, green: 0.60, blue: 0.30, alpha: 1)),
            (0.58, NSColor(red: 0.76, green: 0.50, blue: 0.20, alpha: 1)),
            (0.68, NSColor(red: 0.94, green: 0.70, blue: 0.40, alpha: 1)),
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

    private static func makeStormTexture() -> NSImage {
        let size = CGSize(width: 512, height: 512)
        let img  = NSImage(size: size)
        img.lockFocus()
        NSColor.black.setFill(); NSRect(origin: .zero, size: size).fill()
        // Storm spot: oval in lower-right quadrant
        let stormCol = NSColor(red: 0.85, green: 0.38, blue: 0.15, alpha: 1)
        NSGradient(starting: stormCol, ending: .black)!.draw(
            in: NSRect(x: size.width * 0.58, y: size.height * 0.22,
                       width: size.width * 0.28, height: size.height * 0.14),
            relativeCenterPosition: NSPoint(x: 0, y: 0))
        img.unlockFocus()
        return img
    }

    // MARK: - Asteroid belt (50 rocks in a loose band)

    private static func addAsteroidBelt(to parent: SCNNode) {
        for _ in 0..<50 {
            let sz  = CGFloat(Float.random(in: 0.08...0.60))
            let geo: SCNGeometry = Bool.random()
                ? SCNSphere(radius: sz)
                : SCNBox(width: sz * 1.5, height: sz, length: sz * 0.8, chamferRadius: sz * 0.10)
            let mat = SCNMaterial()
            mat.diffuse.contents  = NSColor(
                red: CGFloat.random(in: 0.18...0.42),
                green: CGFloat.random(in: 0.15...0.34),
                blue: CGFloat.random(in: 0.08...0.22), alpha: 1)
            mat.specular.contents = NSColor(white: 0.15, alpha: 1)
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float.random(in: -35...35),
                Float.random(in: -12...12),
                Float.random(in: -25 ... -14)
            )
            node.runAction(.repeatForever(.rotateBy(
                x: CGFloat(Float.random(in: 0.3...2.5)),
                y: CGFloat(Float.random(in: 0.3...2.5)),
                z: CGFloat(Float.random(in: 0...1.0)),
                duration: Double.random(in: 2...14)
            )))
            parent.addChildNode(node)
        }
    }

    // MARK: - Comet with particle tail

    private static func addComet(to parent: SCNNode) {
        // Nucleus
        let nucleus = SCNSphere(radius: 0.25)
        let nmat    = SCNMaterial()
        nmat.diffuse.contents  = NSColor(white: 0.82, alpha: 1)
        nmat.emission.contents = NSColor(white: 0.60, alpha: 1)
        nucleus.firstMaterial  = nmat
        let comet = SCNNode(geometry: nucleus)
        comet.opacity = 0

        // Ion tail (particle system)
        let ps = SCNParticleSystem()
        ps.birthRate = 80; ps.particleLifeSpan = 1.8; ps.particleLifeSpanVariation = 0.8
        ps.particleVelocity = 3; ps.particleVelocityVariation = 1.5
        ps.particleSize  = 0.08
        ps.particleColor = NSColor(red: 0.55, green: 0.85, blue: 1.00, alpha: 0.80)
        ps.blendMode     = .additive
        ps.emitterShape  = SCNSphere(radius: 0.2)
        comet.addParticleSystem(ps)
        parent.addChildNode(comet)

        // Fly from upper-left to lower-right, repeat every 35 seconds
        let startPos = SCNVector3(-60, 25, -55)
        let endPos   = SCNVector3(60, -15, -55)
        comet.position = startPos

        let flyAction = SCNAction.sequence([
            .fadeIn(duration: 0.3),
            .move(to: SCNVector3(endPos.x, endPos.y, endPos.z), duration: 8),
            .fadeOut(duration: 0.3),
            .wait(duration: 27),
            .run { n in n.position = startPos },
        ])
        comet.runAction(.repeatForever(flyAction))
    }

    // MARK: - Meteor shower (repeating, not one-shot)

    private static func addMeteorShower(to parent: SCNNode) {
        for i in 0..<14 {
            let len   = CGFloat(Float.random(in: 1.8...5.5))
            let trail = SCNBox(width: len, height: 0.04, length: 0.04, chamferRadius: 0)
            let mat   = SCNMaterial()
            mat.diffuse.contents = NSColor.white; mat.emission.contents = NSColor.white
            mat.blendMode = .add; trail.firstMaterial = mat
            let node = SCNNode(geometry: trail)

            let sx = Float.random(in: -50 ... -8)
            let sy = Float.random(in: -10...18)
            let sz = Float.random(in: -70 ... -28)
            let ex = sx + 60 + Float.random(in: 0...20)
            let ey = sy - Float.random(in: 5...14)

            node.position    = SCNVector3(sx, sy, sz)
            node.eulerAngles.z = CGFloat(Float.random(in: -0.25...0.25))
            node.opacity     = 0

            let baseDelay = Double(i) * Double.random(in: 2.5...8.0)
            let cycle     = Double.random(in: 18...45)
            let flyDur    = Double.random(in: 0.6...1.5)

            let action = SCNAction.repeatForever(.sequence([
                .wait(duration: baseDelay.truncatingRemainder(dividingBy: cycle)),
                .group([
                    .fadeIn(duration: 0.04),
                    .move(to: SCNVector3(ex, ey, sz), duration: flyDur),
                ]),
                .fadeOut(duration: 0.06),
                .run { n in n.position = SCNVector3(sx, sy, sz) },
                .wait(duration: cycle - flyDur - 0.10),
            ]))
            node.runAction(action)
            parent.addChildNode(node)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build`
Expected: `Build complete!` with no errors or warnings.

- [ ] **Step 3: Run all tests**

Run: `swift test`
Expected: `Executed 28 tests, with 0 failures`

- [ ] **Step 4: Commit**

```bash
git add src/portals/CosmosPortal.swift
git commit -m "feat: overhaul CosmosPortal with galaxy disc, volumetric nebulae, storm planet, comet, repeating meteors"
```

---

## Task 2: MidnightCityPortal — Cyberpunk Canyon Overhaul

**Files:**
- Modify: `src/portals/MidnightCityPortal.swift` (full rewrite)

### What makes it better

Current problems: buildings are thin and sparse (only 7 Z depths), no movement at all, rain feels weak, no sense of city scale above or below camera.

New design:
- **Deep building canyon**: 10 Z bands from z=-1 to -60. Near buildings are large/tall; distant buildings blur into fog creating genuine perspective.
- **Holographic billboards**: 5–6 large vertical planes with animated emission (SCNAction sequence cycling between colours)
- **Moving vehicles**: 8 pre-spawned vehicles that cross L→R and R→L at different heights and speeds, then loop
- **Steam vents**: 4 `SCNParticleSystem` emitters from floor grates
- **Aerial drones**: 6 small blinking-light nodes flying at y=8–16
- **Distant skyline**: thin dark silhouette towers at z=-65 to -80 (so fog softens them to shapes)
- **Rain splash particles**: second particle system at road level for drip/splash effect
- **Neon sign geometry**: coloured emissive boxes as signs on building faces, in groups of 2–3

- [ ] **Step 1: Replace `MidnightCityPortal.swift` with the new implementation**

```swift
import AppKit
import SceneKit

/// Street-level view of a rainy cyberpunk city.
/// Camera at origin. Road at y = roadY. Fog turns everything beyond 50 units into purple murk.
public enum MidnightCityPortal {
    private static let roadY: Float = -8

    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.black
        scene.fogColor           = NSColor(red: 0.04, green: 0.00, blue: 0.09, alpha: 1)
        scene.fogStartDistance   = 14
        scene.fogEndDistance     = 62
        scene.fogDensityExponent = 1.0

        addLighting(to: scene.rootNode)
        addSky(to: scene.rootNode)
        addRoad(to: scene.rootNode)
        addSidewalks(to: scene.rootNode)
        addBuildings(to: scene.rootNode)
        addDistantSkyline(to: scene.rootNode)
        addNeonSigns(to: scene.rootNode)
        addBillboards(to: scene.rootNode)
        addStreetLights(to: scene.rootNode)
        addVehicles(to: scene.rootNode)
        addAerialDrones(to: scene.rootNode)
        addSteamVents(to: scene.rootNode)
        addRain(to: scene.rootNode)
        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        // Deep violet ambient
        let amb = SCNNode()
        amb.light = {
            let l = SCNLight(); l.type = .ambient
            l.intensity = 55; l.color = NSColor(red: 0.04, green: 0.00, blue: 0.10, alpha: 1)
            return l
        }()
        parent.addChildNode(amb)

        // Cyan key from above (city glow bounce)
        let key = SCNNode()
        key.light = {
            let l = SCNLight(); l.type = .directional
            l.intensity = 140; l.color = NSColor(red: 0.00, green: 0.80, blue: 1.00, alpha: 1)
            return l
        }()
        key.eulerAngles = SCNVector3(-0.9, 0, 0)
        parent.addChildNode(key)

        // Hot-pink neon fill from the left
        let fill = SCNNode()
        fill.light = {
            let l = SCNLight(); l.type = .directional
            l.intensity = 90; l.color = NSColor(red: 1.00, green: 0.05, blue: 0.55, alpha: 1)
            return l
        }()
        fill.eulerAngles = SCNVector3(-0.3, 1.2, 0)
        parent.addChildNode(fill)
    }

    // MARK: - Sky

    private static func addSky(to parent: SCNNode) {
        let plane = SCNPlane(width: 150, height: 80)
        let img   = NSImage(size: CGSize(width: 2, height: 256))
        img.lockFocus()
        NSGradient(colors: [
            NSColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1),
            NSColor(red: 0.04, green: 0.01, blue: 0.10, alpha: 1),
            NSColor(red: 0.08, green: 0.02, blue: 0.18, alpha: 1),
        ])!.draw(in: NSRect(origin: .zero, size: CGSize(width: 2, height: 256)), angle: 90)
        img.unlockFocus()
        let mat = SCNMaterial()
        mat.diffuse.contents = img; plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, 22, -60)
        parent.addChildNode(node)
    }

    // MARK: - Road

    private static func addRoad(to parent: SCNNode) {
        let road = SCNPlane(width: 16, height: 140)
        let mat  = SCNMaterial()
        mat.diffuse.contents  = makeAsphaltTexture()
        mat.specular.contents = NSColor(white: 0.45, alpha: 1)
        mat.shininess = 110; road.firstMaterial = mat
        let node = SCNNode(geometry: road)
        node.eulerAngles.x = CGFloat(-Float.pi / 2)
        node.position = SCNVector3(0, roadY, -38)
        parent.addChildNode(node)

        // Neon puddle reflection strip
        let reflect = SCNPlane(width: 16, height: 140)
        let rmat    = SCNMaterial()
        rmat.diffuse.contents = makeReflectionTexture()
        rmat.blendMode = .add; rmat.isDoubleSided = true; reflect.firstMaterial = rmat
        let rNode = SCNNode(geometry: reflect)
        rNode.eulerAngles.x = CGFloat(-Float.pi / 2)
        rNode.position = SCNVector3(0, roadY + 0.05, -38)
        parent.addChildNode(rNode)
    }

    private static func makeAsphaltTexture() -> NSImage {
        let size = CGSize(width: 256, height: 256)
        let img  = NSImage(size: size)
        img.lockFocus()
        NSColor(red: 0.044, green: 0.044, blue: 0.047, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        NSColor(red: 0.26, green: 0.24, blue: 0.12, alpha: 0.65).setFill()
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
        NSGradient(colors: [
            NSColor(red: 0.6, green: 0.0, blue: 0.3, alpha: 0.22),
            NSColor(red: 0.0, green: 0.3, blue: 0.6, alpha: 0.12),
            NSColor(red: 0.4, green: 0.0, blue: 0.6, alpha: 0.18),
        ])!.draw(in: NSRect(origin: .zero, size: size), angle: 90)
        img.unlockFocus()
        return img
    }

    // MARK: - Sidewalks

    private static func addSidewalks(to parent: SCNNode) {
        for sign: Float in [-1, 1] {
            let walk = SCNPlane(width: 10, height: 140)
            let mat  = SCNMaterial()
            mat.diffuse.contents  = NSColor(white: 0.062, alpha: 1)
            mat.specular.contents = NSColor(white: 0.22, alpha: 1)
            mat.shininess = 32; walk.firstMaterial = mat
            let node = SCNNode(geometry: walk)
            node.eulerAngles.x = CGFloat(-Float.pi / 2)
            node.position = SCNVector3(sign * 13, roadY + 0.18, -38)
            parent.addChildNode(node)
        }
    }

    // MARK: - Buildings (10 depth layers)

    private static func addBuildings(to parent: SCNNode) {
        let neonPalette: [NSColor] = [
            NSColor(red: 1.0, green: 0.08, blue: 0.50, alpha: 1),
            NSColor(red: 0.0, green: 0.90, blue: 1.00, alpha: 1),
            NSColor(red: 0.6, green: 0.00, blue: 1.00, alpha: 1),
            NSColor(red: 1.0, green: 0.60, blue: 0.00, alpha: 1),
            NSColor(red: 0.0, green: 1.00, blue: 0.50, alpha: 1),
        ]
        let zBands: [Float] = [-1, -5, -10, -16, -22, -30, -38, -46, -54, -62]

        for (idx, z) in zBands.enumerated() {
            for side: Float in [-1, 1] {
                let height = Float.random(in: 14...38)
                let width  = Float.random(in: 5...11)
                let depth  = Float.random(in: 4...9)
                let accent = neonPalette[idx % neonPalette.count]

                let box = SCNBox(width: CGFloat(width), height: CGFloat(height),
                                 length: CGFloat(depth), chamferRadius: 0.04)
                let mat = SCNMaterial()
                mat.diffuse.contents  = NSColor(white: CGFloat.random(in: 0.030...0.055), alpha: 1)
                mat.emission.contents = accent.withAlphaComponent(0.04)
                box.firstMaterial = mat

                let node  = SCNNode(geometry: box)
                let xBase = side * (8 + width / 2 + Float.random(in: 0...3))
                node.position = SCNVector3(xBase, roadY + height / 2, z)

                addNeonTrim(to: node, width: CGFloat(width), depth: CGFloat(depth),
                            height: CGFloat(height), colour: accent)
                addWindowLights(to: node, width: CGFloat(width), height: CGFloat(height))
                parent.addChildNode(node)
            }
        }
    }

    private static func addNeonTrim(to building: SCNNode, width: CGFloat, depth: CGFloat,
                                    height: CGFloat, colour: NSColor) {
        let trim = SCNBox(width: width + 0.18, height: 0.14, length: depth + 0.18, chamferRadius: 0)
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
                guard Float.random(in: 0...1) < 0.28 else { continue }
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

    // MARK: - Distant skyline (silhouette at z=-65 to -80, fully in fog)

    private static func addDistantSkyline(to parent: SCNNode) {
        for i in -8...8 {
            let h      = Float.random(in: 22...55)
            let w      = Float.random(in: 3...7)
            let box    = SCNBox(width: CGFloat(w), height: CGFloat(h), length: 2, chamferRadius: 0)
            let mat    = SCNMaterial()
            mat.diffuse.contents = NSColor(white: 0.025, alpha: 1)
            box.firstMaterial = mat
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(Float(i) * 9 + Float.random(in: -3...3),
                                       roadY + h / 2, Float.random(in: -65 ... -75))
            parent.addChildNode(node)
        }
    }

    // MARK: - Neon signs on building faces

    private static func addNeonSigns(to parent: SCNNode) {
        let signs: [(Float, Float, Float, NSColor, CGFloat, CGFloat)] = [
            // (x, y, z, colour, w, h)
            (-10, -1,  -4, NSColor(red: 1.0, green: 0.08, blue: 0.50, alpha: 1), 3.5, 0.9),
            ( 12, -3,  -8, NSColor(red: 0.0, green: 0.90, blue: 1.00, alpha: 1), 4.0, 0.7),
            (-13,  2, -14, NSColor(red: 0.6, green: 0.00, blue: 1.00, alpha: 1), 5.0, 1.1),
            ( 11, -5, -20, NSColor(red: 1.0, green: 0.60, blue: 0.00, alpha: 1), 3.0, 0.8),
            (-12,  5, -28, NSColor(red: 0.0, green: 1.00, blue: 0.50, alpha: 1), 6.0, 1.2),
        ]
        for (x, y, z, col, w, h) in signs {
            let box  = SCNBox(width: w, height: h, length: 0.12, chamferRadius: 0.04)
            let mat  = SCNMaterial()
            mat.diffuse.contents = col; mat.emission.contents = col; mat.blendMode = .add
            box.firstMaterial = mat
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(x, y, z)
            // Gentle flicker
            node.runAction(.repeatForever(.sequence([
                .wait(duration: Double.random(in: 3...9)),
                .fadeOpacity(to: 0.2, duration: 0.05),
                .fadeOpacity(to: 1.0, duration: 0.05),
                .fadeOpacity(to: 0.2, duration: 0.05),
                .fadeOpacity(to: 1.0, duration: 0.08),
            ])))
            parent.addChildNode(node)
        }
    }

    // MARK: - Holographic billboards

    private static func addBillboards(to parent: SCNNode) {
        let configs: [(Float, Float, Float, NSColor)] = [
            // (x, y, z, dominant colour)
            ( 13,  4, -12, NSColor(red: 0.0, green: 0.90, blue: 1.00, alpha: 1)),
            (-14,  6, -22, NSColor(red: 1.0, green: 0.08, blue: 0.50, alpha: 1)),
            ( 14,  8, -35, NSColor(red: 0.6, green: 0.00, blue: 1.00, alpha: 1)),
        ]
        for (x, y, z, col) in configs {
            let billboard = SCNPlane(width: 7, height: 4)
            let mat       = SCNMaterial()
            mat.diffuse.contents  = col.withAlphaComponent(0.12)
            mat.emission.contents = col.withAlphaComponent(0.55)
            mat.blendMode = .add; mat.isDoubleSided = true; billboard.firstMaterial = mat
            let node = SCNNode(geometry: billboard)
            node.position = SCNVector3(x, y, z)
            // Animate: pulse through 3 colours
            let alt = NSColor(red: 1 - col.redComponent * 0.8,
                              green: 1 - col.greenComponent * 0.8,
                              blue: col.blueComponent, alpha: 1)
            node.runAction(.repeatForever(.sequence([
                .customAction(duration: 3) { n, _ in
                    (n.geometry?.firstMaterial)?.emission.contents = col.withAlphaComponent(0.55)
                },
                .customAction(duration: 3) { n, _ in
                    (n.geometry?.firstMaterial)?.emission.contents = alt.withAlphaComponent(0.45)
                },
            ])))
            parent.addChildNode(node)
        }
    }

    // MARK: - Street lights

    private static func addStreetLights(to parent: SCNNode) {
        let zDepths: [Float] = [-2, -10, -20, -30, -42]
        let lightCol = NSColor(red: 1.0, green: 0.92, blue: 0.70, alpha: 1)
        for z in zDepths {
            for side: Float in [-1, 1] {
                let pole = SCNCylinder(radius: 0.14, height: 12)
                let pmat = SCNMaterial()
                pmat.diffuse.contents = NSColor(white: 0.11, alpha: 1); pole.firstMaterial = pmat
                let pNode = SCNNode(geometry: pole)
                pNode.position = SCNVector3(side * 8.5, roadY + 6, z)
                parent.addChildNode(pNode)

                let lamp = SCNSphere(radius: 0.48)
                let lmat = SCNMaterial()
                lmat.diffuse.contents = lightCol; lmat.emission.contents = lightCol
                lmat.blendMode = .add; lamp.firstMaterial = lmat
                let lNode = SCNNode(geometry: lamp)
                lNode.position = SCNVector3(side * 8.5, roadY + 12.5, z)
                parent.addChildNode(lNode)
            }
        }
    }

    // MARK: - Moving vehicles (street level)

    private static func addVehicles(to parent: SCNNode) {
        // (startX, y, z, speed, fromLeft)
        let specs: [(Float, Float, Float, Double, Bool)] = [
            (-30, roadY + 0.8, -3,  6, true),
            ( 30, roadY + 0.8, -5,  8, false),
            (-30, roadY + 0.8, -10, 5, true),
            ( 30, roadY + 0.8, -14, 7, false),
            (-30, roadY + 1.6, -7,  9, true),
            ( 30, roadY + 0.8, -18, 6, false),
            (-30, roadY + 0.8, -22, 8, true),
            ( 30, roadY + 0.8, -26, 5, false),
        ]
        for (i, (sx, y, z, speed, fromLeft)) in specs.enumerated() {
            let endX: Float = fromLeft ? 30 : -30
            let body = SCNBox(width: 2.8, height: 0.85, length: 1.5, chamferRadius: 0.18)
            let mat  = SCNMaterial()
            mat.diffuse.contents = NSColor(white: CGFloat.random(in: 0.06...0.16), alpha: 1)
            body.firstMaterial = mat

            let vehicle = SCNNode(geometry: body)
            vehicle.position = SCNVector3(sx, y, z)
            if !fromLeft { vehicle.eulerAngles.y = CGFloat(Float.pi) }
            vehicle.opacity = 0

            // Headlights
            for hx: Float in [-1.2, 1.2] {
                let lens = SCNSphere(radius: 0.15)
                let lmat = SCNMaterial()
                lmat.diffuse.contents = NSColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1)
                lmat.emission.contents = NSColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1)
                lmat.blendMode = .add; lens.firstMaterial = lmat
                let lNode = SCNNode(geometry: lens)
                lNode.position = SCNVector3(hx, 0, fromLeft ? 0.78 : -0.78)
                vehicle.addChildNode(lNode)
            }
            parent.addChildNode(vehicle)

            let delay = Double(i) * Double.random(in: 1.0...4.0)
            let travelTime = Double(abs(endX - sx)) / speed
            vehicle.runAction(.sequence([
                .wait(duration: delay),
                .repeatForever(.sequence([
                    .run { n in n.position = SCNVector3(sx, y, z); n.opacity = 0 },
                    .fadeIn(duration: 0.3),
                    .move(to: SCNVector3(CGFloat(endX), CGFloat(y), CGFloat(z)),
                          duration: travelTime),
                    .fadeOut(duration: 0.3),
                ])),
            ]))
        }
    }

    // MARK: - Aerial drones

    private static func addAerialDrones(to parent: SCNNode) {
        for i in 0..<6 {
            let drone = SCNBox(width: 0.6, height: 0.18, length: 0.6, chamferRadius: 0.06)
            let dmat  = SCNMaterial()
            dmat.diffuse.contents = NSColor(white: 0.10, alpha: 1); drone.firstMaterial = dmat
            let node = SCNNode(geometry: drone)
            let sx: Float = i % 2 == 0 ? -40 : 40
            let y  = Float.random(in: 4...16)
            let z  = Float.random(in: -8 ... -35)
            node.position = SCNVector3(sx, y, z)
            node.opacity  = 0

            // Blinking light
            let blink = SCNSphere(radius: 0.10)
            let bmat  = SCNMaterial()
            let blinkCol = [NSColor.red, NSColor.cyan, NSColor.white].randomElement()!
            bmat.emission.contents = blinkCol; bmat.blendMode = .add; blink.firstMaterial = bmat
            let blinkNode = SCNNode(geometry: blink)
            blinkNode.runAction(.repeatForever(.sequence([
                .fadeOpacity(to: 0.0, duration: 0.5),
                .fadeOpacity(to: 1.0, duration: 0.5),
            ])))
            node.addChildNode(blinkNode)

            let ex: Float = i % 2 == 0 ? 40 : -40
            let dur = Double.random(in: 12...22)
            let delay = Double(i) * Double.random(in: 2...5)
            node.runAction(.sequence([
                .wait(duration: delay),
                .repeatForever(.sequence([
                    .run { n in n.position = SCNVector3(sx, y, z); n.opacity = 0 },
                    .fadeIn(duration: 0.5),
                    .move(to: SCNVector3(CGFloat(ex), CGFloat(y), CGFloat(z)), duration: dur),
                    .fadeOut(duration: 0.5),
                ])),
            ]))
            parent.addChildNode(node)
        }
    }

    // MARK: - Steam vents

    private static func addSteamVents(to parent: SCNNode) {
        let positions: [(Float, Float)] = [(-5, -6), (4, -11), (-8, -20), (6, -16)]
        for (x, z) in positions {
            let ps = SCNParticleSystem()
            ps.birthRate = 25; ps.particleLifeSpan = 2.5; ps.particleLifeSpanVariation = 1.0
            ps.particleVelocity = 2.0; ps.particleVelocityVariation = 0.8
            ps.particleSize  = 0.40
            ps.particleColor = NSColor(red: 0.75, green: 0.82, blue: 1.00, alpha: 0.28)
            ps.blendMode     = .additive
            ps.emitterShape  = SCNPlane(width: 0.5, height: 0)
            let emitter = SCNNode()
            emitter.position    = SCNVector3(x, roadY + 0.2, z)
            emitter.eulerAngles = SCNVector3(-Float.pi / 2, 0, Float.random(in: -0.3...0.3))
            emitter.addParticleSystem(ps)
            parent.addChildNode(emitter)
        }
    }

    // MARK: - Rain

    private static func addRain(to parent: SCNNode) {
        let ps = SCNParticleSystem()
        ps.birthRate = 2200; ps.particleLifeSpan = 0.45
        ps.particleVelocity = 48; ps.particleVelocityVariation = 10
        ps.emitterShape = SCNPlane(width: 70, height: 0)
        ps.particleSize = 0.028
        ps.particleColor = NSColor(red: 0.70, green: 0.82, blue: 1.00, alpha: 0.50)
        ps.blendMode = .additive
        let emitter = SCNNode()
        emitter.position    = SCNVector3(0, 20, -28)
        emitter.eulerAngles = SCNVector3(-Float.pi / 2 + 0.20, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Tests**

Run: `swift test`
Expected: `Executed 28 tests, with 0 failures`

- [ ] **Step 4: Commit**

```bash
git add src/portals/MidnightCityPortal.swift
git commit -m "feat: overhaul MidnightCityPortal with 10-layer buildings, vehicles, drones, steam, billboards, distant skyline"
```

---

## Task 3: AbyssPortal — Deep Ocean Overhaul

**Files:**
- Modify: `src/portals/AbyssPortal.swift` (full rewrite)

### What makes it better

Current problems: floor feels flat (no caustics), coral is just plain cones, fish are box-shaped, jellyfish are okay but need more bioluminescence, no sense of the depth below you — just black.

New design:
- **Caustic light patches**: 8–10 small emissive planes on the floor at different positions that slowly drift sideways, simulating light refracted through surface waves
- **Kelp forest**: clusters of segmented vertical cylinders swaying with staggered SCNAction sequences
- **Whale silhouette**: elongated flattened SCNBox at z=-28, y=5 slowly moving across the scene
- **Thermal vent**: upward particle plume from floor (dark/red particles)
- **Branching coral**: groups of 2–3 cones at shared base positions creating branching effect
- **Bioluminescent jellyfish**: improved with a large faint additive sphere for a glow halo behind each one
- **Deeper fog**: increase fog density to reinforce crushing depth feel
- **Abyss glow**: large faint emissive plane at z=-30 below camera level for "lit from somewhere below" feel

- [ ] **Step 1: Replace `AbyssPortal.swift` with the new implementation**

```swift
import AppKit
import SceneKit

/// Deep ocean floor. Camera at origin. Floor at y = floorY.
/// Fog is heavy — anything beyond 30 units becomes murk.
public enum AbyssPortal {
    private static let floorY: Float = -10

    public static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0.00, green: 0.01, blue: 0.03, alpha: 1)
        scene.fogColor           = NSColor(red: 0.00, green: 0.02, blue: 0.06, alpha: 1)
        scene.fogStartDistance   = 5
        scene.fogEndDistance     = 28
        scene.fogDensityExponent = 1.2

        addLighting(to: scene.rootNode)
        addAbyssGlow(to: scene.rootNode)
        addOceanFloor(to: scene.rootNode)
        addCaustics(to: scene.rootNode)
        addLightRays(to: scene.rootNode)
        addThermalVent(to: scene.rootNode)
        addKelp(to: scene.rootNode)
        addCoral(to: scene.rootNode)
        addBioluminescence(to: scene.rootNode)
        addJellyfish(to: scene.rootNode)
        addFish(to: scene.rootNode)
        addWhale(to: scene.rootNode)
        addBubbles(to: scene.rootNode)
        return scene
    }

    // MARK: - Lighting

    private static func addLighting(to parent: SCNNode) {
        let amb = SCNNode()
        amb.light = {
            let l = SCNLight(); l.type = .ambient
            l.intensity = 100; l.color = NSColor(red: 0.00, green: 0.12, blue: 0.24, alpha: 1)
            return l
        }()
        parent.addChildNode(amb)

        let sunlight = SCNNode()
        sunlight.light = {
            let l = SCNLight(); l.type = .directional
            l.intensity = 220; l.color = NSColor(red: 0.00, green: 0.42, blue: 0.72, alpha: 1)
            return l
        }()
        sunlight.eulerAngles = SCNVector3(-0.28, 0, 0)
        parent.addChildNode(sunlight)

        // Warm bioluminescent fill from below
        let bio = SCNNode()
        bio.light = {
            let l = SCNLight(); l.type = .directional
            l.intensity = 80; l.color = NSColor(red: 0.00, green: 0.72, blue: 0.55, alpha: 1)
            return l
        }()
        bio.eulerAngles = SCNVector3(0.8, 0, 0)
        parent.addChildNode(bio)
    }

    // MARK: - Abyss glow (deep background emissive haze)

    private static func addAbyssGlow(to parent: SCNNode) {
        let plane = SCNPlane(width: 120, height: 80)
        let img   = NSImage(size: CGSize(width: 256, height: 256))
        img.lockFocus()
        NSColor.black.setFill(); NSRect(origin: .zero, size: CGSize(width: 256, height: 256)).fill()
        NSGradient(starting: NSColor(red: 0.00, green: 0.18, blue: 0.35, alpha: 1), ending: .black)!
            .draw(in: NSRect(origin: .zero, size: CGSize(width: 256, height: 256)),
                  relativeCenterPosition: NSPoint(x: 0, y: 0))
        img.unlockFocus()
        let mat = SCNMaterial()
        mat.diffuse.contents = img; mat.blendMode = .add; mat.isDoubleSided = true
        plane.firstMaterial  = mat
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, -5, -32)
        parent.addChildNode(node)
    }

    // MARK: - Ocean floor

    private static func addOceanFloor(to parent: SCNNode) {
        let floor = SCNPlane(width: 90, height: 130)
        let mat   = SCNMaterial()
        mat.diffuse.contents  = makeSeabedTexture()
        mat.specular.contents = NSColor(white: 0.06, alpha: 1); mat.shininess = 8
        mat.diffuse.wrapS = .repeat; mat.diffuse.wrapT = .repeat
        mat.diffuse.contentsTransform = SCNMatrix4MakeScale(10, 18, 1)
        floor.firstMaterial = mat
        let node = SCNNode(geometry: floor)
        node.eulerAngles.x = CGFloat(-Float.pi / 2)
        node.position = SCNVector3(0, floorY, -42)
        parent.addChildNode(node)

        for sign: Float in [-1, 1] {
            let wall = SCNPlane(width: 130, height: 35)
            let wmat = SCNMaterial()
            wmat.diffuse.contents = NSColor(red: 0, green: 0.015, blue: 0.05, alpha: 1)
            wall.firstMaterial = wmat
            let wNode = SCNNode(geometry: wall)
            wNode.position = SCNVector3(sign * 45, 7, -42)
            wNode.eulerAngles.y = CGFloat(sign * Float.pi / 2)
            parent.addChildNode(wNode)
        }
    }

    private static func makeSeabedTexture() -> NSImage {
        let size = CGSize(width: 128, height: 128)
        let img  = NSImage(size: size)
        img.lockFocus()
        NSGradient(colors: [
            NSColor(red: 0.07, green: 0.06, blue: 0.05, alpha: 1),
            NSColor(red: 0.04, green: 0.04, blue: 0.03, alpha: 1),
        ])!.draw(in: NSRect(origin: .zero, size: size), angle: 0)
        NSColor(red: 0.09, green: 0.08, blue: 0.06, alpha: 0.55).setFill()
        for _ in 0..<90 {
            let r = CGFloat.random(in: 1.5...5.5)
            NSBezierPath(ovalIn: NSRect(
                x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height),
                width: r, height: r * 0.55)).fill()
        }
        img.unlockFocus()
        return img
    }

    // MARK: - Caustic light patches on floor

    private static func addCaustics(to parent: SCNNode) {
        for _ in 0..<12 {
            let w    = CGFloat(Float.random(in: 1.2...4.0))
            let h    = w * CGFloat(Float.random(in: 0.5...1.4))
            let pane = SCNPlane(width: w, height: h)
            let mat  = SCNMaterial()
            mat.diffuse.contents  = NSColor(red: 0.00, green: 0.55, blue: 0.80, alpha: 0.22)
            mat.emission.contents = NSColor(red: 0.00, green: 0.40, blue: 0.65, alpha: 0.30)
            mat.blendMode = .add; mat.isDoubleSided = true; pane.firstMaterial = mat
            let node = SCNNode(geometry: pane)
            node.eulerAngles.x = CGFloat(-Float.pi / 2)
            node.position = SCNVector3(
                Float.random(in: -14...14), floorY + 0.05, Float.random(in: -4 ... -22))
            node.eulerAngles.z = CGFloat(Float.random(in: 0...Float.pi))
            // Drift slowly
            node.runAction(.repeatForever(.sequence([
                .moveBy(x: CGFloat.random(in: -1.5...1.5), y: 0, z: CGFloat.random(in: -1...1),
                        duration: Double.random(in: 4...10)),
                .moveBy(x: CGFloat.random(in: -1.5...1.5), y: 0, z: CGFloat.random(in: -1...1),
                        duration: Double.random(in: 4...10)),
            ])))
            parent.addChildNode(node)
        }
    }

    // MARK: - Volumetric light rays

    private static func addLightRays(to parent: SCNNode) {
        for i in -5...5 {
            let w   = CGFloat(Float.random(in: 0.8...3.0))
            let ray = SCNPlane(width: w, height: 38)
            let mat = SCNMaterial()
            mat.diffuse.contents  = NSColor(red: 0.00, green: 0.32, blue: 0.52, alpha: 0.045)
            mat.emission.contents = NSColor(red: 0.00, green: 0.22, blue: 0.42, alpha: 0.065)
            mat.blendMode = .add; mat.isDoubleSided = true; ray.firstMaterial = mat
            let node = SCNNode(geometry: ray)
            node.position = SCNVector3(
                Float(i) * 3.2 + Float.random(in: -1.5...1.5), 4,
                Float.random(in: -6 ... -18))
            node.eulerAngles.z = CGFloat(Float.random(in: -0.18...0.18))
            node.runAction(.repeatForever(.sequence([
                .rotateTo(x: 0, y: 0, z: CGFloat(Float.random(in: -0.12...0.12)),
                          duration: Double.random(in: 5...10), usesShortestUnitArc: true),
                .rotateTo(x: 0, y: 0, z: CGFloat(Float.random(in: -0.12...0.12)),
                          duration: Double.random(in: 5...10), usesShortestUnitArc: true),
            ])))
            parent.addChildNode(node)
        }
    }

    // MARK: - Thermal vent

    private static func addThermalVent(to parent: SCNNode) {
        // Vent chimney
        let chimney = SCNCylinder(radius: 0.35, height: 1.8)
        let cmat    = SCNMaterial()
        cmat.diffuse.contents = NSColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1)
        chimney.firstMaterial = cmat
        let cNode = SCNNode(geometry: chimney)
        cNode.position = SCNVector3(-4, floorY + 0.9, -8)
        parent.addChildNode(cNode)

        // Hot plume particles
        let ps = SCNParticleSystem()
        ps.birthRate = 55; ps.particleLifeSpan = 3.0; ps.particleLifeSpanVariation = 1.5
        ps.particleVelocity = 1.8; ps.particleVelocityVariation = 0.8
        ps.particleSize  = 0.30
        ps.particleColor = NSColor(red: 0.20, green: 0.10, blue: 0.08, alpha: 0.60)
        ps.blendMode     = .additive
        ps.emitterShape  = SCNSphere(radius: 0.3)
        let emitter = SCNNode()
        emitter.position    = SCNVector3(-4, floorY + 1.9, -8)
        emitter.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }

    // MARK: - Kelp forest (segmented cylinders, left and right sides)

    private static func addKelp(to parent: SCNNode) {
        let positions: [(Float, Float)] = [
            (-14, -5), (-16, -9), (-12, -13), (-18, -17),
            ( 15, -6), ( 13, -11), ( 17, -15), ( 14, -8),
        ]
        for (x, z) in positions {
            let segmentCount = Int.random(in: 6...12)
            var prevNode: SCNNode? = nil
            for seg in 0..<segmentCount {
                let segH = Float.random(in: 0.8...1.4)
                let cyl  = SCNCylinder(radius: CGFloat(Float.random(in: 0.06...0.14)), height: CGFloat(segH))
                let mat  = SCNMaterial()
                mat.diffuse.contents = NSColor(
                    red: CGFloat.random(in: 0.05...0.20),
                    green: CGFloat.random(in: 0.30...0.55),
                    blue: CGFloat.random(in: 0.08...0.20), alpha: 1)
                cyl.firstMaterial = mat
                let node = SCNNode(geometry: cyl)
                if let prev = prevNode {
                    node.position = SCNVector3(
                        Float.random(in: -0.15...0.15), segH, Float.random(in: -0.1...0.1))
                    prev.addChildNode(node)
                } else {
                    node.position = SCNVector3(x, floorY + segH / 2, z)
                    parent.addChildNode(node)
                }
                prevNode = node

                // Sway animation (staggered phase per segment)
                let swayAng = CGFloat(Float.random(in: 0.06...0.18))
                let dur     = Double.random(in: 1.5...4.0)
                let delay   = Double(seg) * 0.15
                node.runAction(.sequence([
                    .wait(duration: delay),
                    .repeatForever(.sequence([
                        .rotateTo(x: 0, y: 0, z:  swayAng, duration: dur, usesShortestUnitArc: true),
                        .rotateTo(x: 0, y: 0, z: -swayAng, duration: dur, usesShortestUnitArc: true),
                    ])),
                ]))
            }
        }
    }

    // MARK: - Coral formations (branching: 2-3 cones per cluster)

    private static func addCoral(to parent: SCNNode) {
        let palette: [NSColor] = [
            NSColor(red: 0.95, green: 0.28, blue: 0.12, alpha: 1),
            NSColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1),
            NSColor(red: 0.78, green: 0.08, blue: 0.52, alpha: 1),
            NSColor(red: 0.55, green: 0.00, blue: 0.90, alpha: 1),
            NSColor(red: 0.00, green: 0.78, blue: 0.55, alpha: 1),
        ]
        let positions: [(Float, Float)] = [
            (-7, -4), (-3, -7), (2, -5), (5, -8), (9, -4),
            (-5, -12), (0, -10), (4, -13), (8, -11), (-9, -16),
            (-2, -18), (6, -16), (11, -9), (-11, -8),
        ]
        for (bx, bz) in positions {
            let col      = palette.randomElement()!
            let branches = Int.random(in: 1...3)
            for b in 0..<branches {
                let h    = Float.random(in: 1.2...5.5)
                let cone = SCNCone(
                    topRadius:    CGFloat(Float.random(in: 0...0.10)),
                    bottomRadius: CGFloat(Float.random(in: 0.10...0.55)),
                    height:       CGFloat(h)
                )
                let mat = SCNMaterial()
                mat.diffuse.contents  = col
                mat.emission.contents = col.withAlphaComponent(0.18)
                cone.firstMaterial = mat
                let node = SCNNode(geometry: cone)
                let bxOff = bx + Float(b) * Float.random(in: -0.8...0.8)
                let bzOff = bz + Float(b) * Float.random(in: -0.6...0.6)
                node.position = SCNVector3(bxOff, floorY + h / 2, bzOff)
                node.eulerAngles.z = CGFloat(Float.random(in: -0.35...0.35))
                parent.addChildNode(node)
            }
        }
    }

    // MARK: - Bioluminescent orbs

    private static func addBioluminescence(to parent: SCNNode) {
        let palette: [NSColor] = [
            NSColor(red: 0.00, green: 0.90, blue: 1.00, alpha: 1),
            NSColor(red: 0.00, green: 1.00, blue: 0.52, alpha: 1),
            NSColor(red: 0.12, green: 0.32, blue: 1.00, alpha: 1),
            NSColor(red: 0.55, green: 0.00, blue: 1.00, alpha: 1),
        ]
        for _ in 0..<40 {
            let r   = CGFloat(Float.random(in: 0.06...0.45))
            let orb = SCNSphere(radius: r)
            let col = palette.randomElement()!
            let mat = SCNMaterial()
            mat.diffuse.contents  = col.withAlphaComponent(0.18)
            mat.emission.contents = col; mat.blendMode = .add
            orb.firstMaterial = mat
            let node = SCNNode(geometry: orb)
            node.position = SCNVector3(
                Float.random(in: -20...20),
                Float(floorY) + Float.random(in: 1...14),
                Float.random(in: -4 ... -26)
            )
            // Pulse glow
            node.runAction(.repeatForever(.sequence([
                .fadeOpacity(to: 0.35, duration: Double.random(in: 1.0...2.5)),
                .fadeOpacity(to: 1.00, duration: Double.random(in: 1.0...2.5)),
            ])))
            let drift = SCNAction.repeatForever(.sequence([
                .moveBy(x: CGFloat.random(in: -1.2...1.2),
                        y: CGFloat.random(in: -0.6...0.6), z: 0,
                        duration: Double.random(in: 3...7)),
                .moveBy(x: CGFloat.random(in: -1.2...1.2),
                        y: CGFloat.random(in: -0.6...0.6), z: 0,
                        duration: Double.random(in: 3...7)),
            ]))
            node.runAction(drift)
            parent.addChildNode(node)
        }
    }

    // MARK: - Jellyfish (with glow halos)

    private static func addJellyfish(to parent: SCNNode) {
        let palette: [NSColor] = [
            NSColor(red: 0.00, green: 0.90, blue: 0.90, alpha: 0.50),
            NSColor(red: 0.72, green: 0.00, blue: 0.90, alpha: 0.50),
            NSColor(red: 0.00, green: 0.72, blue: 0.42, alpha: 0.50),
            NSColor(red: 0.10, green: 0.38, blue: 1.00, alpha: 0.50),
        ]
        let positions: [(Float, Float, Float)] = [
            (-7, -4, -5), (3, -2, -7), (-2, 1, -10),
            (8, -5, -8), (-5, 2, -14), (4, -3, -18),
            (0, 0, -4), (-9, 1, -11), (6, -1, -16),
        ]
        for (x, y, z) in positions {
            let col  = palette.randomElement()!
            let mat  = SCNMaterial()
            mat.diffuse.contents  = col
            mat.emission.contents = col.withAlphaComponent(0.70)
            mat.blendMode = .add; mat.isDoubleSided = true

            let bodyR = Float.random(in: 0.5...1.2)
            let body  = SCNSphere(radius: CGFloat(bodyR))
            body.firstMaterial = mat
            let jelly = SCNNode(geometry: body)
            jelly.position = SCNVector3(x, y, z)

            // Large faint halo sphere for bloom effect
            let halo = SCNSphere(radius: CGFloat(bodyR * 2.8))
            let hmat = SCNMaterial()
            hmat.diffuse.contents = col.withAlphaComponent(0.06)
            hmat.blendMode = .add; hmat.isDoubleSided = true; halo.firstMaterial = hmat
            jelly.addChildNode(SCNNode(geometry: halo))

            // Tentacles
            let tentCount = Int.random(in: 5...9)
            for t in 0..<tentCount {
                let angle = Float(t) * .pi * 2 / Float(tentCount)
                let tentH = Float.random(in: 2.0...4.0)
                let cyl   = SCNCylinder(radius: 0.028, height: CGFloat(tentH))
                cyl.firstMaterial = mat
                let tNode = SCNNode(geometry: cyl)
                let tentY = -(tentH / 2) - bodyR * 0.55
                tNode.position = SCNVector3(cos(angle) * 0.44, tentY, sin(angle) * 0.44)
                jelly.addChildNode(tNode)
            }

            jelly.runAction(.repeatForever(.sequence([
                .scale(to: 0.78, duration: Double.random(in: 0.5...1.0)),
                .scale(to: 1.00, duration: Double.random(in: 0.5...1.0)),
            ])))
            let bobDist = Float.random(in: 0.7...1.8)
            jelly.runAction(.repeatForever(.sequence([
                .moveBy(x: 0, y:  CGFloat(bobDist), z: 0, duration: Double.random(in: 2...5)),
                .moveBy(x: 0, y: -CGFloat(bobDist), z: 0, duration: Double.random(in: 2...5)),
            ])))
            parent.addChildNode(jelly)
        }
    }

    // MARK: - Fish

    private static func addFish(to parent: SCNNode) {
        let palette: [NSColor] = [
            NSColor(red: 0.00, green: 0.72, blue: 0.92, alpha: 0.92),
            NSColor(red: 0.18, green: 0.90, blue: 0.62, alpha: 0.92),
            NSColor(red: 0.08, green: 0.38, blue: 0.82, alpha: 0.92),
        ]
        let specs: [(Float, Float, Float)] = [
            (-28, -5, -4), (28, -7, -6), (-28, -3, -9),
            ( 28, -6, -12), (-28, -2, -15), (28, -8, -5),
            (-28, -4, -18), (28, -6, -8), (-28, -3, -22),
            ( 28, -5, -11), (-28, -7, -7), (28, -4, -16),
        ]
        for (i, (sx, y, z)) in specs.enumerated() {
            let col      = palette.randomElement()!
            let fromLeft = sx < 0
            let endX: Float = fromLeft ? 28 : -28

            let mat = SCNMaterial()
            mat.diffuse.contents  = col
            mat.emission.contents = col.withAlphaComponent(0.25)

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
            let dur   = Double.random(in: 8...18)
            fish.runAction(.sequence([
                .wait(duration: delay),
                .repeatForever(.sequence([
                    .run { n in n.position = SCNVector3(CGFloat(sx), CGFloat(y), CGFloat(z)); n.opacity = 0 },
                    .fadeIn(duration: 0.5),
                    .move(to: SCNVector3(CGFloat(endX), CGFloat(y), CGFloat(z)), duration: dur),
                    .fadeOut(duration: 0.5),
                ])),
            ]))
        }
    }

    // MARK: - Whale (large silhouette crossing in the deep background)

    private static func addWhale(to parent: SCNNode) {
        let body = SCNBox(width: 12, height: 3.5, length: 3.0, chamferRadius: 1.5)
        let mat  = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 1)
        body.firstMaterial = mat

        // Tail fin
        let tail = SCNBox(width: 0.6, height: 4.0, length: 0.8, chamferRadius: 0.2)
        tail.firstMaterial = mat
        let tNode = SCNNode(geometry: tail)
        tNode.position = SCNVector3(-6.5, 0, 0)
        tNode.eulerAngles.z = CGFloat(Float.pi / 6)

        let whale = SCNNode(geometry: body)
        whale.addChildNode(tNode)
        whale.position = SCNVector3(-50, 2, -24)
        whale.opacity  = 0
        parent.addChildNode(whale)

        // Slow crossing, then repeat
        whale.runAction(.repeatForever(.sequence([
            .fadeIn(duration: 3.0),
            .move(to: SCNVector3(50, 2, -24), duration: 55),
            .fadeOut(duration: 3.0),
            .run { n in n.position = SCNVector3(-50, 2, -24) },
            .wait(duration: 30),
        ])))

        // Gentle tail swish
        tNode.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: CGFloat(Float.pi / 6 - 0.3),
                      duration: 2.0, usesShortestUnitArc: true),
            .rotateTo(x: 0, y: 0, z: CGFloat(Float.pi / 6 + 0.3),
                      duration: 2.0, usesShortestUnitArc: true),
        ])))
    }

    // MARK: - Rising bubbles

    private static func addBubbles(to parent: SCNNode) {
        let ps = SCNParticleSystem()
        ps.birthRate = 45; ps.particleLifeSpan = 5.0; ps.particleLifeSpanVariation = 1.8
        ps.particleVelocity = 2.6; ps.particleVelocityVariation = 1.4
        ps.emitterShape = SCNPlane(width: 24, height: 0)
        ps.particleSize = 0.12
        ps.particleColor = NSColor(red: 0.60, green: 0.92, blue: 1.00, alpha: 0.48)
        ps.blendMode = .additive
        let emitter = SCNNode()
        emitter.position    = SCNVector3(0, floorY + 0.5, -12)
        emitter.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Tests**

Run: `swift test`
Expected: `Executed 28 tests, with 0 failures`

- [ ] **Step 4: Commit**

```bash
git add src/portals/AbyssPortal.swift
git commit -m "feat: overhaul AbyssPortal with caustics, kelp, whale, thermal vent, branching coral, jellyfish halos"
```

---

## Final verification

After all three tasks complete:

- [ ] Run `swift build && swift test` one final time — expect clean build, 28/28 pass
- [ ] Launch the app and cycle through all three portals, verifying:
  - **Cosmos**: galaxy disc visible far back, nebulae are glowing clouds (not rectangles), planet has visible rings and moons, comets appear periodically, meteors streak across
  - **Midnight City**: deep canyon of buildings, neon signs flicker, vehicles cruise the road, drones blink overhead, steam rises from grates, rain falls
  - **Abyss**: bright caustic patches drift on the floor, kelp sways, jellyfish pulse with glow halos, whale crosses slowly in the deep, thermal vent smokes
