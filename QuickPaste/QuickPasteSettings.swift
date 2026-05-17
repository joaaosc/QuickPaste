import Foundation

enum QuickPasteSettings {
    static let appGroupIdentifier = "33FPG9442W.QuickPaste"
    static let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
}
