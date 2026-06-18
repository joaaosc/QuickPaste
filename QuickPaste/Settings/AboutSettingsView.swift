import AppKit
import SwiftUI

struct AboutSettingsView: View {
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("QuickPaste")
                            .font(.title2.bold())
                        Text("Bloco de rascunho na barra de menus")
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Versão", value: versionText)
            }

            Section {
                Text("Nota rápida sempre à mão, com tradução on-device e colagem de imagens no corpo do texto. Tudo local e privado.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}

#Preview {
    AboutSettingsView()
}
