import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let frameAutosaveName = "QuickPasteEditorPanel"

    private var statusItem: NSStatusItem?
    private var editorPanel: FloatingPanel?
    private var hasSavedFrame = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        QuickPasteSettings.registerDefaults()

        setupStatusItem()
        setupEditorPanel()

        HotKeyManager.shared.handler = { [weak self] in
            self?.toggleEditorPanel()
        }
        updateHotKeyRegistration()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        // Keep the note above every app, except the Settings window.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        if QuickPasteSettings.openEditorAtLaunch {
            DispatchQueue.main.async { [weak self] in
                self?.showEditorPanel()
            }
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "note.text",
                accessibilityDescription: "QuickPaste"
            )
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        self.statusItem = statusItem
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            toggleEditorPanel()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()

        let toggleTitle = editorPanel?.isVisible == true ? "Ocultar nota" : "Mostrar nota"
        menu.addItem(withTitle: toggleTitle, action: #selector(menuTogglePanel), keyEquivalent: "")
            .target = self

        menu.addItem(.separator())

        let settingsItem = menu.addItem(
            withTitle: "Configurações…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Sair do QuickPaste",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        // Menu temporário: mantém o clique esquerdo como toggle do painel.
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func menuTogglePanel() {
        toggleEditorPanel()
    }

    @objc private func openSettings() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    // MARK: - Window layering

    // The note panel floats above all apps. The Settings window is the only titled,
    // non-panel window this app creates, so when it takes focus we drop the panel to
    // the normal level (letting Settings sit above it) and restore floating afterwards.

    private func isSettingsWindow(_ window: NSWindow) -> Bool {
        window !== editorPanel
            && !(window is NSPanel)
            && window.styleMask.contains(.titled)
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if window === editorPanel {
            editorPanel?.level = .floating
        } else if isSettingsWindow(window) {
            editorPanel?.level = .normal
        }
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, isSettingsWindow(window) else { return }
        editorPanel?.level = .floating
    }

    // MARK: - Editor panel

    private func setupEditorPanel() {
        let hostingController = NSHostingController(rootView: EditorView())

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .fullSizeContentView,
                .nonactivatingPanel,
            ],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.title = "QuickPaste"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.minSize = NSSize(width: 360, height: 280)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        hasSavedFrame = panel.setFrameUsingName(Self.frameAutosaveName)
        panel.setFrameAutosaveName(Self.frameAutosaveName)

        self.editorPanel = panel
    }

    private func toggleEditorPanel() {
        guard let editorPanel else { return }

        if editorPanel.isVisible {
            editorPanel.orderOut(nil)
        } else {
            showEditorPanel()
        }
    }

    private func showEditorPanel() {
        guard let editorPanel else { return }

        if !hasSavedFrame {
            positionPanelBelowStatusItem(editorPanel)
            hasSavedFrame = true
        }

        editorPanel.makeKeyAndOrderFront(nil)
    }

    private func positionPanelBelowStatusItem(_ panel: NSPanel) {
        guard
            let button = statusItem?.button,
            let buttonWindow = button.window
        else { return }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)
        let panelSize = panel.frame.size

        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY - panelSize.height - 8

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Hotkey

    @objc private func defaultsDidChange() {
        updateHotKeyRegistration()
    }

    private func updateHotKeyRegistration() {
        if QuickPasteSettings.globalHotKeyEnabled {
            HotKeyManager.shared.register()
        } else {
            HotKeyManager.shared.unregister()
        }
    }
}
