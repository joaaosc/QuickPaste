import Foundation
import Observation
import Translation

/// Owns the scratchpad's state and orchestrates translation, keeping `EditorView` thin.
///
/// SwiftUI-coupled bits stay in the view by design: `translationTask` provides a
/// `TranslationSession` that is only valid inside its closure (using it later traps —
/// confirmed via apple-docs MCP). So this model holds the *state machine*,
/// language detection, persistence and post-processing; the view just feeds the
/// session's result back in via `finishTranslation` / `failTranslation`.
@MainActor
@Observable
final class EditorModel {
    // MARK: Observable state

    /// The note text. The view binds to this directly (`$model.text`) and reports
    /// edits via `handleTextChanged()` from `.onChange`.
    var text: String
    private(set) var detectedLanguage: TranslationLanguage?
    private(set) var translation: TranslationOutcome = .idle

    /// Drives the view's `translationTask`. Reassigning (or invalidating) it re-runs the task.
    var translationConfiguration: TranslationSession.Configuration?

    /// Snapshot of the text captured when translation was requested. The session is
    /// only valid inside the task closure, so the view reads this instead of `text`.
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

        let restored = persistence.note
        self.text = restored
        self.detectedLanguage = detector.detect(in: restored)
    }

    // MARK: Derived

    var isEmpty: Bool { text.isEmpty }
    var wordCount: Int { text.split(whereSeparator: \.isWhitespace).count }
    var characterCount: Int { text.count }

    // MARK: Editing

    /// React to a text change (the view calls this from `.onChange(of:)`). Debounces
    /// persistence and language detection so we neither write to disk nor re-detect
    /// on every keystroke.
    func handleTextChanged() {
        schedulePersist()
        scheduleDetect()
    }

    private func schedulePersist() {
        persistTask?.cancel()
        let snapshot = text
        persistTask = Task { [persistDebounce] in
            try? await Task.sleep(for: persistDebounce)
            guard !Task.isCancelled else { return }
            persistence.note = snapshot
        }
    }

    private func scheduleDetect() {
        detectTask?.cancel()
        let snapshot = text
        detectTask = Task { [detectDebounce] in
            try? await Task.sleep(for: detectDebounce)
            guard !Task.isCancelled else { return }
            detectedLanguage = detector.detect(in: snapshot)
        }
    }

    /// Flush any pending write immediately (panel close / app termination).
    func persistNow() {
        persistTask?.cancel()
        persistence.note = text
    }

    // MARK: Translation orchestration

    /// Builds/refreshes the configuration so the view's `translationTask` fires.
    /// When the detected source equals the target we leave `source` nil and let the
    /// system auto-detect, avoiding a misleading hint driving the request.
    func requestTranslation(to target: TranslationLanguage) {
        guard !text.isEmpty else { return }

        pendingSourceText = text
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

    /// Post-processing seam: trim and reject empty output before showing it.
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

    /// Replace the note with the translation (user-initiated, never automatic).
    func adoptTranslation() {
        guard let value = translation.result else { return }
        text = value
        dismissTranslation()
    }

    // MARK: Pasteboard actions

    func copyNote() {
        guard !text.isEmpty else { return }
        pasteboard.write(text)
    }

    func copyTranslation() {
        guard let value = translation.result else { return }
        pasteboard.write(value)
    }

    // MARK: Clearing

    func clear() {
        text = ""
        dismissTranslation()
    }
}
