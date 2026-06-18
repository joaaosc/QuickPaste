import AppKit
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

    /// Drives the view's `translationTask`. Reassigning (or invalidating) it re-runs the task.
    var translationConfiguration: TranslationSession.Configuration?

    /// Snapshot of the plain text captured when translation was requested.
    private(set) var pendingSourceText = ""

    // MARK: Dependencies

    private let persistence: NotePersisting
    private let pasteboard: PasteboardWriting
    private let detector: LanguageDetecting
    private let persistDebounce: Duration
    private let detectDebounce: Duration

    private var persistTask: Task<Void, Never>?
    private var detectTask: Task<Void, Never>?

    init(
        persistence: NotePersisting = UserDefaultsNotePersistence(),
        pasteboard: PasteboardWriting = SystemPasteboard(),
        detector: LanguageDetecting = NaturalLanguageDetector(),
        persistDebounce: Duration = .milliseconds(400),
        detectDebounce: Duration = .milliseconds(300)
    ) {
        self.persistence = persistence
        self.pasteboard = pasteboard
        self.detector = detector
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
        attributedText = NSAttributedString(string: "")
        detectedLanguage = nil
        persistNow()
        dismissTranslation()
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
