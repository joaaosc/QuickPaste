import Testing
@testable import QuickPaste

// EditorModel is @MainActor, so the suite is too. Tests drive the state machine
// directly and inject fakes — no UserDefaults, no pasteboard, no real translation.
@MainActor
struct EditorModelTests {

    // MARK: Fakes

    final class FakePasteboard: PasteboardWriting {
        var written: [String] = []
        func write(_ string: String) { written.append(string) }
    }

    struct FixedDetector: LanguageDetecting {
        var language: TranslationLanguage?
        func detect(in text: String) -> TranslationLanguage? { language }
    }

    private func makeModel(
        note: String = "",
        detector: LanguageDetecting = FixedDetector(language: nil)
    ) -> (model: EditorModel, store: InMemoryNotePersistence, pasteboard: FakePasteboard) {
        let store = InMemoryNotePersistence(note: note)
        let pasteboard = FakePasteboard()
        let model = EditorModel(persistence: store, pasteboard: pasteboard, detector: detector)
        return (model, store, pasteboard)
    }

    // MARK: State

    @Test("Restores the persisted note on init")
    func restoresPersistedNote() {
        let (model, _, _) = makeModel(note: "rascunho")
        #expect(model.text == "rascunho")
    }

    @Test("persistNow flushes the current text to the store")
    func persistNowWrites() {
        let (model, store, _) = makeModel()
        model.text = "olá"
        model.persistNow()
        #expect(store.note == "olá")
    }

    @Test("Word and character counts reflect the text")
    func counts() {
        let (model, _, _) = makeModel(note: "uma duas três")
        #expect(model.wordCount == 3)
        #expect(model.characterCount == 13)
    }

    @Test("Detected language from the injected detector is exposed at init")
    func detectedLanguageAtInit() {
        let (model, _, _) = makeModel(note: "qualquer", detector: FixedDetector(language: .french))
        #expect(model.detectedLanguage == .french)
    }

    // MARK: Translation state machine

    @Test("requestTranslation enters in-progress and builds a configuration")
    func requestTranslationStarts() {
        let (model, _, _) = makeModel(note: "hello")
        model.requestTranslation(to: .portuguese)
        #expect(model.translation == .inProgress)
        #expect(model.translationConfiguration != nil)
        #expect(model.pendingSourceText == "hello")
    }

    @Test("requestTranslation is a no-op on empty text")
    func requestTranslationEmpty() {
        let (model, _, _) = makeModel(note: "")
        model.requestTranslation(to: .english)
        #expect(model.translation == .idle)
        #expect(model.translationConfiguration == nil)
    }

    @Test("finishTranslation trims output; empty output becomes a failure")
    func finishTranslationTrimsAndValidates() {
        let (model, _, _) = makeModel(note: "hi")
        model.requestTranslation(to: .portuguese)

        model.finishTranslation("  Olá  ")
        #expect(model.translation == .completed("Olá"))

        model.finishTranslation("   ")
        #expect(model.translation == .failed("Tradução vazia."))
    }

    @Test("failTranslation surfaces the error message")
    func failTranslationSurfacesMessage() {
        let (model, _, _) = makeModel(note: "hi")
        model.failTranslation("sem rede")
        #expect(model.translation.errorMessage == "sem rede")
    }

    @Test("adoptTranslation replaces the note and clears translation state")
    func adoptTranslationReplacesNote() {
        let (model, _, _) = makeModel(note: "hello")
        model.requestTranslation(to: .portuguese)
        model.finishTranslation("Olá")
        model.adoptTranslation()
        #expect(model.text == "Olá")
        #expect(model.translation == .idle)
        #expect(model.translationConfiguration == nil)
    }

    // MARK: Side effects

    @Test("copyNote and copyTranslation write to the pasteboard")
    func copyingWritesToPasteboard() {
        let (model, _, pasteboard) = makeModel(note: "hello")
        model.copyNote()
        model.requestTranslation(to: .portuguese)
        model.finishTranslation("Olá")
        model.copyTranslation()
        #expect(pasteboard.written == ["hello", "Olá"])
    }

    @Test("clear empties the note and dismisses any translation")
    func clearResetsState() {
        let (model, _, _) = makeModel(note: "hello")
        model.requestTranslation(to: .portuguese)
        model.clear()
        #expect(model.text.isEmpty)
        #expect(model.translation == .idle)
    }
}
