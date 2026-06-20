import Testing
@testable import QuickPaste

@MainActor
struct OCRPipelineTests {
    private func makeModel(
        note: String = "",
        classifier: any ImageTextClassifying,
        preprocessor: any ImagePreprocessing,
        recognizer: any TextRecognizing,
        formulaConverter: (any FormulaConverting)? = nil,
        detector: any LanguageDetecting = OCRFixedLanguageDetector(language: nil),
        enabled: Bool = true
    ) -> EditorModel {
        EditorModel(
            persistence: InMemoryNotePersistence(note: note),
            detector: detector,
            classifier: classifier,
            imagePreprocessor: preprocessor,
            recognizer: recognizer,
            formulaConverter: formulaConverter,
            ocrEnabled: enabled
        )
    }

    @Test("noText skips preprocessing and recognition")
    func noTextSkipsPipeline() async {
        let classifier = FakeImageTextClassifier(.noText)
        let preprocessor = FakeImagePreprocessor()
        let recognizer = FakeTextRecognizer(text: "unused")
        let model = makeModel(
            note: "nota",
            classifier: classifier,
            preprocessor: preprocessor,
            recognizer: recognizer
        )

        model.enqueuePastedImage(OCRFixtures.image())
        await model.waitForOCR()

        #expect(model.plainText == "nota")
        #expect(await classifier.callCount == 1)
        #expect(await preprocessor.callCount == 0)
        #expect(await recognizer.callCount == 0)
        #expect(model.ocrState == .idle)
    }

    @Test("text classification preprocesses, recognizes, and inserts editable output")
    func recognizesText() async {
        let classifier = FakeImageTextClassifier(.text(confidence: 0.8))
        let preprocessor = FakeImagePreprocessor(mode: .document)
        let recognizer = FakeTextRecognizer(text: "texto reconhecido")
        let model = makeModel(
            classifier: classifier,
            preprocessor: preprocessor,
            recognizer: recognizer,
            detector: OCRFixedLanguageDetector(language: .portuguese)
        )

        model.enqueuePastedImage(OCRFixtures.image())
        await model.waitForOCR()

        #expect(model.plainText == "texto reconhecido")
        #expect(await recognizer.modes == [.document])
        #expect(await recognizer.languageHints == [[TranslationLanguage.portuguese.locale]])
    }

    @Test("recognition errors become visible OCR failure state")
    func surfacesErrors() async {
        let model = makeModel(
            classifier: FakeImageTextClassifier(.text(confidence: 1)),
            preprocessor: FakeImagePreprocessor(),
            recognizer: FakeTextRecognizer([.failure])
        )

        model.enqueuePastedImage(OCRFixtures.image())
        await model.waitForOCR()

        guard case .failed(let message) = model.ocrState else {
            Issue.record("Expected an OCR failure state")
            return
        }
        #expect(message.contains("falha esperada"))
        #expect(model.plainText.isEmpty)
    }

    @Test("classification errors propagate without running later stages")
    func classifierErrorsPropagate() async {
        let preprocessor = FakeImagePreprocessor()
        let recognizer = FakeTextRecognizer(text: "unused")
        let model = makeModel(
            classifier: FakeImageTextClassifier([.failure]),
            preprocessor: preprocessor,
            recognizer: recognizer
        )

        model.enqueuePastedImage(OCRFixtures.image())
        await model.waitForOCR()

        guard case .failed(let message) = model.ocrState else {
            Issue.record("Expected the classifier error to reach OCR state")
            return
        }
        #expect(message.contains("falha esperada"))
        #expect(await preprocessor.callCount == 0)
        #expect(await recognizer.callCount == 0)
    }

    @Test("disabled OCR creates no work")
    func disabledDoesNotCallDependencies() async {
        let classifier = FakeImageTextClassifier(.text(confidence: 1))
        let preprocessor = FakeImagePreprocessor()
        let recognizer = FakeTextRecognizer(text: "unused")
        let model = makeModel(
            classifier: classifier,
            preprocessor: preprocessor,
            recognizer: recognizer,
            enabled: false
        )

        model.enqueuePastedImage(OCRFixtures.image())
        await Task.yield()

        #expect(await classifier.callCount == 0)
        #expect(await preprocessor.callCount == 0)
        #expect(await recognizer.callCount == 0)
        #expect(model.ocrState == .idle)
    }

    @Test("formula classification uses only the injected future seam")
    func formulaUsesFakeConverter() async {
        let converter = FakeFormulaConverter(output: "E = mc^2")
        let preprocessor = FakeImagePreprocessor()
        let recognizer = FakeTextRecognizer(text: "unused")
        let model = makeModel(
            classifier: FakeImageTextClassifier(.formula),
            preprocessor: preprocessor,
            recognizer: recognizer,
            formulaConverter: converter
        )

        model.enqueuePastedImage(OCRFixtures.image())
        await model.waitForOCR()

        #expect(model.plainText == "E = mc^2")
        #expect(await converter.callCount == 1)
        #expect(await preprocessor.callCount == 0)
        #expect(await recognizer.callCount == 0)
    }

    @Test("OCR jobs are processed FIFO")
    func queueIsFIFO() async {
        let classifier = FakeImageTextClassifier([
            .value(.text(confidence: 1)),
            .value(.text(confidence: 1)),
        ])
        let recognizer = FakeTextRecognizer([
            .value(RecognizedText(text: "primeiro", confidence: 1)),
            .value(RecognizedText(text: "segundo", confidence: 1)),
        ])
        let model = makeModel(
            classifier: classifier,
            preprocessor: FakeImagePreprocessor(),
            recognizer: recognizer
        )

        model.enqueuePastedImage(OCRFixtures.image(width: 8))
        model.enqueuePastedImage(OCRFixtures.image(width: 9))
        await model.waitForOCR()

        #expect(model.plainText == "primeiro\nsegundo")
        #expect(await recognizer.callCount == 2)
    }

    @Test("disabling OCR cancels current work and clears the queue")
    func disablingCancels() async throws {
        let recognizer = BlockingTextRecognizer()
        let model = makeModel(
            classifier: FakeImageTextClassifier(.text(confidence: 1)),
            preprocessor: FakeImagePreprocessor(),
            recognizer: recognizer
        )

        model.enqueuePastedImage(OCRFixtures.image())
        let didStart = await OCRFixtures.eventually { await recognizer.callCount == 1 }
        try #require(didStart)

        model.setOCREnabled(false)
        await Task.yield()

        #expect(model.ocrState == .idle)
        #expect(model.plainText.isEmpty)
        #expect(model.isOCREnabled == false)
    }
}
