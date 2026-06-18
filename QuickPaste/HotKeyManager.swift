import AppKit
import Carbon.HIToolbox

// Atalhos globais via Carbon (RegisterEventHotKey): funcionam em apps sandboxed e
// não exigem permissão de acessibilidade. Registra o atalho fixo (⌃⌥Espaço) e/ou o
// atalho personalizado do usuário, conforme as preferências.
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    var handler: (() -> Void)?

    private var defaultRef: EventHotKeyRef?
    private var customRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    /// Re-register hotkeys from the current settings.
    func reload() {
        installEventHandlerIfNeeded()
        unregisterAll()

        if QuickPasteSettings.globalHotKeyEnabled {
            defaultRef = registerHotKey(
                keyCode: UInt32(kVK_Space),
                carbonModifiers: UInt32(controlKey | optionKey),
                id: 1
            )
        }

        if let custom = QuickPasteSettings.customHotKey {
            customRef = registerHotKey(
                keyCode: custom.keyCode,
                carbonModifiers: custom.carbonModifiers,
                id: 2
            )
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                Task { @MainActor in
                    HotKeyManager.shared.handler?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    private func registerHotKey(keyCode: UInt32, carbonModifiers: UInt32, id: UInt32) -> EventHotKeyRef? {
        let hotKeyID = EventHotKeyID(signature: OSType(0x5150_4B59), id: id)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        return ref
    }

    private func unregisterAll() {
        if let defaultRef {
            UnregisterEventHotKey(defaultRef)
            self.defaultRef = nil
        }
        if let customRef {
            UnregisterEventHotKey(customRef)
            self.customRef = nil
        }
    }
}
