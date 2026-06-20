import AppKit
import CoreGraphics
import Foundation
@testable import QuickPaste

enum OCRTestError: Error, LocalizedError, Sendable {
    case expected

    var errorDescription: String? { "falha esperada" }
}

actor FakeImageTextClassifier: ImageTextClassifying {
    enum Outcome: Sendable {
        case value(ImageTextClass)
        case failure
    }

    private var outcomes: [Outcome]
    private(set) var callCount = 0

    init(_ outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    init(_ result: ImageTextClass) {
        self.outcomes = [.value(result)]
    }

    func classify(_ image: CGImage) async throws -> ImageTextClass {
        callCount += 1
        let outcome = outcomes.isEmpty ? .value(.noText) : outcomes.removeFirst()
        switch outcome {
        case .value(let result): return result
        case .failure: throw OCRTestError.expected
        }
    }
}

actor FakeImagePreprocessor: ImagePreprocessing {
    let mode: OCRRecognitionMode
    private(set) var callCount = 0

    init(mode: OCRRecognitionMode = .general) {
        self.mode = mode
    }

    func prepare(_ image: CGImage) async throws -> OCRPreparedImage {
        callCount += 1
        return OCRPreparedImage(image: image, mode: mode)
    }
}

actor FakeTextRecognizer: TextRecognizing {
    enum Outcome: Sendable {
        case value(RecognizedText)
        case failure
    }

    private var outcomes: [Outcome]
    private(set) var modes: [OCRRecognitionMode] = []
    private(set) var languageHints: [[Locale.Language]] = []

    init(_ outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    init(text: String) {
        self.outcomes = [.value(RecognizedText(text: text, confidence: 0.9))]
    }

    func recognize(
        in image: CGImage,
        mode: OCRRecognitionMode,
        recognitionLanguages: [Locale.Language]
    ) async throws -> RecognizedText {
        modes.append(mode)
        languageHints.append(recognitionLanguages)
        let outcome = outcomes.isEmpty ? .value(.empty) : outcomes.removeFirst()
        switch outcome {
        case .value(let result): return result
        case .failure: throw OCRTestError.expected
        }
    }

    var callCount: Int { modes.count }
}

actor FakeFormulaConverter: FormulaConverting {
    let output: String
    private(set) var callCount = 0

    init(output: String) {
        self.output = output
    }

    func latex(from image: CGImage) async throws -> String {
        callCount += 1
        return output
    }
}

actor BlockingTextRecognizer: TextRecognizing {
    private(set) var callCount = 0

    func recognize(
        in image: CGImage,
        mode: OCRRecognitionMode,
        recognitionLanguages: [Locale.Language]
    ) async throws -> RecognizedText {
        callCount += 1
        try await Task.sleep(for: .seconds(60))
        return RecognizedText(text: "não deve ser inserido", confidence: 1)
    }
}

struct OCRFixedLanguageDetector: LanguageDetecting {
    let language: TranslationLanguage?
    func detect(in text: String) -> TranslationLanguage? { language }
}

@MainActor
enum OCRFixtures {
    static func image(width: Int = 8, height: Int = 8) -> CGImage {
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!.cgImage!
    }

    static func eventually(_ condition: () async -> Bool) async -> Bool {
        for _ in 0..<1_000 {
            if await condition() { return true }
            await Task.yield()
        }
        return false
    }
}
