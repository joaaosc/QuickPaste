//
//  LatexNormalizer.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. Light, deterministic post-processing of decoded LaTeX: collapse runs
//  of whitespace into single spaces and trim. Idempotent on the tokenizer's single-spaced output.
//  Pure string utility — not an ML feature.
//

import Foundation

nonisolated struct LatexNormalizer: Sendable {
    init() {}

    func normalize(_ latex: String) -> String {
        latex
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .joined(separator: " ")
    }
}
