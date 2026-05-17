#if QUICKPASTE_CONFIG
import SwiftUI
import AppKit

@main
struct QuickPasteConfigApp: App {
    var body: some Scene {
        WindowGroup("QuickPaste Configurações") {
            QuickPasteConfigView()
                .frame(minWidth: 420, minHeight: 320)
        }
        .defaultPosition(.center)
        .defaultSize(width: 520, height: 380)
    }
}

struct QuickPasteConfigView: View {
    @State private var optionA: String = "Padrão"
    @State private var optionB: String = "Médio"
    @State private var radioSelection: Int = 0

    private let optionsA = ["Padrão", "Rápido", "Seguro"]
    private let optionsB = ["Baixo", "Médio", "Alto"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configurações do QuickPaste")
                .font(.title2)
                .bold()

            Form {
                Picker("Modo", selection: $optionA) {
                    ForEach(optionsA, id: \.self) { Text($0) }
                }
                Picker("Qualidade", selection: $optionB) {
                    ForEach(optionsB, id: \.self) { Text($0) }
                }
                Picker("Preferência", selection: $radioSelection) {
                    Text("Opção 1").tag(0)
                    Text("Opção 2").tag(1)
                    Text("Opção 3").tag(2)
                }
                .pickerStyle(.radioGroup)
            }

            HStack(spacing: 12) {
                Button("Sobre") { openAbout() }
                Button("Doar") { openDonate() }
            }

            Spacer()
        }
        .padding(20)
    }

    private func openAbout() {
        if let url = URL(string: "https://example.com/about") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openDonate() {
        if let url = URL(string: "https://example.com/donate") {
            NSWorkspace.shared.open(url)
        }
    }
}
#endif
