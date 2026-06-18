import AppKit
import Carbon.HIToolbox

// Atalho global via Carbon (RegisterEventHotKey): funciona em apps
// sandboxed e não exige permissão de acessibilidade.
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    var handler: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    var isRegistered: Bool { hotKeyRef != nil }

    func register() {
        guard hotKeyRef == nil else { return }

        if eventHandlerRef == nil {
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

        let hotKeyID = EventHotKeyID(signature: OSType(0x5150_4B59), id: 1)

        // ⌃⌥Espaço
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }
}
