import AppKit
import Foundation
import NaturalLanguage

// Protocol seams for the editor's side effects. They keep `EditorModel` free of
// concrete frameworks so state/orchestration stays testable with fakes, and they
// put the (sandboxed, on-device) privacy boundary in one place.

// MARK: - Note persistence

/// Reads/writes the scratchpad note. The live implementation is `UserDefaults`,
/// but the model only depends on this protocol so tests can inject an in-memory store.
protocol NotePersisting: AnyObject {
    var note: String { get set }
    /// The note as an RTFD document (embeds inline images), or nil when empty.
    var richDocument: Data? { get set }
}

nonisolated final class UserDefaultsNotePersistence: NotePersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = QuickPasteSettings.Key.noteText) {
        self.defaults = defaults
        self.key = key
    }

    var note: String {
        get { defaults.string(forKey: key) ?? "" }
        set { defaults.set(newValue, forKey: key) }
    }

    var richDocument: Data? {
        get { defaults.data(forKey: QuickPasteSettings.Key.noteRTFD) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: QuickPasteSettings.Key.noteRTFD)
            } else {
                defaults.removeObject(forKey: QuickPasteSettings.Key.noteRTFD)
            }
        }
    }
}

/// In-memory note store for SwiftUI previews and unit tests (no UserDefaults side effects).
nonisolated final class InMemoryNotePersistence: NotePersisting {
    var note: String
    var richDocument: Data?
    init(note: String = "", richDocument: Data? = nil) {
        self.note = note
        self.richDocument = richDocument
    }
}

// MARK: - Pasteboard

/// Write-only pasteboard seam — QuickPaste only ever *writes* the note out.
protocol PasteboardWriting {
    func write(_ string: String)
}

nonisolated struct SystemPasteboard: PasteboardWriting {
    func write(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

// MARK: - Language detection

/// On-device language identification. Backed by NaturalLanguage's `NLLanguageRecognizer`
/// (macOS 10.14+, verified via apple-docs MCP): fully local, no network, no model download —
/// safe for clipboard-sensitive text.
protocol LanguageDetecting {
    func detect(in text: String) -> TranslationLanguage?
}

nonisolated struct NaturalLanguageDetector: LanguageDetecting {
    /// Below this many characters detection is too noisy to be useful, so we abstain.
    var minimumCharacters = 8

    func detect(in text: String) -> TranslationLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumCharacters,
              let language = NLLanguageRecognizer.dominantLanguage(for: trimmed)
        else { return nil }
        return TranslationLanguage(languageCode: language.rawValue)
    }
}
