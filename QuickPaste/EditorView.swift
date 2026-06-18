import SwiftUI
import Translation

struct EditorView: View {
    @AppStorage(QuickPasteSettings.Key.editorFontSize)
    private var fontSize = 14.0

    @AppStorage(QuickPasteSettings.Key.targetLanguage)
    private var targetLanguageRaw = TranslationLanguage.english.rawValue

    @State private var model: EditorModel
    @State private var didCopy = false

    @FocusState private var editorFocused: Bool

    init() {
        _model = State(initialValue: EditorModel())
    }

    init(model: EditorModel) {
        _model = State(initialValue: model)
    }

    private var targetLanguage: TranslationLanguage {
        TranslationLanguage(rawValue: targetLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            editor

            if model.translation.isActive {
                translationCard
            }

            Divider()

            bottomBar
        }
        .background(VisualEffectBackground().ignoresSafeArea())
        .translationTask(model.translationConfiguration) { session in
            do {
                let response = try await session.translate(model.pendingSourceText)
                model.finishTranslation(response.targetText)
            } catch {
                model.failTranslation(error.localizedDescription)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if notification.object is FloatingPanel {
                editorFocused = true
            }
        }
        .onDisappear { model.persistNow() }
    }

    // MARK: - Editor

    private var editor: some View {
        @Bindable var model = model

        return TextEditor(text: $model.text)
            .font(.system(size: fontSize))
            .scrollContentBackground(.hidden)
            .focused($editorFocused)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .accessibilityLabel("Nota")
            .onChange(of: model.text) { model.handleTextChanged() }
            .overlay(alignment: .topLeading) {
                if model.isEmpty {
                    Text("Escreva algo…")
                        .font(.system(size: fontSize))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
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

                if model.translation.isInProgress {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    model.dismissTranslation()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Fechar tradução")
                .accessibilityLabel("Fechar tradução")
            }

            if let message = model.translation.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
            } else if let result = model.translation.result {
                ScrollView {
                    Text(result)
                        .font(.system(size: fontSize))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)

                HStack(spacing: 8) {
                    Button("Copiar tradução") {
                        model.copyTranslation()
                    }

                    Button("Substituir nota") {
                        model.adoptTranslation()
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
        HStack(spacing: 12) {
            Text(statsText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if let detected = model.detectedLanguage {
                Label(detected.displayName, systemImage: "character.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Idioma detectado on-device")
                    .accessibilityLabel("Idioma detectado: \(detected.displayName)")
            }

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
                model.requestTranslation(to: targetLanguage)
            } label: {
                Image(systemName: "globe")
            }
            .buttonStyle(.borderless)
            .disabled(model.isEmpty || model.translation.isInProgress)
            .help("Traduzir nota")
            .accessibilityLabel("Traduzir nota")

            Button {
                model.copyNote()
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
            .disabled(model.isEmpty)
            .help("Copiar nota inteira")
            .accessibilityLabel(didCopy ? "Copiado" : "Copiar nota")

            Button {
                model.clear()
                editorFocused = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(model.isEmpty)
            .help("Limpar nota")
            .accessibilityLabel("Limpar nota")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statsText: String {
        "\(model.wordCount) palavras · \(model.characterCount) caracteres"
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

#Preview("Vazia") {
    EditorView(model: EditorModel(persistence: InMemoryNotePersistence()))
        .frame(width: 480, height: 400)
}

#Preview("Com texto · escuro") {
    EditorView(model: EditorModel(persistence: InMemoryNotePersistence(note: "Olá, mundo!\nEsta é uma nota de exemplo.")))
        .frame(width: 480, height: 400)
        .preferredColorScheme(.dark)
}
