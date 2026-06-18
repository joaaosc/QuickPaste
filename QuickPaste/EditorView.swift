import SwiftUI
import Translation

struct EditorView: View {
    @AppStorage(QuickPasteSettings.Key.editorFontSize)
    private var fontSize = 14.0

    @AppStorage(QuickPasteSettings.Key.targetLanguage)
    private var targetLanguageRaw = TranslationLanguage.english.rawValue

    @State private var text: String = QuickPasteSettings.noteText
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var translatedText: String?
    @State private var translationError: String?
    @State private var isTranslating = false
    @State private var didCopy = false

    @FocusState private var editorFocused: Bool

    private var targetLanguage: TranslationLanguage {
        TranslationLanguage(rawValue: targetLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            editor

            if isTranslating || translatedText != nil || translationError != nil {
                translationCard
            }

            Divider()

            bottomBar
        }
        .background(VisualEffectBackground().ignoresSafeArea())
        .translationTask(translationConfig) { session in
            do {
                let response = try await session.translate(text)
                translatedText = response.targetText
                translationError = nil
            } catch {
                translatedText = nil
                translationError = error.localizedDescription
            }
            isTranslating = false
        }
        .onChange(of: text) { _, newValue in
            QuickPasteSettings.noteText = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if notification.object is FloatingPanel {
                editorFocused = true
            }
        }
    }

    // MARK: - Editor

    private var editor: some View {
        TextEditor(text: $text)
            .font(.system(size: fontSize))
            .scrollContentBackground(.hidden)
            .focused($editorFocused)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Escreva algo…")
                        .font(.system(size: fontSize))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - Tradução

    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Tradução · \(targetLanguage.displayName)", systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isTranslating {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    dismissTranslation()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Fechar tradução")
            }

            if let translationError {
                Text(translationError)
                    .font(.callout)
                    .foregroundStyle(.red)
            } else if let translatedText {
                ScrollView {
                    Text(translatedText)
                        .font(.system(size: fontSize))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)

                HStack(spacing: 8) {
                    Button("Copiar tradução") {
                        copyToPasteboard(translatedText)
                    }

                    Button("Substituir nota") {
                        text = translatedText
                        dismissTranslation()
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.4))
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Barra inferior

    private var bottomBar: some View {
        HStack(spacing: 14) {
            Text(statsText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            Picker("Idioma de destino", selection: $targetLanguageRaw) {
                ForEach(TranslationLanguage.allCases) { language in
                    Text(language.displayName).tag(language.rawValue)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 130)
            .help("Idioma de destino da tradução")

            Button {
                translate()
            } label: {
                Image(systemName: "globe")
            }
            .buttonStyle(.borderless)
            .disabled(text.isEmpty || isTranslating)
            .help("Traduzir nota")

            Button {
                copyToPasteboard(text)
                withAnimation { didCopy = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    withAnimation { didCopy = false }
                }
            } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(didCopy ? .green : .primary)
            }
            .buttonStyle(.borderless)
            .disabled(text.isEmpty)
            .help("Copiar nota inteira")

            Button {
                text = ""
                dismissTranslation()
                editorFocused = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(text.isEmpty)
            .help("Limpar nota")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statsText: String {
        let words = text.split(whereSeparator: \.isWhitespace).count
        return "\(words) palavras · \(text.count) caracteres"
    }

    // MARK: - Ações

    private func translate() {
        guard !text.isEmpty else { return }

        translationError = nil
        isTranslating = true

        if var config = translationConfig {
            config.target = targetLanguage.locale
            config.invalidate()
            translationConfig = config
        } else {
            translationConfig = TranslationSession.Configuration(
                source: nil,
                target: targetLanguage.locale
            )
        }
    }

    private func dismissTranslation() {
        translatedText = nil
        translationError = nil
        isTranslating = false
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

#Preview {
    EditorView()
        .frame(width: 480, height: 400)
}
