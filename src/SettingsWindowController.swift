import AppKit
import ServiceManagement

public final class SettingsWindowController: NSWindowController {

    public var onChange: (() -> Void)?

    // MARK: - Controls

    private let sensitivitySlider = NSSlider(value: AppSettings.shared.sensitivity,
                                              minValue: 1, maxValue: 15,
                                              target: nil, action: nil)
    private let depthSlider       = NSSlider(value: AppSettings.shared.depthIntensity,
                                              minValue: 0, maxValue: 1,
                                              target: nil, action: nil)
    private let fovSlider         = NSSlider(value: AppSettings.shared.fieldOfView,
                                              minValue: 30, maxValue: 120,
                                              target: nil, action: nil)
    private let monitorPicker      = NSPopUpButton()
    private let portalPicker       = NSPopUpButton()
    private let launchAtLoginCheck = NSButton(checkboxWithTitle: "Launch at login",
                                              target: nil, action: nil)

    // MARK: - Init

    public convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 310),
            styleMask:   [.titled, .closable],
            backing:     .buffered,
            defer:       false
        )
        window.title = "3D Wallpaper Settings"
        window.center()
        self.init(window: window)
        buildUI()
    }

    public override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI

    private func buildUI() {
        // Monitor picker
        monitorPicker.removeAllItems()
        for screen in NSScreen.screens {
            monitorPicker.addItem(withTitle: screen.localizedName)
        }
        if let saved = AppSettings.shared.targetDisplayName {
            monitorPicker.selectItem(withTitle: saved)
        }

        // Portal picker
        portalPicker.removeAllItems()
        Portal.allCases.forEach { portalPicker.addItem(withTitle: $0.rawValue) }
        portalPicker.selectItem(withTitle: AppSettings.shared.selectedPortal)

        // Launch at login reflects actual system state
        launchAtLoginCheck.state = LoginItemManager.isEnabled ? .on : .off

        // Wire targets
        for control in [sensitivitySlider, depthSlider, fovSlider] as [NSControl] {
            control.target = self
            control.action = #selector(controlChanged)
        }
        monitorPicker.target      = self; monitorPicker.action      = #selector(controlChanged)
        portalPicker.target       = self; portalPicker.action       = #selector(controlChanged)
        launchAtLoginCheck.target = self; launchAtLoginCheck.action = #selector(controlChanged)

        // Layout
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment   = .leading
        stack.spacing     = 16
        stack.edgeInsets  = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        stack.addArrangedSubview(row("Portal",            portalPicker))
        stack.addArrangedSubview(row("Monitor",           monitorPicker))
        stack.addArrangedSubview(row("Sensitivity",       sensitivitySlider))
        stack.addArrangedSubview(row("Depth intensity",   depthSlider))
        stack.addArrangedSubview(row("Field of view",     fovSlider))
        stack.addArrangedSubview(launchAtLoginCheck)

        window?.contentView = stack
    }

    private func row(_ label: String, _ control: NSView) -> NSStackView {
        let lbl = NSTextField(labelWithString: label)
        lbl.frame.size.width = 140
        let h = NSStackView(views: [lbl, control])
        h.orientation = .horizontal
        h.spacing = 12
        return h
    }

    // MARK: - Actions

    @objc private func controlChanged() {
        AppSettings.shared.sensitivity    = sensitivitySlider.doubleValue
        AppSettings.shared.depthIntensity = depthSlider.doubleValue
        AppSettings.shared.fieldOfView    = fovSlider.doubleValue
        AppSettings.shared.targetDisplayName = monitorPicker.titleOfSelectedItem

        if let title = portalPicker.titleOfSelectedItem {
            AppSettings.shared.selectedPortal = title
        }

        let login = launchAtLoginCheck.state == .on
        AppSettings.shared.launchAtLogin = login
        LoginItemManager.setEnabled(login)

        onChange?()
    }
}
