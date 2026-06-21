//
//  FormulaRecognitionService.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. Internal recognition boundary, implemented by the Core AI adapter
//  and by fakes in tests. The app-facing seam is `FormulaConverting` (Editor/OCR); this protocol
//  stays inside the module.
//

import CoreGraphics
import Foundation

nonisolated protocol FormulaRecognitionService: Sendable {
    func recognize(imageAt url: URL) async throws -> RecognizedFormula
    func recognize(image: CGImage) async throws -> RecognizedFormula
}
