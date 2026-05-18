//
//  QuickPasteSettings.swift
//  QuickPaste
//
//  Created by João Pedro Torres on 18/05/26.
//

import Foundation

enum QuickPasteSettings {
    static let appGroupID = "group.com.joaopedro.quickpaste"

    static var defaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            fatalError("Could not load shared UserDefaults for App Group: \(appGroupID)")
        }
        return defaults
    }

    enum Key {
        static let toggleTranslatorWithRightClick = "toggleTranslatorWithRightClick"
        static let defaultTranslationLanguage = "defaultTranslationLanguage"
    }

    static var toggleTranslatorWithRightClick: Bool {
        get {
            defaults.bool(forKey: Key.toggleTranslatorWithRightClick)
        }
        set {
            defaults.set(newValue, forKey: Key.toggleTranslatorWithRightClick)
        }
    }

    static var defaultTranslationLanguage: TranslationLanguage {
        get {
            let rawValue = defaults.string(forKey: Key.defaultTranslationLanguage)
                ?? TranslationLanguage.portuguese.rawValue

            return TranslationLanguage(rawValue: rawValue) ?? .portuguese
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.defaultTranslationLanguage)
        }
    }
}

enum TranslationLanguage: String, CaseIterable {
    case portuguese = "Portuguese"
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case italian = "Italian"

    var displayName: String {
        rawValue
    }
}
