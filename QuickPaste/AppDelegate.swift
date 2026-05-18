import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var editorPanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        setupStatusItem()
        setupEditorPanel()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeSpaceDidChange(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        if QuickPasteSettings.defaults.bool(forKey: "openEditorAtLaunch") {
            DispatchQueue.main.async { [weak self] in
                self?.showEditorPanel()
            }
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
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
        panel.minSize = NSSize(width: 520, height: 360)

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]

        panel.title = "QuickPaste"

        self.editorPanel = panel
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

        editorPanel.level = keepEditorFloating ? .floating : .normal

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)

        let panelSize = editorPanel.frame.size

        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY - panelSize.height - 8

        editorPanel.setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate(ignoringOtherApps: true)
        editorPanel.makeKeyAndOrderFront(nil)
    }

    private var keepEditorFloating: Bool {
        QuickPasteSettings.defaults.object(forKey: "keepEditorFloating") as? Bool ?? true
    }

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        _ = notification
        if let editorPanel, editorPanel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            editorPanel.makeKeyAndOrderFront(nil)
        }
    }
}
