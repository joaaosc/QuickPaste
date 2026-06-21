import Foundation

enum QuickPasteSettings {
    nonisolated enum Key {
        static let openEditorAtLaunch = "openEditorAtLaunch"
        static let globalHotKeyEnabled = "globalHotKeyEnabled"
        static let editorFontSize = "editorFontSize"
        static let targetLanguage = "targetLanguage"
        static let noteText = "noteText"
        static let noteRTFD = "noteRTFD"
        static let translationEnabled = "translationEnabled"
        static let ocrEnabled = "ocrEnabled"
        static let allowMultipleImages = "allowMultipleImages"
        static let latexOutputDestination = "latexOutputDestination"
        static let customHotKeyKeyCode = "customHotKeyKeyCode"
        static let customHotKeyModifiers = "customHotKeyModifiers"
        static let customHotKeyDisplay = "customHotKeyDisplay"
    }

    static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.openEditorAtLaunch: false,
            Key.globalHotKeyEnabled: true,
            Key.editorFontSize: 14.0,
            Key.targetLanguage: TranslationLanguage.english.rawValue,
            Key.translationEnabled: true,
            Key.ocrEnabled: false,
            Key.allowMultipleImages: false,
            Key.latexOutputDestination: LatexOutputDestination.insertIntoNote.rawValue,
            Key.customHotKeyKeyCode: -1,
            Key.customHotKeyModifiers: 0,
            Key.customHotKeyDisplay: "",
        ])
    }

    static var openEditorAtLaunch: Bool {
        defaults.bool(forKey: Key.openEditorAtLaunch)
    }

    static var globalHotKeyEnabled: Bool {
        defaults.bool(forKey: Key.globalHotKeyEnabled)
    }

    static var ocrEnabled: Bool {
        defaults.bool(forKey: Key.ocrEnabled)
    }

    /// Where recognized LaTeX goes when a formula conversion succeeds.
    static var latexOutputDestination: LatexOutputDestination {
        LatexOutputDestination(rawValue: defaults.string(forKey: Key.latexOutputDestination) ?? "")
            ?? .insertIntoNote
    }

    /// The user's custom global shortcut (Carbon key code + modifiers), or nil when unset.
    static var customHotKey: (keyCode: UInt32, carbonModifiers: UInt32)? {
        let code = defaults.integer(forKey: Key.customHotKeyKeyCode)
        guard code >= 0 else { return nil }
        let modifiers = defaults.integer(forKey: Key.customHotKeyModifiers)
        return (UInt32(code), UInt32(modifiers))
    }
}

/// Where a successful formula→LaTeX conversion sends its output. User-selectable in Settings.
nonisolated enum LatexOutputDestination: String, CaseIterable, Identifiable {
    case insertIntoNote
    case copyToClipboard
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .insertIntoNote: "Inserir na nota"
        case .copyToClipboard: "Copiar para a área de transferência"
        case .both: "Inserir e copiar"
        }
    }
}

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case portuguese = "pt-BR"
    case english = "en-US"
    case spanish = "es-ES"
    case french = "fr-FR"
    case german = "de-DE"
    case italian = "it-IT"
    case japanese = "ja-JP"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .portuguese: "Português"
        case .english: "Inglês"
        case .spanish: "Espanhol"
        case .french: "Francês"
        case .german: "Alemão"
        case .italian: "Italiano"
        case .japanese: "Japonês"
        case .chinese: "Chinês (simplificado)"
        }
    }

    var locale: Locale.Language {
        Locale.Language(identifier: rawValue)
    }

    /// Maps a detected BCP-47 code (e.g. NaturalLanguage's `"en"`, `"pt"`, `"zh-Hans"`)
    /// to a supported target by comparing primary language subtags.
    init?(languageCode code: String) {
        let primary = Self.primarySubtag(code)
        guard let match = Self.allCases.first(where: { Self.primarySubtag($0.rawValue) == primary }) else {
            return nil
        }
        self = match
    }

    private static func primarySubtag(_ code: String) -> Substring {
        code.lowercased().split(separator: "-").first ?? Substring(code.lowercased())
    }
}
