import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var editorPanel: NSPanel?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupEditorPanel()
        setupSettingsWindow()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeSpaceDidChange(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        // Optionally open editor at launch can be wired to settings later
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "text.cursor",
                accessibilityDescription: "QuickPaste"
            )

            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        self.statusItem = statusItem
    }

    private func setupEditorPanel() {
        let contentView = MenuBarContent()
        let hostingController = NSHostingController(rootView: contentView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [
                .titled,
                .resizable,
                .closable
            ],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = keepEditorFloating ? .floating : .normal
        panel.minSize = NSSize(width: 320, height: 200)

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]

        panel.title = "QuickPaste"

        self.editorPanel = panel
    }

    private func setupSettingsWindow() {
        let contentView = SettingsContent()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 360, height: 260)
        window.title = "Configurações"
        window.setFrameAutosaveName("SettingsWindow")
        window.center()
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating

        self.settingsWindow = window
    }

    @objc private func statusItemClicked() {
        toggleEditorPanel()
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
        guard
            let editorPanel,
            let button = statusItem?.button,
            let buttonWindow = button.window
        else {
            return
        }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)

        let panelSize = editorPanel.frame.size

        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY - panelSize.height - 8

        editorPanel.setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate(ignoringOtherApps: true)
        editorPanel.makeKeyAndOrderFront(nil)
    }

    private func showSettingsWindow() {
        guard let settingsWindow else { return }

        editorPanel?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.deminiaturize(nil)
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    private var keepEditorFloating: Bool {
        // Default to true while settings are not available here
        return true
    }

    private func openSettingsApp() {
        let settingsAppURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("QuickPasteConfig.app")

        guard FileManager.default.fileExists(atPath: settingsAppURL.path) else {
            showSettingsWindow()
            return
        }

        NSWorkspace.shared.openApplication(
            at: settingsAppURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { [weak self] _, error in
            guard error != nil else { return }

            DispatchQueue.main.async {
                self?.showSettingsWindow()
            }
        }
    }

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        if let settingsWindow, settingsWindow.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
        }
        if let editorPanel, editorPanel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            editorPanel.makeKeyAndOrderFront(nil)
        }
    }
}
