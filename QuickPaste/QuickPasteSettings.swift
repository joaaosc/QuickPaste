import Foundation

enum QuickPasteSettings {
    enum Key {
        static let openEditorAtLaunch = "openEditorAtLaunch"
        static let globalHotKeyEnabled = "globalHotKeyEnabled"
        static let editorFontSize = "editorFontSize"
        static let targetLanguage = "targetLanguage"
        static let noteText = "noteText"
    }

    static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.openEditorAtLaunch: false,
            Key.globalHotKeyEnabled: true,
            Key.editorFontSize: 14.0,
            Key.targetLanguage: TranslationLanguage.english.rawValue,
        ])
    }

    static var openEditorAtLaunch: Bool {
        defaults.bool(forKey: Key.openEditorAtLaunch)
    }

    static var globalHotKeyEnabled: Bool {
        defaults.bool(forKey: Key.globalHotKeyEnabled)
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
