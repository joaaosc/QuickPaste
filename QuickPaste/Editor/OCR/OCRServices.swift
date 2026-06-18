import CoreGraphics
import Vision

// Protocol seams for the OCR module. Vision/Core AI stay behind these so `EditorModel`
// is testable with fakes and beta frameworks are isolated. Inputs are `CGImage`
// (Sendable, what Vision wants) so calls cross actor boundaries cleanly.

/// Decides whether an image is worth OCR (and, later, whether it's a formula).
protocol ImageTextClassifying: Sendable {
    func classify(_ image: CGImage) async -> ImageTextClass
}

/// Recognizes text in an image (OCR).
protocol TextRecognizing: Sendable {
    func recognize(in image: CGImage) async throws -> RecognizedText
}

/// Converts an image of a rendered formula into LaTeX. **Implemented by a separate module**
/// (a custom model running in Core AI). Declared here only to prepare the integration —
/// there is no live implementation in this module.
protocol FormulaConverting: Sendable {
    func latex(from image: CGImage) async throws -> String
}

// MARK: - Vision implementations

/// Fast gate: a low-cost text-recognition pass to classify OCR viability.
nonisolated struct VisionImageTextClassifier: ImageTextClassifying {
    var minimumCharacters = 3
    var minimumConfidence = 0.3

    func classify(_ image: CGImage) async -> ImageTextClass {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        guard let observations = try? await request.perform(on: image), !observations.isEmpty else {
            return .noText
        }

        var characters = 0
        var totalConfidence = 0.0
        var count = 0
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            characters += candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).count
            totalConfidence += Double(candidate.confidence)
            count += 1
        }

        let confidence = count > 0 ? totalConfidence / Double(count) : 0
        guard characters >= minimumCharacters, confidence >= minimumConfidence else { return .noText }
        return .text(confidence: confidence)
    }
}

/// Accurate OCR via Vision's `RecognizeTextRequest`.
nonisolated struct VisionTextRecognizer: TextRecognizing {
    var recognitionLanguages: [Locale.Language] = []

    func recognize(in image: CGImage) async throws -> RecognizedText {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if !recognitionLanguages.isEmpty {
            request.recognitionLanguages = recognitionLanguages
        }

        let observations = try await request.perform(on: image)

        var lines: [String] = []
        var totalConfidence = 0.0
        var count = 0
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            lines.append(candidate.string)
            totalConfidence += Double(candidate.confidence)
            count += 1
        }

        let confidence = count > 0 ? totalConfidence / Double(count) : 0
        return RecognizedText(text: lines.joined(separator: "\n"), confidence: confidence)
    }
}
