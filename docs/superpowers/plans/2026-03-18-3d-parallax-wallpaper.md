# 3D Parallax Wallpaper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu-bar app that renders a multi-layer parallax scene as the desktop wallpaper and shifts the camera perspective in real-time based on webcam head-tracking, creating a "looking through a window" illusion.

**Core UX principles (from spec):**
1. **Head tracking** — webcam detects head position locally in real time; no frames are written to disk, logged, or transmitted anywhere.
2. **Camera movement** — the virtual camera shifts proportionally to match the exact direction and distance of head movement.
3. **Depth illusion** — multi-layer depth causes the brain to interpret perspective shifts as real 3D depth.

**Architecture:** A borderless `NSWindow` locked to the desktop layer renders a SceneKit scene composed of depth-sorted image planes. AVFoundation captures the webcam stream; frames are analyzed in-memory by Apple's Vision framework (`VNDetectFaceRectanglesRequest`) — never written to disk — to extract a normalized face-center coordinate. That coordinate (smoothed via exponential moving average) drives the SceneKit camera's X/Y offset proportionally: the camera travels the same direction and distance as the head, scaled by a sensitivity factor.

**Tech Stack:** Swift 5.9+, AppKit, AVFoundation, Vision, SceneKit, XCTest — targeting macOS 13 Ventura+. No third-party dependencies.

---

## File Structure

```
src/
  AppDelegate.swift          – NSApplication entry, menu-bar setup, lifecycle
  DesktopWindowController.swift – Creates/manages the desktop-level NSWindow + SCNView
  CameraManager.swift        – AVFoundation capture session, delegates raw frames
  HeadTracker.swift          – Vision face detection, emits normalized CGPoint
  HeadSmoother.swift         – Exponential moving-average filter on head position
  ParallaxScene.swift        – Builds the SCNScene (layers, camera rig, lighting)
  ParallaxController.swift   – Receives smoothed head position, drives camera
  WallpaperLayer.swift       – Value type describing one depth layer (image + depth)
  SettingsWindowController.swift – Preferences panel (sensitivity, monitor, FOV, depth intensity)
  AutoPauseManager.swift     – Observes NSWorkspace to pause tracking when desktop is hidden
  LoginItemManager.swift     – SMAppService wrapper for launch-at-login
  AppSettings.swift          – UserDefaults-backed settings model (single source of truth)

tests/
  HeadSmootherTests.swift    – Unit tests for EMA filter
  HeadTrackerTests.swift     – Unit tests for coordinate normalization
  ParallaxControllerTests.swift – Unit tests for camera offset math
  WallpaperLayerTests.swift  – Unit tests for layer depth sorting
  AutoPauseManagerTests.swift – Unit tests for pause/resume logic
  AppSettingsTests.swift      – Unit tests for settings persistence
```

---

## Task 1: Project Scaffold

**Files:**
- Create: `src/AppDelegate.swift`
- Create: `3DWallpaper.xcodeproj` (via Xcode CLI)

- [ ] **Step 1: Create Xcode project**

```bash
cd /Users/hamadgul/Projects/3DWallpaper
xcodebuild -create-xcodeproj 3DWallpaper || true
# Preferred: open Xcode → New Project → macOS → App
# Product name: 3DWallpaper, Language: Swift, Interface: AppKit, no storyboards
# Uncheck "Create Git repository"
```

- [ ] **Step 2: Configure Info.plist for menu-bar-only app**

In `Info.plist` (or target settings → Info tab), set:
```
Application is agent (UIElement) = YES   → hides Dock icon
NSCameraUsageDescription = "3DWallpaper needs your camera to track head position."
```

- [ ] **Step 3: Write minimal AppDelegate**

Replace generated `AppDelegate.swift` with:

```swift
import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var desktopWindowController: DesktopWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        desktopWindowController = DesktopWindowController()
        desktopWindowController?.showWindow(nil)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "camera.aperture",
                                            accessibilityDescription: "3D Wallpaper")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        // Task 8 wires this up
    }
}
```

- [ ] **Step 4: Commit**

```bash
git init && git add .
git commit -m "feat: scaffold macOS menu-bar app"
```

---

## Task 2: WallpaperLayer Value Type

**Files:**
- Create: `src/WallpaperLayer.swift`
- Create: `tests/WallpaperLayerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// tests/WallpaperLayerTests.swift
import XCTest
@testable import WallpapperApp   // match your module name

final class WallpaperLayerTests: XCTestCase {

    func test_layers_sortedByDepthAscending() {
        let layers = [
            WallpaperLayer(imageName: "sky", depth: 10.0, parallaxScale: 0.2),
            WallpaperLayer(imageName: "mid", depth:  5.0, parallaxScale: 0.5),
            WallpaperLayer(imageName: "fg",  depth:  1.0, parallaxScale: 1.0),
        ]
        let sorted = layers.sorted()
        XCTAssertEqual(sorted.map(\.imageName), ["fg", "mid", "sky"])
    }

    func test_defaultParallaxScale_clampedToValidRange() {
        let layer = WallpaperLayer(imageName: "x", depth: 5, parallaxScale: 3.0)
        XCTAssertLessThanOrEqual(layer.parallaxScale, 1.0)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme 3DWallpaper -destination 'platform=macOS'
```
Expected: compile error — `WallpaperLayer` not defined.

- [ ] **Step 3: Implement WallpaperLayer**

```swift
// src/WallpaperLayer.swift
import Foundation

struct WallpaperLayer: Comparable {
    let imageName: String
    /// Distance from camera. Larger = farther away.
    let depth: Double
    /// How much this layer moves per unit of head offset (0–1). Closer layers move more.
    let parallaxScale: Double

    init(imageName: String, depth: Double, parallaxScale: Double) {
        self.imageName    = imageName
        self.depth        = depth
        self.parallaxScale = min(max(parallaxScale, 0), 1)
    }

    static func < (lhs: WallpaperLayer, rhs: WallpaperLayer) -> Bool {
        lhs.depth < rhs.depth   // ascending: foreground first
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
xcodebuild test -scheme 3DWallpaper -destination 'platform=macOS'
```

- [ ] **Step 5: Commit**

```bash
git add src/WallpaperLayer.swift tests/WallpaperLayerTests.swift
git commit -m "feat: add WallpaperLayer value type with depth sorting"
```

---

## Task 3: HeadSmoother (EMA Filter)

**Files:**
- Create: `src/HeadSmoother.swift`
- Create: `tests/HeadSmootherTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// tests/HeadSmootherTests.swift
import XCTest
@testable import WallpapperApp

final class HeadSmootherTests: XCTestCase {

    func test_firstUpdate_returnsInput() {
        let smoother = HeadSmoother(alpha: 0.5)
        let result = smoother.update(CGPoint(x: 0.8, y: 0.3))
        XCTAssertEqual(result.x, 0.8, accuracy: 0.001)
        XCTAssertEqual(result.y, 0.3, accuracy: 0.001)
    }

    func test_subsequentUpdates_blendTowardNewValue() {
        let smoother = HeadSmoother(alpha: 0.5)
        _ = smoother.update(CGPoint(x: 0.0, y: 0.0))
        let result = smoother.update(CGPoint(x: 1.0, y: 1.0))
        // EMA: 0.0 * (1-0.5) + 1.0 * 0.5 = 0.5
        XCTAssertEqual(result.x, 0.5, accuracy: 0.001)
    }

    func test_reset_clearsState() {
        let smoother = HeadSmoother(alpha: 0.5)
        _ = smoother.update(CGPoint(x: 1.0, y: 1.0))
        smoother.reset()
        let result = smoother.update(CGPoint(x: 0.2, y: 0.2))
        XCTAssertEqual(result.x, 0.2, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme 3DWallpaper -destination 'platform=macOS'
```

- [ ] **Step 3: Implement HeadSmoother**

```swift
// src/HeadSmoother.swift
import CoreGraphics

/// Exponential moving average filter to smooth noisy head-position input.
/// alpha: weight given to new sample (0 = ignore new, 1 = no smoothing).
final class HeadSmoother {
    private let alpha: Double
    private var current: CGPoint?

    init(alpha: Double = 0.15) {
        self.alpha = min(max(alpha, 0), 1)
    }

    func update(_ point: CGPoint) -> CGPoint {
        guard let prev = current else {
            current = point
            return point
        }
        let smoothed = CGPoint(
            x: prev.x * (1 - alpha) + point.x * alpha,
            y: prev.y * (1 - alpha) + point.y * alpha
        )
        current = smoothed
        return smoothed
    }

    func reset() { current = nil }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
xcodebuild test -scheme 3DWallpaper -destination 'platform=macOS'
```

- [ ] **Step 5: Commit**

```bash
git add src/HeadSmoother.swift tests/HeadSmootherTests.swift
git commit -m "feat: add EMA head position smoother"
```

---

## Task 4: HeadTracker (Vision face detection)

**Files:**
- Create: `src/HeadTracker.swift`
- Create: `tests/HeadTrackerTests.swift`

- [ ] **Step 1: Write failing tests (coordinate normalization only — Vision itself is not unit-tested)**

```swift
// tests/HeadTrackerTests.swift
import XCTest
@testable import WallpapperApp

final class HeadTrackerTests: XCTestCase {

    /// Vision returns bounding boxes in bottom-left origin. We flip Y for display.
    func test_convertVisionBox_toCenterPoint_flipsY() {
        // A face box at x:0.4, y:0.3 (bottom-left origin), size 0.2x0.2
        // Center in Vision coords: (0.5, 0.4)
        // After Y-flip: (0.5, 0.6)
        let box = CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.2)
        let point = HeadTracker.centerPoint(from: box)
        XCTAssertEqual(point.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(point.y, 0.6, accuracy: 0.001)   // 1 - (0.3 + 0.1)
    }
}
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement HeadTracker**

```swift
// src/HeadTracker.swift
import AVFoundation
import Vision

protocol HeadTrackerDelegate: AnyObject {
    /// Called on an arbitrary background queue.
    func headTracker(_ tracker: HeadTracker, didDetectPosition position: CGPoint)
    func headTrackerDidLoseFace(_ tracker: HeadTracker)
}

final class HeadTracker {
    weak var delegate: HeadTrackerDelegate?

    private lazy var request = VNDetectFaceRectanglesRequest(completionHandler: handleResults)
    private let requestHandler = VNSequenceRequestHandler()

    // MARK: - Public

    func process(sampleBuffer: CMSampleBuffer) {
        try? requestHandler.perform([request], on: sampleBuffer,
                                    orientation: .leftMirrored)
    }

    // MARK: - Internal (exposed for testing)

    static func centerPoint(from boundingBox: CGRect) -> CGPoint {
        CGPoint(
            x: boundingBox.midX,
            y: 1.0 - boundingBox.midY   // flip Vision's bottom-left origin to top-left
        )
    }

    // MARK: - Private

    private func handleResults(request: VNRequest, error: Error?) {
        guard
            let results = request.results as? [VNFaceObservation],
            let face = results.first
        else {
            delegate?.headTrackerDidLoseFace(self)
            return
        }
        let point = Self.centerPoint(from: face.boundingBox)
        delegate?.headTracker(self, didDetectPosition: point)
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/HeadTracker.swift tests/HeadTrackerTests.swift
git commit -m "feat: add Vision-based head tracker with Y-flip normalization"
```

---

## Task 5: CameraManager (AVFoundation capture)

**Files:**
- Create: `src/CameraManager.swift`

*(AVFoundation hardware access is integration-level; we skip unit tests here and rely on manual testing.)*

- [ ] **Step 1: Implement CameraManager**

```swift
// src/CameraManager.swift
import AVFoundation

/// Captures webcam frames and delivers them for in-memory processing ONLY.
/// Frames are NEVER written to disk, logged, or transmitted — they go directly
/// to the Vision request handler and are released immediately after.
final class CameraManager: NSObject {
    var onFrame: ((CMSampleBuffer) -> Void)?

    private let session = AVCaptureSession()
    private let output  = AVCaptureVideoDataOutput()
    private let queue   = DispatchQueue(label: "com.3dwallpaper.camera", qos: .userInteractive)

    func start() throws {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480   // low res = fast Vision processing

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                  for: .video, position: .front)
                      ?? AVCaptureDevice.default(for: .video),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { throw CameraError.noCamera }

        session.addInput(input)
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(output) else { throw CameraError.outputFailed }
        session.addOutput(output)
        session.commitConfiguration()
        session.startRunning()
    }

    func stop() { session.stopRunning() }

    enum CameraError: Error { case noCamera, outputFailed }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
    }
}
```

- [ ] **Step 2: Manual smoke test**

Build and run; add a temporary `print` to `onFrame` to confirm frames arrive.

- [ ] **Step 3: Commit**

```bash
git add src/CameraManager.swift
git commit -m "feat: add AVFoundation camera manager"
```

---

## Task 6: ParallaxScene (SceneKit scene)

**Files:**
- Create: `src/ParallaxScene.swift`

The scene uses a perspective camera rig. Each depth layer is a flat `SCNPlane` with the layer's image as its diffuse texture. Layers are positioned along Z; the camera sits at Z=0 and looks toward negative Z.

- [ ] **Step 1: Implement ParallaxScene**

```swift
// src/ParallaxScene.swift
import SceneKit

final class ParallaxScene {
    let scene: SCNScene
    private let cameraNode: SCNNode

    init(layers: [WallpaperLayer], sceneSize: CGSize) {
        scene      = SCNScene()
        cameraNode = SCNNode()

        // Camera
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar  = 500
        cameraNode.camera   = camera
        cameraNode.position = SCNVector3(0, 0, 20)
        scene.rootNode.addChildNode(cameraNode)

        // Ambient light so textures are fully visible
        let ambient = SCNNode()
        ambient.light = {
            let l = SCNLight(); l.type = .ambient; l.intensity = 1000; return l
        }()
        scene.rootNode.addChildNode(ambient)

        // Build one plane per layer
        for layer in layers.sorted().reversed() {   // back-to-front
            addLayer(layer, sceneSize: sceneSize)
        }
    }

    /// Animate camera toward target offset (called each head-position update).
    /// `offset` is in scene units; positive X = camera moves right (scene shifts left).
    func updateCameraOffset(_ offset: CGPoint) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.08
        cameraNode.position.x = Float(offset.x)
        cameraNode.position.y = Float(offset.y)
        SCNTransaction.commit()
    }

    // MARK: - Private

    private func addLayer(_ layer: WallpaperLayer, sceneSize: CGSize) {
        let aspect = sceneSize.width / sceneSize.height
        let planeH: CGFloat = 30
        let planeW = planeH * aspect

        let geometry = SCNPlane(width: planeW * (1 + CGFloat(layer.parallaxScale) * 0.5),
                                 height: planeH)

        if let image = NSImage(named: layer.imageName) {
            geometry.firstMaterial?.diffuse.contents = image
        }
        geometry.firstMaterial?.isDoubleSided = true

        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(0, 0, Float(-layer.depth))
        scene.rootNode.addChildNode(node)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/ParallaxScene.swift
git commit -m "feat: add SceneKit parallax scene with layered planes"
```

---

## Task 7: Portal Scenes — 3 MVP Wallpapers

**Files:**
- Create: `src/portals/CosmosPortal.swift`
- Create: `src/portals/MidnightCityPortal.swift`
- Create: `src/portals/AbyssPortal.swift`
- Create: `src/portals/PortalScene.swift`  (shared protocol)

All portals are **fully procedural** — no external image assets. Each returns a ready-to-use `SCNScene` that plugs directly into `ParallaxScene`.

---

### Portal Design Overview

```
Portal 1 — COSMOS          Portal 2 — MIDNIGHT CITY      Portal 3 — ABYSS
──────────────────────────────────────────────────────────────────────────
 depth 40  Star field        City sky gradient              Deep ocean black
 depth 28  Nebula wash       Distant glowing towers         Bioluminescence
 depth 16  Planet + glow     Neon bridge / mid-rise         Coral formations
 depth  6  Asteroid belt     Rain particle system           Fish silhouettes
 depth  1  Porthole frame    Frosted window frame           Submarine frame
──────────────────────────────────────────────────────────────────────────
Head moves left → each layer shifts right by its own rate → 3-D depth
```

---

### Portal 1: COSMOS — deep space through a porthole

The viewer peers through a metallic spacecraft porthole into a vast nebula. A gas giant sits at mid-depth; moving your head reveals the star field curving around it. Asteroid chunks drift at an intermediate layer.

- **Background (depth 40):** Black SCNPlane covered in hundreds of tiny emissive white/blue SCNSphere nodes (stars). Slow rotation animation adds subtle life.
- **Nebula (depth 28):** Large semi-transparent SCNPlane with a radial gradient material (purple → deep blue), `blendMode = .add`. Gives the space-glow look.
- **Planet (depth 16):** `SCNSphere` with a `diffuse` texture generated from `CIFilter` (swirling marble pattern in blue/teal). A second concentric `SCNSphere` slightly larger with emissive blue = atmosphere rim.
- **Asteroid belt (depth 6):** 12 small `SCNSphere`/`SCNBox` nodes at varying X/Y offsets, grey rocky material, subtle rotation animation.
- **Porthole frame (depth 1):** `SCNTube` (thick circular ring) with brushed-metal material. Casts a vignette shadow on the inner scene.

```swift
// src/portals/CosmosPortal.swift
import SceneKit

enum CosmosPortal {
    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.black

        addStarField(to: scene.rootNode, count: 600, depth: -40)
        addNebula(to: scene.rootNode, depth: -28)
        addPlanet(to: scene.rootNode, depth: -16)
        addAsteroids(to: scene.rootNode, depth: -6)
        addPorthole(to: scene.rootNode, depth: -1)

        return scene
    }

    // MARK: – Stars
    private static func addStarField(to parent: SCNNode, count: Int, depth: Float) {
        let container = SCNNode()
        container.position.z = depth
        for _ in 0..<count {
            let r = Float.random(in: 0.02...0.12)
            let geo = SCNSphere(radius: CGFloat(r))
            geo.firstMaterial?.diffuse.contents  = NSColor.white
            geo.firstMaterial?.emission.contents = NSColor(white: 0.9, alpha: 1)
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float.random(in: -30...30),
                Float.random(in: -18...18),
                Float.random(in: -3...3)
            )
            container.addChildNode(node)
        }
        // Slow rotation so stars drift subtly
        container.runAction(.repeatForever(.rotateBy(x: 0, y: 0.05, z: 0, duration: 60)))
        parent.addChildNode(container)
    }

    // MARK: – Nebula (additive blended plane)
    private static func addNebula(to parent: SCNNode, depth: Float) {
        let plane = SCNPlane(width: 60, height: 36)
        let mat = SCNMaterial()
        // Radial gradient purple→blue via Core Image
        let grad = CIFilter.radialGradient()
        grad.center    = CIVector(x: 200, y: 200)
        grad.radius0   = 60
        grad.radius1   = 200
        grad.color0    = CIColor(red: 0.5, green: 0.0, blue: 0.8, alpha: 0.7)
        grad.color1    = CIColor(red: 0.0, green: 0.0, blue: 0.2, alpha: 0.0)
        if let img = grad.outputImage {
            let rep = NSCIImageRep(ciImage: img)
            let ns  = NSImage(size: rep.size); ns.addRepresentation(rep)
            mat.diffuse.contents = ns
        }
        mat.blendMode  = .add
        mat.isDoubleSided = true
        plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.position.z = depth
        parent.addChildNode(node)
    }

    // MARK: – Planet
    private static func addPlanet(to parent: SCNNode, depth: Float) {
        // Core sphere
        let sphere = SCNSphere(radius: 4)
        let mat = SCNMaterial()
        mat.diffuse.contents  = makeMarbleImage(colors: [.cyan, .blue, .init(red: 0, green: 0.3, blue: 0.6, alpha: 1)])
        mat.specular.contents = NSColor.white
        mat.shininess = 50
        sphere.firstMaterial = mat
        let planet = SCNNode(geometry: sphere)
        planet.position.z = depth
        planet.runAction(.repeatForever(.rotateBy(x: 0, y: 0.2, z: 0, duration: 8)))

        // Atmosphere rim
        let atmo = SCNSphere(radius: 4.25)
        let amat = SCNMaterial()
        amat.diffuse.contents  = NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.18)
        amat.emission.contents = NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 0.3)
        amat.blendMode = .add; amat.isDoubleSided = true
        atmo.firstMaterial = amat
        planet.addChildNode(SCNNode(geometry: atmo))

        parent.addChildNode(planet)
    }

    // MARK: – Asteroid belt
    private static func addAsteroids(to parent: SCNNode, depth: Float) {
        let positions: [(Float, Float)] = [(-8,3),(5,-2),(-3,5),(9,1),(-6,-4),(4,6),
                                           (-10,0),(7,-5),(2,4),(-4,-6),(8,3),(-1,-3)]
        for (x, y) in positions {
            let size = Float.random(in: 0.2...0.7)
            let geo  = Bool.random() ? SCNGeometry(SCNSphere(radius: CGFloat(size)))
                                     : SCNGeometry(SCNBox(width: CGFloat(size), height: CGFloat(size),
                                                          length: CGFloat(size * 0.7), chamferRadius: 0.05))
            let mat  = SCNMaterial()
            mat.diffuse.contents = NSColor(white: CGFloat.random(in: 0.3...0.5), alpha: 1)
            geo.firstMaterial    = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(x, y, depth)
            node.runAction(.repeatForever(.rotateBy(x: 1, y: 1, z: 0.3, duration: Double.random(in: 4...12))))
            parent.addChildNode(node)
        }
    }

    // MARK: – Porthole frame
    private static func addPorthole(to parent: SCNNode, depth: Float) {
        let tube = SCNTube(innerRadius: 8, outerRadius: 9.5, height: 0.5)
        let mat  = SCNMaterial()
        mat.diffuse.contents  = NSColor(white: 0.25, alpha: 1)
        mat.specular.contents = NSColor.white
        mat.shininess = 80
        tube.firstMaterial = mat
        let frame = SCNNode(geometry: tube)
        frame.position.z = depth
        frame.eulerAngles.x = .pi / 2   // face camera
        parent.addChildNode(frame)
    }

    // MARK: – Helpers
    private static func makeMarbleImage(colors: [NSColor]) -> NSImage {
        let size = CGSize(width: 512, height: 512)
        let img  = NSImage(size: size)
        img.lockFocus()
        let ctx  = NSGraphicsContext.current!.cgContext
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors.map(\.cgColor) as CFArray,
                              locations: [0, 0.5, 1])!
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: 0, y: 0),
                               end:   CGPoint(x: size.width, y: size.height),
                               options: [])
        img.unlockFocus()
        return img
    }
}

// Helper so both SCNSphere and SCNBox can share the same code path
private extension SCNGeometry {
    init(_ sphere: SCNSphere) { self = sphere }
    init(_ box: SCNBox) { self = box }
}
```

---

### Portal 2: MIDNIGHT CITY — cyberpunk rain at night

Rain streaks down a frosted window pane. Behind it: a neon-lit city in layers — a glowing bridge at mid-distance, towers receding into dark sky further back. Moving your head makes near rain and far towers drift at completely different rates.

- **Sky (depth 35):** Black→deep-indigo gradient `SCNPlane`.
- **Distant towers (depth 22):** 20–30 tall thin `SCNBox` nodes of varying height arranged as a skyline. Emissive materials simulate lit windows.
- **Neon mid-ground (depth 12):** A wide `SCNPlane` with a procedurally generated neon-sign texture (CIFilter pixel art). Pink/cyan emissive.
- **Rain particles (depth 5):** `SCNParticleSystem` with long thin streaks, fast velocity, emissive white, slight angle.
- **Frosted window frame (depth 1):** `SCNBox` rectangle border (hollow middle) with slightly frosted/translucent material.

```swift
// src/portals/MidnightCityPortal.swift
import SceneKit

enum MidnightCityPortal {
    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.black

        addSky(to: scene.rootNode, depth: -35)
        addTowers(to: scene.rootNode, depth: -22)
        addNeonMidground(to: scene.rootNode, depth: -12)
        addRain(to: scene.rootNode, depth: -5)
        addWindowFrame(to: scene.rootNode, depth: -1)

        return scene
    }

    // MARK: – Night sky gradient
    private static func addSky(to parent: SCNNode, depth: Float) {
        let plane = SCNPlane(width: 80, height: 50)
        let mat   = SCNMaterial()
        let grad  = NSGradient(colors: [.black, NSColor(red: 0.04, green: 0.0, blue: 0.12, alpha: 1)])!
        let img   = NSImage(size: CGSize(width: 2, height: 512))
        img.lockFocus(); grad.draw(in: NSRect(origin: .zero, size: img.size), angle: 90); img.unlockFocus()
        mat.diffuse.contents = img
        plane.firstMaterial  = mat
        let node = SCNNode(geometry: plane); node.position.z = depth
        parent.addChildNode(node)
    }

    // MARK: – City skyline (towers)
    private static func addTowers(to parent: SCNNode, depth: Float) {
        let container = SCNNode(); container.position.z = depth

        let neonColors: [NSColor] = [
            NSColor(red: 1, green: 0.1, blue: 0.5, alpha: 1),   // pink
            NSColor(red: 0, green: 0.9, blue: 1.0, alpha: 1),   // cyan
            NSColor(red: 0.6, green: 0, blue: 1.0, alpha: 1),   // purple
            NSColor(red: 1, green: 0.6, blue: 0, alpha: 1),     // orange
        ]

        for i in -15...15 {
            let height  = Float.random(in: 4...18)
            let width   = Float.random(in: 0.8...2.2)
            let box     = SCNBox(width: CGFloat(width), height: CGFloat(height), length: 1.5, chamferRadius: 0)
            let mat     = SCNMaterial()
            mat.diffuse.contents  = NSColor(white: 0.05, alpha: 1)
            // Random windows: emissive dots scattered on face
            mat.emission.contents = neonColors.randomElement()!.withAlphaComponent(0.08)
            box.firstMaterial = mat

            let node = SCNNode(geometry: box)
            node.position = SCNVector3(Float(i) * 2.2 + Float.random(in: -0.5...0.5),
                                       height / 2 - 10,
                                       Float.random(in: -3...3))
            container.addChildNode(node)
        }
        parent.addChildNode(container)
    }

    // MARK: – Neon mid-ground strip
    private static func addNeonMidground(to parent: SCNNode, depth: Float) {
        // Horizontal glowing band simulating a neon-lit bridge/overpass
        let strip = SCNBox(width: 50, height: 0.4, length: 1, chamferRadius: 0)
        let mat   = SCNMaterial()
        mat.diffuse.contents  = NSColor(red: 1, green: 0.1, blue: 0.6, alpha: 1)
        mat.emission.contents = NSColor(red: 1, green: 0.1, blue: 0.6, alpha: 1)
        strip.firstMaterial = mat
        let glow = SCNNode(geometry: strip)
        glow.position = SCNVector3(0, -2, depth)
        parent.addChildNode(glow)

        // Vertical support pillars
        for x: Float in [-12, -4, 4, 12] {
            let pillar = SCNBox(width: 0.3, height: 6, length: 0.3, chamferRadius: 0)
            pillar.firstMaterial = mat
            let p = SCNNode(geometry: pillar)
            p.position = SCNVector3(x, -5, depth)
            parent.addChildNode(p)
        }
    }

    // MARK: – Rain particles
    private static func addRain(to parent: SCNNode, depth: Float) {
        let ps = SCNParticleSystem()
        ps.birthRate          = 800
        ps.particleLifeSpan   = 0.6
        ps.particleVelocity   = 30
        ps.particleVelocityVariation = 5
        ps.emitterShape       = SCNPlane(width: 40, height: 0)   // spawn along top band
        ps.particleSize       = 0.04
        ps.particleColor      = NSColor(white: 0.8, alpha: 0.6)
        ps.blendMode          = .additive
        // Angle rain slightly
        let emitter = SCNNode()
        emitter.position    = SCNVector3(0, 12, depth)
        emitter.eulerAngles = SCNVector3(-Float.pi / 2 + 0.15, 0, 0)
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }

    // MARK: – Frosted window frame
    private static func addWindowFrame(to parent: SCNNode, depth: Float) {
        func bar(w: CGFloat, h: CGFloat, x: Float, y: Float) {
            let box = SCNBox(width: w, height: h, length: 0.2, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents  = NSColor(white: 0.15, alpha: 0.9)
            mat.specular.contents = NSColor.white; mat.shininess = 60
            box.firstMaterial = mat
            let n = SCNNode(geometry: box); n.position = SCNVector3(x, y, depth)
            parent.addChildNode(n)
        }
        bar(w: 22, h: 0.6,  x: 0,  y: 9)    // top
        bar(w: 22, h: 0.6,  x: 0,  y: -9)   // bottom
        bar(w: 0.6, h: 18,  x: -11, y: 0)   // left
        bar(w: 0.6, h: 18,  x: 11,  y: 0)   // right
    }
}
```

---

### Portal 3: ABYSS — deep ocean through a submarine porthole

A circular submarine porthole looks into bioluminescent deep ocean. Slowly drifting jellyfish-like orbs pulse in the dark. Coral structures at mid-distance shift as you look around. Near: bubbles float up past the porthole glass.

- **Ocean floor darkness (depth 30):** Deep navy→black `SCNPlane`.
- **Bioluminescence (depth 20):** 30 softly glowing SCNSphere nodes in blue/teal/green, slow drift animation, additive blend.
- **Coral structures (depth 10):** A cluster of tapered `SCNPyramid` / `SCNCone` nodes in coral-red/orange with slight emissive.
- **Jellyfish (depth 7):** `SCNSphere` caps with thin `SCNCylinder` tentacle children, slow vertical bob animation, emissive teal.
- **Bubbles (depth 3):** `SCNParticleSystem` rising upward, small white spheres.
- **Porthole frame (depth 1):** `SCNTube` with bolt-like `SCNSphere` nodes around the rim.

```swift
// src/portals/AbyssPortal.swift
import SceneKit

enum AbyssPortal {
    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(red: 0, green: 0.01, blue: 0.04, alpha: 1)

        addOceanDepth(to: scene.rootNode, depth: -30)
        addBioluminescence(to: scene.rootNode, depth: -20)
        addCoral(to: scene.rootNode, depth: -10)
        addJellyfish(to: scene.rootNode, depth: -7)
        addBubbles(to: scene.rootNode, depth: -3)
        addPorthole(to: scene.rootNode, depth: -1)

        return scene
    }

    // MARK: – Deep ocean background
    private static func addOceanDepth(to parent: SCNNode, depth: Float) {
        let plane = SCNPlane(width: 80, height: 50)
        let mat   = SCNMaterial()
        let grad  = NSGradient(colors: [NSColor(red: 0, green: 0.02, blue: 0.1, alpha: 1), .black])!
        let img   = NSImage(size: CGSize(width: 2, height: 512))
        img.lockFocus(); grad.draw(in: NSRect(origin: .zero, size: img.size), angle: 90); img.unlockFocus()
        mat.diffuse.contents = img; plane.firstMaterial = mat
        let node = SCNNode(geometry: plane); node.position.z = depth
        parent.addChildNode(node)
    }

    // MARK: – Bioluminescent orbs
    private static func addBioluminescence(to parent: SCNNode, depth: Float) {
        let colors: [NSColor] = [
            NSColor(red: 0, green: 0.8, blue: 1, alpha: 1),
            NSColor(red: 0, green: 1, blue: 0.6, alpha: 1),
            NSColor(red: 0.2, green: 0.4, blue: 1, alpha: 1),
        ]
        for _ in 0..<30 {
            let r    = Float.random(in: 0.15...0.6)
            let orb  = SCNSphere(radius: CGFloat(r))
            let mat  = SCNMaterial()
            let col  = colors.randomElement()!
            mat.diffuse.contents  = col.withAlphaComponent(0.3)
            mat.emission.contents = col
            mat.blendMode = .add
            orb.firstMaterial = mat
            let node = SCNNode(geometry: orb)
            node.position = SCNVector3(Float.random(in: -20...20),
                                       Float.random(in: -12...12),
                                       depth + Float.random(in: -4...4))
            // Slow drift
            let drift = SCNAction.sequence([
                .moveBy(x: CGFloat.random(in: -1...1), y: CGFloat.random(in: -0.5...0.5), z: 0, duration: Double.random(in: 3...7)),
                .moveBy(x: CGFloat.random(in: -1...1), y: CGFloat.random(in: -0.5...0.5), z: 0, duration: Double.random(in: 3...7)),
            ])
            node.runAction(.repeatForever(drift))
            parent.addChildNode(node)
        }
    }

    // MARK: – Coral
    private static func addCoral(to parent: SCNNode, depth: Float) {
        let coralColor = NSColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1)
        for i in -5...5 {
            let height = Float.random(in: 1.5...5)
            let cone   = SCNCone(topRadius: 0, bottomRadius: CGFloat(Float.random(in: 0.2...0.5)),
                                 height: CGFloat(height))
            let mat    = SCNMaterial()
            mat.diffuse.contents  = coralColor
            mat.emission.contents = coralColor.withAlphaComponent(0.2)
            cone.firstMaterial = mat
            let node = SCNNode(geometry: cone)
            node.position = SCNVector3(Float(i) * 2.5 + Float.random(in: -0.8...0.8),
                                       -8 + height / 2,
                                       depth + Float.random(in: -2...2))
            node.eulerAngles.z = Float.random(in: -0.3...0.3)
            parent.addChildNode(node)
        }
    }

    // MARK: – Jellyfish
    private static func addJellyfish(to parent: SCNNode, depth: Float) {
        for _ in 0..<5 {
            let body = SCNSphere(radius: 0.8)
            let mat  = SCNMaterial()
            mat.diffuse.contents  = NSColor(red: 0, green: 0.9, blue: 0.9, alpha: 0.4)
            mat.emission.contents = NSColor(red: 0, green: 0.8, blue: 0.8, alpha: 0.6)
            mat.blendMode = .add; mat.isDoubleSided = true
            body.firstMaterial = mat
            let jelly = SCNNode(geometry: body)
            jelly.position = SCNVector3(Float.random(in: -8...8),
                                        Float.random(in: -4...4),
                                        depth + Float.random(in: -2...2))
            // Tentacles
            for t in 0..<6 {
                let cyl = SCNCylinder(radius: 0.04, height: 2)
                cyl.firstMaterial = mat
                let tNode = SCNNode(geometry: cyl)
                let angle = Float(t) * .pi * 2 / 6
                tNode.position = SCNVector3(cos(angle) * 0.5, -1.5, sin(angle) * 0.5)
                jelly.addChildNode(tNode)
            }
            // Bob up and down
            let bob = SCNAction.sequence([
                .moveBy(x: 0, y: 1, z: 0, duration: Double.random(in: 2...4)),
                .moveBy(x: 0, y: -1, z: 0, duration: Double.random(in: 2...4)),
            ])
            jelly.runAction(.repeatForever(bob))
            parent.addChildNode(jelly)
        }
    }

    // MARK: – Bubbles
    private static func addBubbles(to parent: SCNNode, depth: Float) {
        let ps = SCNParticleSystem()
        ps.birthRate        = 25
        ps.particleLifeSpan = 4
        ps.particleVelocity = 3
        ps.particleVelocityVariation = 1
        ps.emitterShape     = SCNPlane(width: 15, height: 0)
        ps.particleSize     = 0.15
        ps.particleColor    = NSColor(white: 1, alpha: 0.5)
        ps.blendMode        = .additive
        let emitter = SCNNode()
        emitter.position    = SCNVector3(0, -8, depth)
        emitter.eulerAngles = SCNVector3(.pi / 2, 0, 0)   // emit upward
        emitter.addParticleSystem(ps)
        parent.addChildNode(emitter)
    }

    // MARK: – Submarine porthole with bolts
    private static func addPorthole(to parent: SCNNode, depth: Float) {
        let tube = SCNTube(innerRadius: 7.5, outerRadius: 9, height: 0.8)
        let mat  = SCNMaterial()
        mat.diffuse.contents  = NSColor(red: 0.15, green: 0.18, blue: 0.2, alpha: 1)
        mat.specular.contents = NSColor.white; mat.shininess = 120
        tube.firstMaterial = mat
        let frame = SCNNode(geometry: tube)
        frame.position.z = depth; frame.eulerAngles.x = .pi / 2
        parent.addChildNode(frame)

        // 12 bolts around the rim
        for i in 0..<12 {
            let angle  = Float(i) * .pi * 2 / 12
            let bolt   = SCNSphere(radius: 0.25)
            bolt.firstMaterial = mat
            let bNode  = SCNNode(geometry: bolt)
            bNode.position = SCNVector3(cos(angle) * 8.25, sin(angle) * 8.25, depth)
            parent.addChildNode(bNode)
        }
    }
}
```

---

### Shared Protocol

```swift
// src/portals/PortalScene.swift
import SceneKit

enum Portal: String, CaseIterable {
    case cosmos      = "Cosmos"
    case midnightCity = "Midnight City"
    case abyss       = "Abyss"

    func makeScene() -> SCNScene {
        switch self {
        case .cosmos:       return CosmosPortal.makeScene()
        case .midnightCity: return MidnightCityPortal.makeScene()
        case .abyss:        return AbyssPortal.makeScene()
        }
    }

    var defaultSensitivity: Double {
        switch self {
        case .cosmos:       return 5.0   // large scale, subtle feels right
        case .midnightCity: return 7.0   // rain parallax benefits from more range
        case .abyss:        return 6.0
        }
    }
}
```

---

### Wire Portal Picker into Settings

Add to `AppSettings`:
```swift
var selectedPortal: String {
    get { defaults.string(forKey: "portal") ?? Portal.cosmos.rawValue }
    set { defaults.set(newValue, forKey: "portal") }
}
```

Add `NSPopUpButton` to `SettingsWindowController`:
```swift
private let portalPicker = NSPopUpButton()

// In buildUI():
portalPicker.removeAllItems()
Portal.allCases.forEach { portalPicker.addItem(withTitle: $0.rawValue) }
portalPicker.selectItem(withTitle: AppSettings.shared.selectedPortal)
// ...add to stack: row("Portal", portalPicker)

// In controlChanged():
AppSettings.shared.selectedPortal = portalPicker.titleOfSelectedItem ?? Portal.cosmos.rawValue
```

And in `DesktopWindowController.applySettings()`:
```swift
let portal = Portal(rawValue: AppSettings.shared.selectedPortal) ?? .cosmos
// Rebuild scene with new portal
parallaxScene = ParallaxScene(scene: portal.makeScene(), sceneSize: currentSize)
scnView?.scene = parallaxScene?.scene
controller.sensitivity = portal.defaultSensitivity
```

- [ ] **Step 1: Create `src/portals/` directory, add all 4 files above**

- [ ] **Step 2: Build and verify each portal renders**

```bash
xcodebuild build -scheme 3DWallpaper -destination 'platform=macOS'
```

- [ ] **Step 3: Manual visual test — cycle through all 3 portals in Settings**

- [ ] **Step 4: Commit**

```bash
git add src/portals/
git commit -m "feat: 3 procedural MVP portals — Cosmos, Midnight City, Abyss"
```

---

## Task 8: ParallaxController (connect head → camera)

**Files:**
- Create: `src/ParallaxController.swift`
- Create: `tests/ParallaxControllerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// tests/ParallaxControllerTests.swift
import XCTest
import CoreGraphics
@testable import WallpapperApp

final class ParallaxControllerTests: XCTestCase {

    func test_headAtCenter_producesZeroOffset() {
        let controller = ParallaxController(sensitivity: 5.0)
        let offset = controller.cameraOffset(for: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(offset.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(offset.y, 0.0, accuracy: 0.001)
    }

    func test_headMovesLeft_cameraMovesRight() {
        // Head at x=0.2 (left of center). Camera should move negative X
        // so scene appears to shift right (window effect).
        let controller = ParallaxController(sensitivity: 10.0)
        let offset = controller.cameraOffset(for: CGPoint(x: 0.2, y: 0.5))
        XCTAssertLessThan(offset.x, 0.0)
    }

    func test_sensitivityScalesOffset() {
        let low  = ParallaxController(sensitivity: 2.0)
        let high = ParallaxController(sensitivity: 8.0)
        let pos  = CGPoint(x: 0.8, y: 0.5)
        let offsetLow  = low.cameraOffset(for: pos)
        let offsetHigh = high.cameraOffset(for: pos)
        XCTAssertGreaterThan(abs(offsetHigh.x), abs(offsetLow.x))
    }

    /// Distance from center is preserved proportionally (spec: "exact direction and distance").
    func test_largerHeadDisplacement_producesProportionallyLargerOffset() {
        let controller = ParallaxController(sensitivity: 10.0)
        let smallMove  = controller.cameraOffset(for: CGPoint(x: 0.6, y: 0.5))  // 0.1 from center
        let largeMove  = controller.cameraOffset(for: CGPoint(x: 0.8, y: 0.5))  // 0.3 from center
        // Large move should be 3x the small move
        XCTAssertEqual(abs(largeMove.x) / abs(smallMove.x), 3.0, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement ParallaxController**

```swift
// src/ParallaxController.swift
import CoreGraphics

final class ParallaxController {
    var sensitivity: Double

    init(sensitivity: Double = 5.0) {
        self.sensitivity = sensitivity
    }

    /// Converts a normalized head position (0–1 each axis, origin top-left)
    /// into a scene-unit camera offset.
    ///
    /// Mapping is strictly linear (proportional): doubling the head displacement
    /// doubles the camera displacement, preserving exact direction and distance.
    /// sensitivity scales the magnitude; direction is always preserved.
    ///
    /// When head moves left (x < 0.5), camera moves left (negative X),
    /// making the scene appear to shift right — the "window" effect.
    func cameraOffset(for headPosition: CGPoint) -> CGPoint {
        CGPoint(
            x: (headPosition.x - 0.5) * sensitivity,
            y: -(headPosition.y - 0.5) * sensitivity   // Y inverted: head up → camera up
        )
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/ParallaxController.swift tests/ParallaxControllerTests.swift
git commit -m "feat: add parallax controller for head-to-camera mapping"
```

---

## Task 8: DesktopWindowController (desktop-layer NSWindow + SCNView)

**Files:**
- Create: `src/DesktopWindowController.swift`

This is the most macOS-specific piece. The window sits just above the desktop wallpaper but below all app windows.

- [ ] **Step 1: Implement DesktopWindowController**

```swift
// src/DesktopWindowController.swift
import AppKit
import SceneKit

final class DesktopWindowController: NSWindowController {

    private var scnView: SCNView?
    private var parallaxScene: ParallaxScene?
    private let controller  = ParallaxController(sensitivity: 6.0)
    private let smoother    = HeadSmoother(alpha: 0.12)
    private let headTracker = HeadTracker()
    private let camera      = CameraManager()

    // MARK: - Init

    convenience init() {
        // Cover all screens; use primary screen to start
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask:   .borderless,
            backing:     .buffered,
            defer:       false
        )
        window.level           = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isOpaque        = true
        window.backgroundColor = .black
        window.ignoresMouseEvents = true

        self.init(window: window)
        buildScene(for: screen.frame.size)
        startTracking()
    }

    // MARK: - Private

    private func buildScene(for size: CGSize) {
        let layers = defaultLayers()
        let scene  = ParallaxScene(layers: layers, sceneSize: size)
        parallaxScene = scene

        let view = SCNView(frame: NSRect(origin: .zero, size: size))
        view.scene           = scene.scene
        view.allowsCameraControl = false
        view.antialiasingMode    = .multisampling4X
        view.preferredFramesPerSecond = 60
        window?.contentView  = view
        scnView = view
    }

    private func startTracking() {
        headTracker.delegate = self
        camera.onFrame = { [weak self] buffer in
            self?.headTracker.process(sampleBuffer: buffer)
        }
        try? camera.start()
    }

    /// Override with user-supplied images in Task 9 (Settings).
    private func defaultLayers() -> [WallpaperLayer] {
        [
            WallpaperLayer(imageName: "layer_bg",  depth: 15, parallaxScale: 0.15),
            WallpaperLayer(imageName: "layer_mid", depth:  8, parallaxScale: 0.45),
            WallpaperLayer(imageName: "layer_fg",  depth:  3, parallaxScale: 0.90),
        ]
    }
}

// MARK: - HeadTrackerDelegate

extension DesktopWindowController: HeadTrackerDelegate {
    func headTracker(_ tracker: HeadTracker, didDetectPosition position: CGPoint) {
        let smoothed = smoother.update(position)
        let offset   = controller.cameraOffset(for: smoothed)
        DispatchQueue.main.async { [weak self] in
            self?.parallaxScene?.updateCameraOffset(offset)
        }
    }

    func headTrackerDidLoseFace(_ tracker: HeadTracker) {
        // Gently return to center
        DispatchQueue.main.async { [weak self] in
            self?.parallaxScene?.updateCameraOffset(.zero)
        }
    }
}
```

- [ ] **Step 2: Add bundle images**

In Xcode, add three placeholder images to `Assets.xcassets`:
- `layer_bg`  — wide landscape photo (sky + horizon)
- `layer_mid` — midground with transparency or cutout (trees, buildings)
- `layer_fg`  — foreground element (window frame or plants, with alpha)

Use PNG with alpha for non-background layers.

- [ ] **Step 3: Build and run manual smoke test**

```bash
xcodebuild build -scheme 3DWallpaper
# Then run via Xcode — menu bar icon should appear; desktop should show scene
```

Move your head; scene should shift.

- [ ] **Step 4: Commit**

```bash
git add src/DesktopWindowController.swift
git commit -m "feat: add desktop-level window rendering parallax scene with head tracking"
```

---

## Task 9: AppSettings Model (UserDefaults persistence)

**Files:**
- Create: `src/AppSettings.swift`
- Create: `tests/AppSettingsTests.swift`

All user preferences live in one observable object so Settings UI and the rendering pipeline always read from the same source.

- [ ] **Step 1: Write failing tests**

```swift
// tests/AppSettingsTests.swift
import XCTest
@testable import WallpapperApp

final class AppSettingsTests: XCTestCase {

    override func setUp() {
        // Use ephemeral suite so tests don't pollute real prefs
        AppSettings.shared = AppSettings(suiteName: "test-\(UUID())")
    }

    func test_sensitivity_defaultValue() {
        XCTAssertEqual(AppSettings.shared.sensitivity, 6.0, accuracy: 0.001)
    }

    func test_sensitivity_persistsRoundTrip() {
        AppSettings.shared.sensitivity = 11.5
        XCTAssertEqual(AppSettings.shared.sensitivity, 11.5, accuracy: 0.001)
    }

    func test_fieldOfView_clamped() {
        AppSettings.shared.fieldOfView = 200   // out of valid range
        XCTAssertLessThanOrEqual(AppSettings.shared.fieldOfView, 120)
    }

    func test_depthIntensity_clamped() {
        AppSettings.shared.depthIntensity = -1
        XCTAssertGreaterThanOrEqual(AppSettings.shared.depthIntensity, 0)
    }
}
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement AppSettings**

```swift
// src/AppSettings.swift
import Foundation

final class AppSettings {
    static var shared = AppSettings()

    private let defaults: UserDefaults

    init(suiteName: String = "com.3dwallpaper.prefs") {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    /// 1–15, default 6. How far the camera moves per unit head displacement.
    var sensitivity: Double {
        get { defaults.double(forKey: "sensitivity").nonZero(default: 6.0) }
        set { defaults.set(newValue, forKey: "sensitivity") }
    }

    /// 30–120 degrees, default 60.
    var fieldOfView: Double {
        get { min(max(defaults.double(forKey: "fov").nonZero(default: 60), 30), 120) }
        set { defaults.set(min(max(newValue, 30), 120), forKey: "fov") }
    }

    /// 0–1, default 1. Multiplier on layer depth values.
    var depthIntensity: Double {
        get { min(max(defaults.double(forKey: "depthIntensity").nonZero(default: 1.0), 0), 1) }
        set { defaults.set(min(max(newValue, 0), 1), forKey: "depthIntensity") }
    }

    /// NSScreen.localizedName of the chosen display, or nil → primary screen.
    var targetDisplayName: String? {
        get { defaults.string(forKey: "targetDisplay") }
        set { defaults.set(newValue, forKey: "targetDisplay") }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }
}

private extension Double {
    func nonZero(default value: Double) -> Double { self == 0 ? value : self }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/AppSettings.swift tests/AppSettingsTests.swift
git commit -m "feat: add UserDefaults-backed AppSettings model"
```

---

## Task 10: Settings Panel (full UI)

**Files:**
- Create: `src/SettingsWindowController.swift`
- Modify: `src/AppDelegate.swift`

Covers: sensitivity, monitor picker, depth intensity, FOV, launch at login.

- [ ] **Step 1: Implement Settings panel**

```swift
// src/SettingsWindowController.swift
import AppKit
import ServiceManagement

final class SettingsWindowController: NSWindowController {

    var onChange: (() -> Void)?   // called whenever any setting changes

    // Controls
    private let sensitivitySlider  = NSSlider(value: AppSettings.shared.sensitivity,
                                              minValue: 1, maxValue: 15, target: nil, action: nil)
    private let depthSlider        = NSSlider(value: AppSettings.shared.depthIntensity,
                                              minValue: 0, maxValue: 1, target: nil, action: nil)
    private let fovSlider          = NSSlider(value: AppSettings.shared.fieldOfView,
                                              minValue: 30, maxValue: 120, target: nil, action: nil)
    private let monitorPicker      = NSPopUpButton()
    private let launchAtLoginCheck = NSButton(checkboxWithTitle: "Launch at login",
                                              target: nil, action: nil)

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 280),
            styleMask:   [.titled, .closable],
            backing:     .buffered,
            defer:       false
        )
        window.title = "3D Wallpaper Settings"
        self.init(window: window)
        buildUI()
    }

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment   = .leading
        stack.spacing     = 14
        stack.edgeInsets  = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        // Monitor picker
        monitorPicker.removeAllItems()
        for screen in NSScreen.screens {
            monitorPicker.addItem(withTitle: screen.localizedName)
        }
        if let saved = AppSettings.shared.targetDisplayName {
            monitorPicker.selectItem(withTitle: saved)
        }

        launchAtLoginCheck.state = AppSettings.shared.launchAtLogin ? .on : .off

        // Wire targets
        for control in [sensitivitySlider, depthSlider, fovSlider] as [NSControl] {
            control.target = self; control.action = #selector(controlChanged)
        }
        monitorPicker.target      = self; monitorPicker.action      = #selector(controlChanged)
        launchAtLoginCheck.target = self; launchAtLoginCheck.action = #selector(controlChanged)

        func row(_ label: String, _ control: NSView) -> NSStackView {
            let lbl = NSTextField(labelWithString: label)
            lbl.frame.size.width = 140
            let h = NSStackView(views: [lbl, control])
            h.orientation = .horizontal; h.spacing = 12
            return h
        }

        stack.addArrangedSubview(row("Monitor",         monitorPicker))
        stack.addArrangedSubview(row("Sensitivity",     sensitivitySlider))
        stack.addArrangedSubview(row("Depth intensity", depthSlider))
        stack.addArrangedSubview(row("Field of view",   fovSlider))
        stack.addArrangedSubview(launchAtLoginCheck)

        window?.contentView = stack
    }

    @objc private func controlChanged() {
        AppSettings.shared.sensitivity    = sensitivitySlider.doubleValue
        AppSettings.shared.depthIntensity = depthSlider.doubleValue
        AppSettings.shared.fieldOfView    = fovSlider.doubleValue
        AppSettings.shared.targetDisplayName = monitorPicker.titleOfSelectedItem
        let login = launchAtLoginCheck.state == .on
        AppSettings.shared.launchAtLogin  = login
        // Task 13 will call LoginItemManager here
        onChange?()
    }
}
```

- [ ] **Step 2: Wire into AppDelegate**

```swift
// AppDelegate.swift — replace openSettings stub:
private var settingsController: SettingsWindowController?

@objc private func openSettings() {
    if settingsController == nil {
        settingsController = SettingsWindowController()
        settingsController?.onChange = { [weak self] in
            self?.desktopWindowController?.applySettings()
        }
    }
    settingsController?.showWindow(nil)
    settingsController?.window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
```

- [ ] **Step 3: Add `applySettings()` to DesktopWindowController**

```swift
// In DesktopWindowController:
func applySettings() {
    controller.sensitivity = AppSettings.shared.sensitivity
    parallaxScene?.fieldOfView    = AppSettings.shared.fieldOfView
    parallaxScene?.depthIntensity = AppSettings.shared.depthIntensity
    // Monitor switch: rebuild windows if targetDisplay changed (Task 11 handles this)
}
```

- [ ] **Step 4: Expose FOV + depthIntensity on ParallaxScene**

```swift
// In ParallaxScene, add:
var fieldOfView: Double = 60 {
    didSet { cameraNode.camera?.fieldOfView = fieldOfView }
}

var depthIntensity: Double = 1.0 {
    didSet {
        // Scale each layer node's Z by depthIntensity
        scene.rootNode.childNodes.forEach { node in
            node.position.z = node.position.z / Float(oldValue) * Float(depthIntensity)
        }
    }
}
```

- [ ] **Step 5: Run all tests**

```bash
xcodebuild test -scheme 3DWallpaper -destination 'platform=macOS'
```

- [ ] **Step 6: Commit**

```bash
git add src/SettingsWindowController.swift src/AppDelegate.swift src/ParallaxScene.swift
git commit -m "feat: full settings panel (monitor, sensitivity, FOV, depth, login)"
```

---

## Task 11: Multi-Screen Support (Monitor Picker)

**Files:**
- Modify: `src/DesktopWindowController.swift`

- [ ] **Step 1: Handle monitor selection + multiple displays**

```swift
// In DesktopWindowController, replace screen selection:

/// Returns the screen the user chose in Settings, falling back to primary.
private static func targetScreen() -> NSScreen {
    if let name = AppSettings.shared.targetDisplayName {
        return NSScreen.screens.first { $0.localizedName == name } ?? NSScreen.main ?? NSScreen.screens[0]
    }
    return NSScreen.main ?? NSScreen.screens[0]
}

convenience init() {
    let target = DesktopWindowController.targetScreen()
    let window = DesktopWindowController.makeDesktopWindow(for: target)
    self.init(window: window)
    buildScene(for: target.frame.size)
    startTracking()
}

private static func makeDesktopWindow(for screen: NSScreen) -> NSWindow {
    let w = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                     backing: .buffered, defer: false)
    w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
    w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    w.isOpaque = true; w.backgroundColor = .black; w.ignoresMouseEvents = true
    w.makeKeyAndOrderFront(nil)
    return w
}
```

- [ ] **Step 2: Rebuild windows when monitor changes**

```swift
// In AppDelegate.applySettings, if targetDisplay changed:
func rebuildDesktopWindow() {
    desktopWindowController?.close()
    desktopWindowController = DesktopWindowController()
    desktopWindowController?.showWindow(nil)
}
```

- [ ] **Step 3: Test with mirrored/extended display**

- [ ] **Step 4: Commit**

```bash
git add src/DesktopWindowController.swift
git commit -m "feat: monitor picker — render on user-selected display"
```

---

## Task 12: AutoPause (stop tracking when desktop is hidden)

**Files:**
- Create: `src/AutoPauseManager.swift`
- Create: `tests/AutoPauseManagerTests.swift`

Tracking must stop automatically when a fullscreen app covers the desktop. This saves battery and avoids holding the webcam from other apps.

- [ ] **Step 1: Write failing tests**

```swift
// tests/AutoPauseManagerTests.swift
import XCTest
@testable import WallpapperApp

final class AutoPauseManagerTests: XCTestCase {

    func test_startsUnpaused() {
        let mgr = AutoPauseManager()
        XCTAssertFalse(mgr.isPaused)
    }

    func test_pause_setsFlag() {
        let mgr = AutoPauseManager()
        mgr.simulatePause()
        XCTAssertTrue(mgr.isPaused)
    }

    func test_resume_clearsFlag() {
        let mgr = AutoPauseManager()
        mgr.simulatePause()
        mgr.simulateResume()
        XCTAssertFalse(mgr.isPaused)
    }
}
```

- [ ] **Step 2: Run to verify failure**

- [ ] **Step 3: Implement AutoPauseManager**

```swift
// src/AutoPauseManager.swift
import AppKit

final class AutoPauseManager {
    var onPause:  (() -> Void)?
    var onResume: (() -> Void)?

    private(set) var isPaused = false

    // MARK: - Lifecycle

    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appActivated),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDeactivated),
                       name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        // Also observe space changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Testing seams

    func simulatePause()  { pause() }
    func simulateResume() { resume() }

    // MARK: - Private

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else { return }
        // If a fullscreen app takes focus, the desktop is no longer visible
        if app.activationPolicy == .regular { pause() }
    }

    @objc private func appDeactivated(_ note: Notification) { resume() }
    @objc private func spaceChanged(_ note: Notification)   { evaluateVisibility() }

    private func evaluateVisibility() {
        // Desktop visible when Mission Control / no fullscreen foreground app
        let frontmostIsFullscreen = NSWorkspace.shared.frontmostApplication?.isActive == true
        frontmostIsFullscreen ? pause() : resume()
    }

    private func pause() {
        guard !isPaused else { return }
        isPaused = true
        onPause?()
    }

    private func resume() {
        guard isPaused else { return }
        isPaused = false
        onResume?()
    }
}
```

- [ ] **Step 4: Wire into DesktopWindowController**

```swift
// In DesktopWindowController, add:
private let autoPause = AutoPauseManager()

// In startTracking():
autoPause.onPause  = { [weak self] in self?.camera.stop() }
autoPause.onResume = { [weak self] in try? self?.camera.start() }
autoPause.start()
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
xcodebuild test -scheme 3DWallpaper -destination 'platform=macOS'
```

- [ ] **Step 6: Commit**

```bash
git add src/AutoPauseManager.swift tests/AutoPauseManagerTests.swift src/DesktopWindowController.swift
git commit -m "feat: auto-pause tracking when desktop is hidden by fullscreen app"
```

---

## Task 13: Launch at Login (SMAppService)

**Files:**
- Create: `src/LoginItemManager.swift`

Uses `SMAppService` (macOS 13+) — no legacy daemon needed.

- [ ] **Step 1: Implement LoginItemManager**

```swift
// src/LoginItemManager.swift
import ServiceManagement

enum LoginItemManager {

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // SMAppService throws if the user has denied via System Settings.
            // Surface to user via a dialog if needed — don't crash.
            print("[LoginItem] \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
```

- [ ] **Step 2: Wire into Settings panel**

```swift
// In SettingsWindowController.controlChanged():
LoginItemManager.setEnabled(login)
```

- [ ] **Step 3: Sync checkbox state on open** (reflects actual SMAppService status, not just saved pref)

```swift
// In SettingsWindowController.buildUI(), replace:
launchAtLoginCheck.state = AppSettings.shared.launchAtLogin ? .on : .off
// With:
launchAtLoginCheck.state = LoginItemManager.isEnabled ? .on : .off
```

- [ ] **Step 4: Manual test**

Enable "Launch at login" in Settings → log out → log back in → app should start automatically and appear in menu bar.

- [ ] **Step 5: Commit**

```bash
git add src/LoginItemManager.swift src/SettingsWindowController.swift
git commit -m "feat: launch at login via SMAppService"
```

---

## Task 14: Polish & Performance

**Files:**
- Modify: `src/CameraManager.swift`
- Modify: `src/HeadTracker.swift`

- [ ] **Step 1: Throttle Vision to 15 fps** (webcam runs at 30fps, we only need 15)

```swift
// In CameraManager, add frame counter:
private var frameCount = 0

func captureOutput(...) {
    frameCount += 1
    guard frameCount % 2 == 0 else { return }   // drop every other frame
    onFrame?(sampleBuffer)
}
```

- [ ] **Step 2: Add face-loss debounce** (don't snap to center on single missed frame)

```swift
// In DesktopWindowController:
private var faceLossCount = 0
private let faceLossThreshold = 8   // ~0.5s at 15fps

func headTrackerDidLoseFace(_ tracker: HeadTracker) {
    faceLossCount += 1
    guard faceLossCount >= faceLossThreshold else { return }
    DispatchQueue.main.async { [weak self] in
        self?.parallaxScene?.updateCameraOffset(.zero)
    }
}

func headTracker(_ tracker: HeadTracker, didDetectPosition position: CGPoint) {
    faceLossCount = 0   // reset on each detected frame
    // ... rest of existing code
}
```

- [ ] **Step 3: Run all tests**

```bash
xcodebuild test -scheme 3DWallpaper -destination 'platform=macOS'
```
Expected: all PASS.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: add frame throttle and face-loss debounce for smooth parallax"
```

---

## Testing Checklist (Manual)

**Core rendering**
- [ ] Menu bar icon appears; app is absent from Dock
- [ ] Scene renders behind all app windows
- [ ] Moving head left → scene shifts right (window effect)
- [ ] Moving head right → scene shifts left
- [ ] Moving head up → scene shifts down
- [ ] Head lost → scene smoothly returns to center (after ~0.5s)

**Settings**
- [ ] Sensitivity slider changes parallax magnitude in real-time
- [ ] Depth intensity slider visibly changes layer separation
- [ ] FOV slider changes scene perspective in real-time
- [ ] Monitor picker moves the wallpaper to the chosen display
- [ ] Launch at login toggle persists across app restarts

**Auto-pause**
- [ ] Open a fullscreen app (e.g. YouTube in Safari fullscreen) → menu bar camera indicator goes inactive
- [ ] Exit fullscreen → tracking resumes within ~1 second
- [ ] Another app that requests camera (FaceTime, Zoom) can open without conflict after auto-pause

**Privacy**
- [ ] No files written during use: `sudo fs_usage -f filesys $(pgrep 3DWallpaper)` — no camera-related writes
- [ ] Network monitor (`lsof -p $(pgrep 3DWallpaper) -i`) shows zero outbound connections

**Performance**
- [ ] CPU stays below 15% on Apple Silicon (Activity Monitor)
- [ ] Camera permission prompt appears on first launch

---

## Known Limitations (document in app Help or tooltip)

| Limitation | Reason | Mitigation |
|---|---|---|
| One person at a time | Perspective can only be correct for one viewpoint — multiple faces cause conflicting offsets | Track only `results.first` (largest face); document clearly |
| Only one app can use the webcam at a time | macOS exclusive camera access | AutoPause releases camera so FaceTime/Zoom can take it |
| Perspective correct for one eye position only | Physical constraint of the monocular parallax illusion | None — fundamental |
| Bright backlight or face obstructions may lose tracking | Vision's face detector needs a clear face | Debounce (0.5s) before snapping back to center |

---

## Dependency-Free Alternatives

If SceneKit rendering performance is insufficient on older Intel Macs, replace `ParallaxScene` with a **Metal-based renderer** (`MTKView` + vertex buffer of quads). The rest of the pipeline (Vision, AVFoundation, HeadSmoother) remains unchanged — only `ParallaxScene.swift` and `DesktopWindowController.swift` need updating.
