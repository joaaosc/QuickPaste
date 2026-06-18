import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A small control that records a global keyboard shortcut. SwiftUI can't capture raw
/// key combos with modifiers, so this wraps an AppKit view. It reports the Carbon key
/// code + modifiers (for `RegisterEventHotKey`) and a display string.
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var carbonModifiers: Int
    @Binding var display: String

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.displayString = display
        view.onCapture = context.coordinator.capture
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        context.coordinator.parent = self
        nsView.displayString = display
        nsView.onCapture = context.coordinator.capture
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator {
        var parent: ShortcutRecorder
        init(_ parent: ShortcutRecorder) { self.parent = parent }

        func capture(_ keyCode: Int, _ modifiers: Int, _ display: String) {
            parent.keyCode = keyCode
            parent.carbonModifiers = modifiers
            parent.display = display
        }
    }
}

final class ShortcutRecorderView: NSView {
    var onCapture: ((Int, Int, String) -> Void)?
    var displayString: String = "" { didSet { refresh() } }

    private var recording = false { didSet { refresh() } }
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        label.alignment = .center
        label.font = .systemFont(ofSize: 12)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize { NSSize(width: 150, height: 24) }
    override var acceptsFirstResponder: Bool { true }

    private var currentText: String {
        if recording { return "Pressione o atalho…" }
        return displayString.isEmpty ? "Clique para gravar" : displayString
    }

    private func refresh() {
        label.stringValue = currentText
        label.textColor = (recording || displayString.isEmpty) ? .secondaryLabelColor : .labelColor
        layer?.borderColor = (recording ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        recording = true
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        if !handle(event) { super.keyDown(with: event) }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording, handle(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    private func endRecording() {
        recording = false
        window?.makeFirstResponder(nil)
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard recording else { return false }
        let key = Int(event.keyCode)

        if key == kVK_Escape {                                   // cancel, keep current
            endRecording()
            return true
        }
        if key == kVK_Delete || key == kVK_ForwardDelete {       // clear
            onCapture?(-1, 0, "")
            displayString = ""
            endRecording()
            return true
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let carbon = carbonFlags(from: flags)
        guard carbon != 0 else { return false }                  // require a modifier

        let text = displayText(flags: flags, event: event)
        onCapture?(key, Int(carbon), text)
        displayString = text
        endRecording()
        return true
    }

    private func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    private func displayText(flags: NSEvent.ModifierFlags, event: NSEvent) -> String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        text += keyName(for: Int(event.keyCode), characters: event.charactersIgnoringModifiers)
        return text
    }

    private func keyName(for keyCode: Int, characters: String?) -> String {
        let specials: [Int: String] = [
            kVK_Space: "Espaço",
            kVK_Return: "↩",
            kVK_Tab: "⇥",
            kVK_LeftArrow: "←",
            kVK_RightArrow: "→",
            kVK_UpArrow: "↑",
            kVK_DownArrow: "↓",
        ]
        if let name = specials[keyCode] { return name }
        if let characters, !characters.isEmpty, characters != " " { return characters.uppercased() }
        return "Tecla \(keyCode)"
    }
}
