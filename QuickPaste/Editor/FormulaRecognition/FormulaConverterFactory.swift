//
//  FormulaConverterFactory.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Builds the app-facing `FormulaConverting` seam for injection into `EditorModel`. Returns nil
//  when the platform can't run the Core AI model (macOS < 27 or CoreAI unavailable), so the
//  "Converter fórmula para LaTeX" action stays hidden. A missing on-disk asset is *not* handled
//  here — that surfaces at use time as an install message, since it is user-fixable.
//

import Foundation

nonisolated enum FormulaConverterFactory {
    static func make(computeUnit: ComputeUnitSelection = .cpu) -> (any FormulaConverting)? {
        #if canImport(CoreAI)
        if #available(macOS 27, *) {
            return CoreAIFormulaConverter(computeUnit: computeUnit)
        }
        #endif
        return nil
    }
}
