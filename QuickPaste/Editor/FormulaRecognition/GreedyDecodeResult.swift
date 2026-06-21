//
//  GreedyDecodeResult.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab.
//

nonisolated struct GreedyDecodeResult: Sendable, Equatable {
    let tokenIds: [Int]
    let stoppedOnEOS: Bool
    let steps: Int

    init(tokenIds: [Int], stoppedOnEOS: Bool, steps: Int) {
        self.tokenIds = tokenIds
        self.stoppedOnEOS = stoppedOnEOS
        self.steps = steps
    }
}
