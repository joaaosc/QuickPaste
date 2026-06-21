import AppKit
import Testing
@testable import QuickPaste

private final class SpyPasteboard: PasteboardWriting, @unchecked Sendable {
    private(set) var written: [String] = []
    func write(_ string: String) { written.append(string) }
}

private actor ThrowingFormulaConverter: FormulaConverting {
    let error: Error
    private(set) var callCount = 0

    init(error: Error) { self.error = error }

    func latex(from image: CGImage) async throws -> String {
        callCount += 1
        throw error
    }
}

@MainActor
struct FormulaConversionTests {
    private func makeModel(
        formulaConverter: (any FormulaConverting)?,
        destination: LatexOutputDestination = .insertIntoNote,
        pasteboard: SpyPasteboard = SpyPasteboard(),
        enabled: Bool = true
    ) -> EditorModel {
        EditorModel(
            persistence: InMemoryNotePersistence(),
            pasteboard: pasteboard,
            detector: OCRFixedLanguageDetector(language: nil),
            classifier: FakeImageTextClassifier(.noText),
            imagePreprocessor: FakeImagePreprocessor(),
            recognizer: FakeTextRecognizer(text: "unused"),
            formulaConverter: formulaConverter,
            latexDestination: { destination },
            ocrEnabled: enabled
        )
    }

    @Test("insert destination appends LaTeX to the note, keeping the clipboard untouched")
    func insertsLatex() async {
        let converter = FakeFormulaConverter(output: "E = mc^2")
        let pasteboard = SpyPasteboard()
        let model = makeModel(formulaConverter: converter, destination: .insertIntoNote, pasteboard: pasteboard)

        model.enqueueFormula(OCRFixtures.image())
        await model.waitForOCR()

        #expect(model.plainText == "E = mc^2")
        #expect(pasteboard.written.isEmpty)
        #expect(await converter.callCount == 1)
    }

    @Test("copy destination writes LaTeX to the clipboard only")
    func copiesLatex() async {
        let pasteboard = SpyPasteboard()
        let model = makeModel(
            formulaConverter: FakeFormulaConverter(output: "x^2"),
            destination: .copyToClipboard,
            pasteboard: pasteboard
        )

        model.enqueueFormula(OCRFixtures.image())
        await model.waitForOCR()

        #expect(model.plainText.isEmpty)
        #expect(pasteboard.written == ["x^2"])
    }

    @Test("both destination inserts and copies")
    func insertsAndCopies() async {
        let pasteboard = SpyPasteboard()
        let model = makeModel(
            formulaConverter: FakeFormulaConverter(output: "a + b"),
            destination: .both,
            pasteboard: pasteboard
        )

        model.enqueueFormula(OCRFixtures.image())
        await model.waitForOCR()

        #expect(model.plainText == "a + b")
        #expect(pasteboard.written == ["a + b"])
    }

    @Test("no-formula surfaces a clear message without the OCR prefix")
    func noFormulaMessage() async {
        let model = makeModel(formulaConverter: ThrowingFormulaConverter(error: RecognitionError.noFormula))

        model.enqueueFormula(OCRFixtures.image())
        await model.waitForOCR()

        guard case .failed(let message) = model.ocrState else {
            Issue.record("Expected a failure state for an unusable formula")
            return
        }
        #expect(message == RecognitionError.noFormula.localizedDescription)
        #expect(message.contains("OCR falhou") == false)
        #expect(model.plainText.isEmpty)
    }

    @Test("formula conversion is a no-op without a converter")
    func noConverterNoOp() async {
        let model = makeModel(formulaConverter: nil)

        model.enqueueFormula(OCRFixtures.image())
        await Task.yield()

        #expect(model.ocrState == .idle)
        #expect(model.plainText.isEmpty)
        #expect(model.isFormulaConversionAvailable == false)
    }

    @Test("disabled OCR gating blocks formula conversion")
    func disabledBlocksFormula() async {
        let converter = FakeFormulaConverter(output: "unused")
        let model = makeModel(formulaConverter: converter, enabled: false)

        model.enqueueFormula(OCRFixtures.image())
        await Task.yield()

        #expect(await converter.callCount == 0)
        #expect(model.plainText.isEmpty)
        #expect(model.ocrState == .idle)
    }

    @Test("OCR and formula jobs share the FIFO queue, in order")
    func mixedFifo() async {
        let model = makeModel(formulaConverter: FakeFormulaConverter(output: "E=mc^2"))

        model.enqueueRecognition(OCRFixtures.image()) // inserts the recognizer's "unused"
        model.enqueueFormula(OCRFixtures.image())      // then inserts the LaTeX
        await model.waitForOCR()

        #expect(model.plainText == "unused\nE=mc^2")
    }
}
