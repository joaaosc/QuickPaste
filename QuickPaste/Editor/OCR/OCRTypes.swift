import Foundation

/// How an image relates to text, for deciding whether OCR is worthwhile.
enum ImageTextClass: Equatable {
    case noText
    case text(confidence: Double)
    /// Reserved for the separate LaTeX-conversion module (a custom Core AI model).
    case formula
}

/// Output of recognizing text in an image.
struct RecognizedText: Equatable {
    var text: String
    var confidence: Double

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    static let empty = RecognizedText(text: "", confidence: 0)
}
