//
//  CoreAIFormulaConverter.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Adapts the ported Core AI runtime to the app-facing `FormulaConverting` seam (Editor/OCR).
//  Runs the recognizer from an inline CGImage, validates the output, and throws a typed
//  `noFormula` when the result is unusable — so `EditorModel` can surface a clear message.
//  `@available(macOS 27, *)`; the factory only builds it when Core AI can actually run.
//

import CoreGraphics
import Foundation

#if canImport(CoreAI)

@available(macOS 27, *)
nonisolated struct CoreAIFormulaConverter: FormulaConverting {
    let recognizer: CoreAIFormulaRecognizer
    let validator = RecognitionResultValidator()

    init(computeUnit: ComputeUnitSelection = .cpu, locator: RuntimeLocator = .resolved()) {
        recognizer = CoreAIFormulaRecognizer(computeUnit: computeUnit, locator: locator)
    }

    func latex(from image: CGImage) async throws -> String {
        let result = try await recognizer.recognize(image: image)
        guard validator.validate(result) == .valid else {
            throw RecognitionError.noFormula
        }
        return result.latex
    }
}

#endif
