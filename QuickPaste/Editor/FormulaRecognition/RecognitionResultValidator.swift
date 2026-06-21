//
//  RecognitionResultValidator.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. Conservative app-layer checks for outputs that should not be
//  presented as recognized LaTeX. Drives the clear "no formula / unusable" message.
//

import Foundation

nonisolated struct RecognitionResultValidator: Sendable {
    enum Outcome: Equatable, Sendable {
        case valid
        case unusable
    }

    static let unusableMessage = "Nenhuma fórmula detectada ou o resultado não é utilizável."

    func validate(_ result: RecognizedFormula) -> Outcome {
        let latex = result.latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard latex.isEmpty == false else { return .unusable }
        guard containsOnlySpecialTokens(result.tokenIds) == false else { return .unusable }
        guard containsInvalidText(latex) == false else { return .unusable }
        guard hasBalancedBraces(latex) else { return .unusable }
        guard looksLikeFormula(latex) else { return .unusable }
        guard containsRepeatedGarbage(result.tokenIds) == false else { return .unusable }
        return .valid
    }

    private func containsOnlySpecialTokens(_ tokenIds: [Int]) -> Bool {
        let specialIds: Set<Int> = [0, 1, 2]
        return tokenIds.isEmpty || tokenIds.allSatisfy(specialIds.contains)
    }

    private func containsInvalidText(_ latex: String) -> Bool {
        let uppercased = latex.uppercased()
        let placeholders = ["<UNK>", "<PAD>", "<BOS>", "<EOS>"]
        return placeholders.contains(where: uppercased.contains)
            || latex.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            || latex.contains("\u{FFFD}")
    }

    private func hasBalancedBraces(_ latex: String) -> Bool {
        var depth = 0
        for character in latex {
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth < 0 { return false }
            }
        }
        return depth == 0
    }

    private func looksLikeFormula(_ latex: String) -> Bool {
        latex.contains("\\") || latex.unicodeScalars.contains {
            CharacterSet.alphanumerics.contains($0)
        }
    }

    private func containsRepeatedGarbage(_ tokenIds: [Int]) -> Bool {
        let contentIds = tokenIds.filter { $0 > 2 }
        guard contentIds.count >= 8 else { return false }

        var runLength = 1
        for index in contentIds.indices.dropFirst() {
            if contentIds[index] == contentIds[contentIds.index(before: index)] {
                runLength += 1
                if runLength >= 8 { return true }
            } else {
                runLength = 1
            }
        }
        return false
    }
}
