import ServiceManagement
import SwiftUI

struct SettingsContent: View {
    @AppStorage(QuickPasteSettings.Key.openEditorAtLaunch)
    private var openEditorAtLaunch = false

    @AppStorage(QuickPasteSettings.Key.globalHotKeyEnabled)
    private var globalHotKeyEnabled = true

    @AppStorage(QuickPasteSettings.Key.editorFontSize)
    private var fontSize = 14.0

    @AppStorage(QuickPasteSettings.Key.targetLanguage)
    private var targetLanguageRaw = TranslationLanguage.english.rawValue

    @State private var startAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Geral") {
                Toggle("Abrir nota ao iniciar o app", isOn: $openEditorAtLaunch)

                Toggle("Iniciar no login", isOn: $startAtLogin)
                    .onChange(of: startAtLogin) { _, enabled in
                        updateLoginItem(enabled: enabled)
                    }

                Toggle("Atalho global (⌃⌥Espaço)", isOn: $globalHotKeyEnabled)
            }

            Section("Editor") {
                HStack(spacing: 12) {
                    Text("Tamanho da fonte")

                    Slider(value: $fontSize, in: 10...28, step: 1)

                    Text("\(Int(fontSize))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }

            Section("Tradução") {
                Picker("Idioma de destino", selection: $targetLanguageRaw) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
    }

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            startAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

#Preview {
    SettingsContent()
}
