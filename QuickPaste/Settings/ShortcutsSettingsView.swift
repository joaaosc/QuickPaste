import SwiftUI

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Globais") {
                LabeledContent("Mostrar/ocultar a nota", value: "⌃⌥Espaço")
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
