import AppKit
import CoreGraphics
import Foundation
import Observation
import Translation

/// Owns the scratchpad's state and orchestrates translation, keeping `EditorView` thin.
///
/// The note content is an `NSAttributedString` so pasted images live **inline in the
/// text body** (as text attachments). Plain-text features (translation, counts, language
/// detection) derive from `plainText`. SwiftUI-coupled translation stays in the view:
/// `TranslationSession` is only valid inside the `translationTask` closure (confirmed via
/// apple-docs MCP), so the view feeds results back via `finishTranslation`/`failTranslation`.
@MainActor
@Observable
final class EditorModel {
    // MARK: Observable state

    /// The note as rich text (text + inline image attachments). The editor view edits this.
    private(set) var attributedText: NSAttributedString

    private(set) var detectedLanguage: TranslationLanguage?
    private(set) var translation: TranslationOutcome = .idle
    private(set) var ocrState: OCRState = .idle
    private(set) var isOCREnabled: Bool

    /// Drives the view's `translationTask`. Reassigning (or invalidating) it re-runs the task.
    var translationConfiguration: TranslationSession.Configuration?

    /// Snapshot of the plain text captured when translation was requested.
    private(set) var pendingSourceText = ""

    // MARK: Dependencies

    private let persistence: NotePersisting
    private let pasteboard: PasteboardWriting
    private let detector: LanguageDetecting
    private let classifier: ImageTextClassifying
    private let imagePreprocessor: ImagePreprocessing
    private let recognizer: TextRecognizing
    private let formulaConverter: (any FormulaConverting)?
    /// Read live so a Settings change during the session takes effect on the next conversion;
    /// injectable so tests can pin a destination without touching global defaults.
    private let latexDestination: () -> LatexOutputDestination
    private let persistDebounce: Duration
    private let detectDebounce: Duration

    private var persistTask: Task<Void, Never>?
    private var detectTask: Task<Void, Never>?
    private var ocrTask: Task<Void, Never>?
    private var ocrQueue: [OCRJob] = []
    private var ocrGeneration = UUID()
    private var ocrCompleted = 0
    private var ocrTotal = 0

    private struct OCRJob: Sendable {
        enum Kind: Equatable, Sendable {
            case automatic
            case explicit
            case formula
        }

        let image: CGImage
        let kind: Kind
    }

    init(
        persistence: NotePersisting = UserDefaultsNotePersistence(),
        pasteboard: PasteboardWriting = SystemPasteboard(),
        detector: LanguageDetecting = NaturalLanguageDetector(),
        classifier: ImageTextClassifying = VisionImageTextClassifier(),
        imagePreprocessor: ImagePreprocessing = VisionOCRImagePreprocessor(),
        recognizer: TextRecognizing = VisionTextRecognizer(),
        formulaConverter: (any FormulaConverting)? = nil,
        latexDestination: @escaping () -> LatexOutputDestination = { QuickPasteSettings.latexOutputDestination },
        ocrEnabled: Bool? = nil,
        persistDebounce: Duration = .milliseconds(400),
        detectDebounce: Duration = .milliseconds(300)
    ) {
        self.persistence = persistence
        self.pasteboard = pasteboard
        self.detector = detector
        self.classifier = classifier
        self.imagePreprocessor = imagePreprocessor
        self.recognizer = recognizer
        self.formulaConverter = formulaConverter
        self.latexDestination = latexDestination
        self.isOCREnabled = ocrEnabled ?? QuickPasteSettings.ocrEnabled
        self.persistDebounce = persistDebounce
        self.detectDebounce = detectDebounce

        if let data = persistence.richDocument, let restored = Self.attributedString(fromRTFD: data) {
            self.attributedText = restored
        } else {
            self.attributedText = NSAttributedString(string: persistence.note)
        }
        self.detectedLanguage = detector.detect(in: self.attributedText.string)
    }

    // MARK: Derived

    /// The note's text, excluding image attachments (the object-replacement char U+FFFC),
    /// so translation, copy and counts operate on real text only.
    var plainText: String { attributedText.string.replacingOccurrences(of: "\u{FFFC}", with: "") }
    var isEmpty: Bool { plainText.isEmpty }
    var hasContent: Bool { attributedText.length > 0 }
    var wordCount: Int { plainText.split(whereSeparator: \.isWhitespace).count }
    var characterCount: Int { plainText.count }

    // MARK: Editing

    /// React to a content change reported by the editor. Debounces persistence and
    /// language detection so we neither write to disk nor re-detect on every keystroke.
    func updateContent(_ newValue: NSAttributedString) {
        guard !newValue.isEqual(to: attributedText) else { return }
        attributedText = newValue
        schedulePersist()
        scheduleDetect()
    }

    private func schedulePersist() {
        persistTask?.cancel()
        let snapshot = attributedText
        persistTask = Task { [persistDebounce] in
            try? await Task.sleep(for: persistDebounce)
            guard !Task.isCancelled else { return }
            persist(snapshot)
        }
    }

    private func scheduleDetect() {
        detectTask?.cancel()
        let snapshot = plainText
        detectTask = Task { [detectDebounce] in
            try? await Task.sleep(for: detectDebounce)
            guard !Task.isCancelled else { return }
            detectedLanguage = detector.detect(in: snapshot)
        }
    }

    /// Flush any pending write immediately (panel close / app termination).
    func persistNow() {
        persistTask?.cancel()
        persist(attributedText)
    }

    private func persist(_ attr: NSAttributedString) {
        persistence.richDocument = Self.rtfdData(from: attr)
        persistence.note = attr.string
    }

    // MARK: Translation orchestration

    func requestTranslation(to target: TranslationLanguage) {
        guard !plainText.isEmpty else { return }

        pendingSourceText = plainText
        translation = .inProgress

        let source: Locale.Language? = (detectedLanguage == target) ? nil : detectedLanguage?.locale

        if var configuration = translationConfiguration {
            configuration.source = source
            configuration.target = target.locale
            configuration.invalidate()
            translationConfiguration = configuration
        } else {
            translationConfiguration = TranslationSession.Configuration(source: source, target: target.locale)
        }
    }

    func finishTranslation(_ targetText: String) {
        let trimmed = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        translation = trimmed.isEmpty ? .failed("Tradução vazia.") : .completed(trimmed)
    }

    func failTranslation(_ message: String) {
        translation = .failed(message)
    }

    func dismissTranslation() {
        translation = .idle
        translationConfiguration = nil
    }

    /// Replace the note with the translation (user-initiated). Drops inline images.
    func adoptTranslation() {
        guard let value = translation.result else { return }
        attributedText = NSAttributedString(string: value)
        persistNow()
        detectedLanguage = detector.detect(in: value)
        dismissTranslation()
    }

    // MARK: Pasteboard actions

    func copyNote() {
        guard !plainText.isEmpty else { return }
        pasteboard.write(plainText)
    }

    func copyTranslation() {
        guard let value = translation.result else { return }
        pasteboard.write(value)
    }

    // MARK: Clearing

    func clear() {
        cancelOCR()
        attributedText = NSAttributedString(string: "")
        detectedLanguage = nil
        persistNow()
        dismissTranslation()
    }

    // MARK: OCR (text in images)

    /// Whether formula→LaTeX conversion can run (a Core AI converter was injected, i.e. macOS 27
    /// with Core AI). Drives whether the "Converter fórmula para LaTeX" menu item is offered.
    var isFormulaConversionAvailable: Bool { formulaConverter != nil }

    func setOCREnabled(_ enabled: Bool) {
        guard isOCREnabled != enabled else { return }
        isOCREnabled = enabled
        if enabled == false { cancelOCR() }
    }

    /// Auto-OCR after paste. Disabled OCR never allocates a task or queues work.
    func enqueuePastedImage(_ image: CGImage) {
        enqueueOCR(OCRJob(image: image, kind: .automatic))
    }

    /// Explicit OCR from the image context menu skips only the viability classification.
    func enqueueRecognition(_ image: CGImage) {
        enqueueOCR(OCRJob(image: image, kind: .explicit))
    }

    /// Explicit formula→LaTeX from the image context menu. Requires the Core AI converter;
    /// reuses the OCR queue/cancellation/state and is gated by `isOCREnabled` like the rest.
    func enqueueFormula(_ image: CGImage) {
        guard formulaConverter != nil else { return }
        enqueueOCR(OCRJob(image: image, kind: .formula))
    }

    func cancelOCR() {
        ocrGeneration = UUID()
        ocrTask?.cancel()
        ocrTask = nil
        ocrQueue.removeAll(keepingCapacity: false)
        ocrCompleted = 0
        ocrTotal = 0
        ocrState = .idle
    }

    func dismissOCRError() {
        if case .failed = ocrState { ocrState = .idle }
    }

    /// Test synchronization point; production code observes `ocrState` instead.
    func waitForOCR() async {
        while let task = ocrTask {
            await task.value
        }
    }

    private func enqueueOCR(_ job: OCRJob) {
        guard isOCREnabled else { return }

        if ocrTask == nil {
            ocrCompleted = 0
            ocrTotal = 0
        }
        ocrQueue.append(job)
        ocrTotal += 1
        ocrState = .processing(completed: ocrCompleted, total: ocrTotal)
        startOCRWorkerIfNeeded()
    }

    private func startOCRWorkerIfNeeded() {
        guard ocrTask == nil, ocrQueue.isEmpty == false else { return }
        let generation = ocrGeneration
        ocrTask = Task { [weak self] in
            await self?.drainOCRQueue(generation: generation)
        }
    }

    private func drainOCRQueue(generation: UUID) async {
        var lastErrorMessage: String?

        while isOCREnabled, generation == ocrGeneration, ocrQueue.isEmpty == false {
            let job = ocrQueue.removeFirst()
            do {
                try await processOCRJob(job, generation: generation)
            } catch is CancellationError {
                return
            } catch {
                lastErrorMessage = Self.failureMessage(for: error)
            }

            guard generation == ocrGeneration else { return }
            ocrCompleted += 1
            if ocrQueue.isEmpty == false {
                ocrState = .processing(completed: ocrCompleted, total: ocrTotal)
            }
        }

        guard generation == ocrGeneration else { return }
        ocrTask = nil
        ocrQueue.removeAll(keepingCapacity: false)
        ocrState = lastErrorMessage.map(OCRState.failed(message:)) ?? .idle
    }

    private func processOCRJob(_ job: OCRJob, generation: UUID) async throws {
        try Task.checkCancellation()

        if job.kind == .formula {
            guard let formulaConverter else { return }
            let latex = try await formulaConverter.latex(from: job.image)
            try Task.checkCancellation()
            guard isOCREnabled, generation == ocrGeneration else { throw CancellationError() }
            dispatchLatex(latex)
            return
        }

        if job.kind == .automatic {
            switch try await classifier.classify(job.image) {
            case .noText:
                return
            case .formula:
                guard let formulaConverter else { return }
                let latex = try await formulaConverter.latex(from: job.image)
                try Task.checkCancellation()
                guard isOCREnabled, generation == ocrGeneration else { throw CancellationError() }
                dispatchLatex(latex)
                return
            case .text:
                break
            }
        }

        try Task.checkCancellation()
        let prepared = try await imagePreprocessor.prepare(job.image)
        try Task.checkCancellation()

        let languageHints = detectedLanguage.map { [$0.locale] } ?? []
        let recognized = try await recognizer.recognize(
            in: prepared.image,
            mode: prepared.mode,
            recognitionLanguages: languageHints
        )
        try Task.checkCancellation()
        guard isOCREnabled, generation == ocrGeneration else { throw CancellationError() }
        guard recognized.isEmpty == false else { return }
        appendRecognizedText(recognized.text)
    }

    /// Route recognized LaTeX to the destination chosen in Settings (non-destructive: keeps the
    /// image). Insert appends to the note like OCR; copy writes the LaTeX to the clipboard.
    private func dispatchLatex(_ latex: String) {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        switch latexDestination() {
        case .insertIntoNote:
            appendRecognizedText(trimmed)
        case .copyToClipboard:
            pasteboard.write(trimmed)
        case .both:
            appendRecognizedText(trimmed)
            pasteboard.write(trimmed)
        }
    }

    /// Append recognized text to the note (non-destructive: keeps the image).
    private func appendRecognizedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        if mutable.length > 0 {
            mutable.append(NSAttributedString(string: "\n"))
        }
        mutable.append(NSAttributedString(string: trimmed))
        attributedText = mutable
        persistNow()
        detectedLanguage = detector.detect(in: plainText)
    }

    /// Formula-domain errors (no formula / asset missing) already read as full sentences; only
    /// generic OCR errors get the "OCR falhou:" prefix.
    private static func failureMessage(for error: Error) -> String {
        if error is RecognitionError || error is RuntimeResourceError {
            return error.localizedDescription
        }
        return "OCR falhou: \(error.localizedDescription)"
    }

    // MARK: RTFD helpers

    static func rtfdData(from attr: NSAttributedString) -> Data? {
        try? attr.data(
            from: NSRange(location: 0, length: attr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
    }

    static func attributedString(fromRTFD data: Data) -> NSAttributedString? {
        try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        )
    }
}
