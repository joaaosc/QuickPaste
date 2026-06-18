import SwiftUI

struct DisplaysSettingsView: View {
    @AppStorage(QuickPasteSettings.Key.editorFontSize)
    private var fontSize = 14.0

    var body: some View {
        Form {
            Section("Editor") {
                LabeledContent("Tamanho da fonte") {
                    HStack(spacing: 10) {
                        Slider(value: $fontSize, in: 10...28, step: 1)
                            .frame(width: 180)
                        Text("\(Int(fontSize))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }

            Section("Janela da nota") {
                LabeledContent("Comportamento", value: "Flutua acima de todos os apps")
                Text("A janela de configurações sempre aparece acima da nota.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}

#Preview {
    DisplaysSettingsView()
}
