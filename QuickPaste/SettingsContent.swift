import SwiftUI

struct SettingsContent: View {
    @AppStorage("openEditorAtLaunch", store: QuickPasteSettings.defaults)
    private var openEditorAtLaunch = false

    @AppStorage("keepEditorFloating", store: QuickPasteSettings.defaults)
    private var keepEditorFloating = true

    @AppStorage("defaultText", store: QuickPasteSettings.defaults)
    private var defaultText = ""

    var body: some View {
        Form {
            Section("Editor") {
                Toggle("Abrir editor ao iniciar", isOn: $openEditorAtLaunch)
                Toggle("Manter janela acima das outras", isOn: $keepEditorFloating)
            }

            Section("Conteúdo") {
                TextField("Texto padrão", text: $defaultText, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}
