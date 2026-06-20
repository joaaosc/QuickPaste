import CoreGraphics
import Foundation
import Vision

// Protocol seams for the OCR module. Vision/Core AI stay behind these so `EditorModel`
// is testable with fakes and beta frameworks are isolated. Inputs are `CGImage`
// (Sendable, what Vision wants) so calls cross actor boundaries cleanly.

/// Decides whether an image is worth OCR (and, later, whether it's a formula).
nonisolated protocol ImageTextClassifying: Sendable {
    func classify(_ image: CGImage) async throws -> ImageTextClass
}

/// Corrects document perspective and improves small inputs before recognition.
nonisolated protocol ImagePreprocessing: Sendable {
    func prepare(_ image: CGImage) async throws -> OCRPreparedImage
}

/// Recognizes text in an image (OCR).
nonisolated protocol TextRecognizing: Sendable {
    func recognize(
        in image: CGImage,
        mode: OCRRecognitionMode,
        recognitionLanguages: [Locale.Language]
    ) async throws -> RecognizedText
}

/// Converts an image of a rendered formula into LaTeX. **Implemented by a separate module**
/// (a custom model running in Core AI). Declared here only to prepare the integration —
/// there is no live implementation in this module.
nonisolated protocol FormulaConverting: Sendable {
    func latex(from image: CGImage) async throws -> String
}

// MARK: - Vision implementations

/// Fast gate: dimensions, detected text regions, then a low-cost recognition probe.
actor VisionImageTextClassifier: ImageTextClassifying {
    var minimumCharacters = 3
    var minimumConfidence = 0.3
    var minimumPixelDimension = 24
    var minimumPixelCount = 1_024
    var minimumTextCoverage = 0.0005

    func classify(_ image: CGImage) async throws -> ImageTextClass {
        guard image.width >= minimumPixelDimension,
              image.height >= minimumPixelDimension,
              image.width * image.height >= minimumPixelCount
        else { return .noText }

        var regionRequest = DetectTextRectanglesRequest()
        regionRequest.reportCharacterBoxes = false
        let regions = try await regionRequest.perform(on: image)
        try Task.checkCancellation()

        let coverage = min(1, regions.reduce(0.0) { partial, observation in
            partial + observation.boundingBox.width * observation.boundingBox.height
        })
        guard regions.isEmpty == false, coverage >= minimumTextCoverage else { return .noText }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = true

        let observations = try await request.perform(on: image)
        try Task.checkCancellation()
        guard observations.isEmpty == false else { return .noText }

        var characters = 0
        var weightedConfidence = 0.0
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let count = candidate.string.filter { $0.isWhitespace == false }.count
            characters += count
            weightedConfidence += Double(candidate.confidence) * Double(count)
        }

        let confidence = characters > 0 ? weightedConfidence / Double(characters) : 0
        guard characters >= minimumCharacters, confidence >= minimumConfidence else { return .noText }
        return .text(confidence: confidence)
    }
}

/// Accurate OCR via Vision. Document recognition falls back to general text recognition.
actor VisionTextRecognizer: TextRecognizing {
    func recognize(
        in image: CGImage,
        mode: OCRRecognitionMode,
        recognitionLanguages: [Locale.Language]
    ) async throws -> RecognizedText {
        if mode == .document {
            do {
                let documentResult = try await recognizeDocument(
                    in: image,
                    recognitionLanguages: recognitionLanguages
                )
                if documentResult.isEmpty == false { return documentResult }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // General OCR is the documented fallback for an unsupported document layout.
            }
        }

        return try await recognizeGeneralText(
            in: image,
            recognitionLanguages: recognitionLanguages
        )
    }

    private func recognizeGeneralText(
        in image: CGImage,
        recognitionLanguages: [Locale.Language]
    ) async throws -> RecognizedText {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = recognitionLanguages.isEmpty
        if recognitionLanguages.isEmpty == false {
            request.recognitionLanguages = recognitionLanguages
        }

        let observations = try await request.perform(on: image)
        try Task.checkCancellation()
        return OCRTextAssembler.result(from: observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRTextBlock(
                text: candidate.string,
                confidence: Double(candidate.confidence),
                boundingBox: observation.boundingBox.cgRect
            )
        })
    }

    private func recognizeDocument(
        in image: CGImage,
        recognitionLanguages: [Locale.Language]
    ) async throws -> RecognizedText {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.automaticallyDetectLanguage = recognitionLanguages.isEmpty
        request.textRecognitionOptions.recognitionLanguages = recognitionLanguages
        request.textRecognitionOptions.useLanguageCorrection = true
        request.barcodeDetectionOptions.enabled = false

        let observations = try await request.perform(on: image)
        try Task.checkCancellation()

        var blocks: [OCRTextBlock] = []
        for (documentIndex, observation) in observations.enumerated() {
            let paragraphs = observation.document.paragraphs
            if paragraphs.isEmpty {
                blocks.append(contentsOf: makeBlocks(from: observation.document.text.lines))
                continue
            }

            for (paragraphIndex, paragraph) in paragraphs.enumerated() {
                let stableParagraphIndex = documentIndex * 100_000 + paragraphIndex
                blocks.append(contentsOf: makeBlocks(
                    from: paragraph.lines,
                    paragraphIndex: stableParagraphIndex
                ))
            }
        }
        return OCRTextAssembler.result(from: blocks)
    }

    private func makeBlocks(
        from observations: [RecognizedTextObservation],
        paragraphIndex: Int? = nil
    ) -> [OCRTextBlock] {
        observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRTextBlock(
                text: candidate.string,
                confidence: Double(candidate.confidence),
                boundingBox: observation.boundingBox.cgRect,
                paragraphIndex: paragraphIndex
            )
        }
    }
}
