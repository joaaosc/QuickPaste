import Foundation

/// The state of an in-flight or finished translation. A small explicit state
/// machine instead of three loose optionals, so the view renders one case at a time.
enum TranslationOutcome: Equatable {
    case idle
    case inProgress
    case completed(String)
    case failed(String)

    var isInProgress: Bool { self == .inProgress }
    var isActive: Bool { self != .idle }
    var result: String? { if case let .completed(value) = self { return value } else { return nil } }
    var errorMessage: String? { if case let .failed(message) = self { return message } else { return nil } }
}
