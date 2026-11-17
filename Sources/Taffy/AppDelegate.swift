import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var panelController: SearchPanelController!
    private var hotKey: HotKey?
    private var hotKeyDisplay = ""
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login",
                                               action: #selector(toggleLaunchAtLogin(_:)),
                                               keyEquivalent: "")

    private let mediaIndicatorsItem = NSMenuItem(title: "Audio & Camera Indicators…",
                                                 action: #selector(configureMediaIndicators(_:)),
                                                 keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = SearchPanelController()
        registerHotKey()
        setUpStatusItem()
    }

    private func registerHotKey() {
        let configured = UserDefaults.standard.string(forKey: "hotkey")
        var spec = configured.flatMap(HotKeySpec.parse)
        if configured != nil && spec == nil {
            NSLog("Taffy: invalid hotkey %@, falling back to %@", configured!, HotKeySpec.defaultString)
        }
        if spec == nil { spec = HotKeySpec.parse(HotKeySpec.defaultString) }
        guard let spec else { return }

        let controller = panelController!
        hotKey = HotKey(spec: spec) {
            Task { @MainActor in controller.toggle() }
        }
        if hotKey == nil {
            NSLog("Taffy: could not register hotkey %@ (already in use?)", spec.display)
            hotKeyDisplay = ""
        } else {
            hotKeyDisplay = spec.display
        }
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.stack",
                                   accessibilityDescription: "Taffy")
            button.image?.isTemplate = true
            button.toolTip = "Taffy"
        }

        let menu = NSMenu()
        menu.delegate = self

        let searchTitle = hotKeyDisplay.isEmpty ? "Search Tabs" : "Search Tabs  (\(hotKeyDisplay))"
        let searchItem = NSMenuItem(title: searchTitle, action: #selector(showSearch(_:)), keyEquivalent: "")
        searchItem.target = self
        menu.addItem(searchItem)
        menu.addItem(.separator())

        mediaIndicatorsItem.target = self
        menu.addItem(mediaIndicatorsItem)
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())

        let versionItem = NSMenuItem(title: "Taffy \(TaffyVersion.current)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quitItem = NSMenuItem(title: "Quit Taffy", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        mediaIndicatorsItem.state = MediaScanner.isTrusted ? .on : .off
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func showSearch(_ sender: Any?) {
        panelController.show()
    }

    /// Asks for the Accessibility permission, or opens its settings pane when
    /// it is already granted (so it can be turned off there).
    @objc private func configureMediaIndicators(_ sender: NSMenuItem) {
        if MediaScanner.isTrusted {
            MediaScanner.openAccessibilitySettings()
        } else {
            MediaScanner.requestAccess()
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change the login item"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
