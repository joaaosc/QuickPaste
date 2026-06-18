import SwiftUI

struct ShortcutsSettingsView: View {
    @AppStorage(QuickPasteSettings.Key.customHotKeyKeyCode)
    private var customKeyCode = -1

    @AppStorage(QuickPasteSettings.Key.customHotKeyModifiers)
    private var customModifiers = 0

    @AppStorage(QuickPasteSettings.Key.customHotKeyDisplay)
    private var customDisplay = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Mostrar/ocultar a nota") {
                    HStack(spacing: 8) {
                        ShortcutRecorder(
                            keyCode: $customKeyCode,
                            carbonModifiers: $customModifiers,
                            display: $customDisplay
                        )
                        .frame(width: 150, height: 24)

                        if !customDisplay.isEmpty {
                            Button("Limpar") {
                                customKeyCode = -1
                                customModifiers = 0
                                customDisplay = ""
                            }
                            .controlSize(.small)
                        }
                    }
                }
            } header: {
                Text("Atalho personalizado")
            } footer: {
                Text("Vazio por padrão. Clique para gravar (precisa de um modificador). Funciona junto do atalho fixo ⌃⌥Espaço.")
                    .foregroundStyle(.secondary)
            }

            Section("No editor") {
                LabeledContent("Colar texto ou imagem", value: "⌘V")
                LabeledContent("Copiar / Recortar / Selecionar tudo", value: "⌘C / ⌘X / ⌘A")
                LabeledContent("Desfazer / Refazer", value: "⌘Z / ⇧⌘Z")
                LabeledContent("Ocultar a nota", value: "⌘W · Esc")
            }

            Section("App") {
                LabeledContent("Configurações", value: "⌘,")
                LabeledContent("Sair", value: "⌘Q")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}

#Preview {
    ShortcutsSettingsView()
}
