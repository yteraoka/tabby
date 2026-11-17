import AppKit
import SwiftUI

/// A borderless-looking floating panel that can take keyboard focus.
final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class SearchPanelController: NSObject, NSWindowDelegate {
    let model = SearchModel()
    private var panel: SearchPanel!
    private var keyMonitor: Any?

    override init() {
        super.init()
        let panel = SearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 460),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: SearchView(model: model))
        self.panel = panel

        model.onDismiss = { [weak self] restoreFocus in
            self?.hide(restoreFocus: restoreFocus)
        }
    }

    /// `mode`: the hot key for a specific mode (nil: the main hot key, which
    /// opens the panel in the last used mode). Pressing a mode's hot key while
    /// the panel shows the other mode switches to it instead of closing.
    func toggle(mode: AppCategory? = nil) {
        if panel.isVisible {
            if let mode, mode != model.mode {
                model.mode = mode
            } else {
                hide(restoreFocus: true)
            }
        } else {
            show(mode: mode)
        }
    }

    func show(mode: AppCategory? = nil) {
        model.prepareForShow(mode: mode)
        position()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        model.reload()
    }

    func hide(restoreFocus: Bool) {
        guard panel.isVisible else { return }
        removeKeyMonitor()
        panel.orderOut(nil)
        if restoreFocus {
            // Hand focus back to whatever app was active before the panel opened.
            NSApp.hide(nil)
        }
    }

    /// Places the panel horizontally centered, slightly above the middle of the
    /// screen that contains the mouse pointer.
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = min(visible.minY + visible.height * 0.62 - size.height / 2, visible.maxY - size.height)
        panel.setFrameOrigin(NSPoint(x: x, y: max(y, visible.minY)))
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        // Leave keys alone while an input method (e.g. Japanese) is composing.
        if let editor = panel.firstResponder as? NSTextView, editor.hasMarkedText() {
            return false
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let control = flags.contains(.control)

        switch event.keyCode {
        case 53: // esc
            hide(restoreFocus: true)
            return true
        case 48 where !command: // tab, shift-tab
            model.toggleMode()
            return true
        case 18 where command: // ⌘1
            model.mode = .browser
            return true
        case 19 where command: // ⌘2
            model.mode = .terminal
            return true
        case 36, 76: // return, keypad enter
            model.activateSelected()
            return true
        case 125: // down
            if command { model.moveToEdge(top: false) } else { model.move(1) }
            return true
        case 126: // up
            if command { model.moveToEdge(top: true) } else { model.move(-1) }
            return true
        case 121: // page down
            model.move(8)
            return true
        case 116: // page up
            model.move(-8)
            return true
        case 46 where command: // ⌘M
            model.toggleMediaFilter()
            return true
        case 51 where command: // ⌘⌫
            model.closeSelected()
            return true
        default:
            break
        }

        if control, let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "n", "j":
                model.move(1)
                return true
            case "p", "k":
                model.move(-1)
                return true
            default:
                break
            }
        }
        return false
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide(restoreFocus: false)
    }
}
