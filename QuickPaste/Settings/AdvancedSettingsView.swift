import SwiftUI

struct AdvancedSettingsView: View {
    @AppStorage(QuickPasteSettings.Key.translationEnabled)
    private var translationEnabled = true

    @AppStorage(QuickPasteSettings.Key.targetLanguage)
    private var targetLanguageRaw = TranslationLanguage.english.rawValue

    @AppStorage(QuickPasteSettings.Key.allowMultipleImages)
    private var allowMultipleImages = false

    @AppStorage(QuickPasteSettings.Key.ocrEnabled)
    private var ocrEnabled = false

    @AppStorage(QuickPasteSettings.Key.latexOutputDestination)
    private var latexOutputDestinationRaw = LatexOutputDestination.insertIntoNote.rawValue

    var body: some View {
        Form {
            Section("Tradução") {
                Toggle("Habilitar tradução", isOn: $translationEnabled)

                Picker("Idioma de destino", selection: $targetLanguageRaw) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .disabled(!translationEnabled)
            }

            Section("Imagens") {
                Toggle("Permitir colar mais de uma imagem", isOn: $allowMultipleImages)
            }

            Section {
                Toggle("Reconhecer texto em imagens (OCR)", isOn: $ocrEnabled)

                Picker("Saída do LaTeX", selection: $latexOutputDestinationRaw) {
                    ForEach(LatexOutputDestination.allCases) { destination in
                        Text(destination.displayName).tag(destination.rawValue)
                    }
                }
                .disabled(!ocrEnabled)
            } header: {
                Text("OCR e fórmulas em imagens")
            } footer: {
                Text("Reconhece texto (Vision, on-device) e converte fórmulas para LaTeX pelo clique direito na imagem. A conversão de fórmulas requer macOS 27 (Core AI) e o modelo LatexOCR instalado localmente.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}

#Preview {
    AdvancedSettingsView()
}
