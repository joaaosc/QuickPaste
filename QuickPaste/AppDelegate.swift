import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var editorPanel: NSPanel?
    private var settingsPopover: NSPopover?
    private var contextMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupEditorPanel()
        setupSettingsPopover()
        setupContextMenu()
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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [
                .titled,
                .resizable,
                .closable,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.minSize = NSSize(width: 240, height: 140)

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]

        panel.title = "QuickPaste"

        self.editorPanel = panel
    }

    private func setupSettingsPopover() {
        let contentView = SettingsContent()
        let hostingController = NSHostingController(rootView: contentView)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 220)
        popover.contentViewController = hostingController

        self.settingsPopover = popover
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            toggleEditorPanel()
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isRightClick = (event.type == .rightMouseUp) || flags.contains(.control)

        if isRightClick {
            showContextMenu()
        } else if flags.contains(.command) || flags.contains(.option) {
            showSettingsPanel()
        } else {
            toggleEditorPanel()
        }
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
        editorPanel.orderFrontRegardless()
    }

    private func showSettingsPanel() {
        guard
            let popover = settingsPopover,
            let button = statusItem?.button
        else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func setupContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Configurações…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Sair", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.contextMenu = menu
    }

    private func showContextMenu() {
        guard let menu = contextMenu, let statusItem = statusItem else { return }
        statusItem.popUpMenu(menu)
    }

    @objc private func openSettingsFromMenu() {
        showSettingsPanel()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
