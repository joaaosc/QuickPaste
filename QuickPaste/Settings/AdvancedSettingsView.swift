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
            } header: {
                Text("OCR em imagens")
            } footer: {
                Text("Reconhece texto em imagens coladas (Vision, on-device) e pelo clique direito na imagem. A conversão de fórmulas para LaTeX virá depois.")
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
