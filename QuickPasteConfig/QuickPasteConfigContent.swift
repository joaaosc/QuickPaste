import SwiftUI

struct QuickPasteConfigContent: View {
    @AppStorage("openEditorAtLaunch", store: QuickPasteConfigSettings.defaults)
    private var openEditorAtLaunch = false

    @AppStorage("keepEditorFloating", store: QuickPasteConfigSettings.defaults)
    private var keepEditorFloating = true

    @AppStorage("defaultText", store: QuickPasteConfigSettings.defaults)
    private var defaultText = ""

    var body: some View {
        Form {
            Section("QuickPaste") {
                Toggle("Abrir editor ao iniciar", isOn: $openEditorAtLaunch)
                Toggle("Manter editor acima das outras janelas", isOn: $keepEditorFloating)
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
