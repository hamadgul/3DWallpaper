import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    public var desktopWindowController: DesktopWindowController?
    private var settingsController: SettingsWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
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

    @objc public func openSettings() {
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
}
