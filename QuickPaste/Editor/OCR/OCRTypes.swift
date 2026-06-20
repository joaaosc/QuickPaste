import CoreGraphics
import Foundation

/// How an image relates to text, for deciding whether OCR is worthwhile.
nonisolated enum ImageTextClass: Equatable, Sendable {
    case noText
    case text(confidence: Double)
    /// Reserved for the separate LaTeX-conversion module (a custom Core AI model).
    case formula
}

/// Output of recognizing text in an image.
nonisolated struct OCRTextBlock: Equatable, Sendable {
    let text: String
    let confidence: Double
    let boundingBox: CGRect
    let paragraphIndex: Int?

    init(
        text: String,
        confidence: Double,
        boundingBox: CGRect,
        paragraphIndex: Int? = nil
    ) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.paragraphIndex = paragraphIndex
    }
}

/// Output of recognizing text in an image, including editable text and source geometry.
nonisolated struct RecognizedText: Equatable, Sendable {
    let text: String
    let confidence: Double
    let blocks: [OCRTextBlock]

    init(text: String, confidence: Double, blocks: [OCRTextBlock] = []) {
        self.text = text
        self.confidence = confidence
        self.blocks = blocks
    }

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    static let empty = RecognizedText(text: "", confidence: 0)
}

nonisolated enum OCRRecognitionMode: Equatable, Sendable {
    case general
    case document
}

nonisolated struct OCRPreparedImage: Sendable {
    let image: CGImage
    let mode: OCRRecognitionMode
}

nonisolated enum OCRState: Equatable, Sendable {
    case idle
    case processing(completed: Int, total: Int)
    case failed(message: String)

    var isProcessing: Bool {
        if case .processing = self { true } else { false }
    }
}
