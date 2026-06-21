//
//  RecognizedFormula.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. Domain result of one recognition. Plain value type; UI binds to
//  this, never to tensors.
//

import Foundation

nonisolated struct RecognizedFormula: Sendable, Equatable {
    let latex: String
    let tokenIds: [Int]
    let steps: Int
    let stoppedOnEOS: Bool
    let latencyMilliseconds: Double
    let computeUnit: ComputeUnitSelection

    init(
        latex: String,
        tokenIds: [Int],
        steps: Int,
        stoppedOnEOS: Bool,
        latencyMilliseconds: Double,
        computeUnit: ComputeUnitSelection
    ) {
        self.latex = latex
        self.tokenIds = tokenIds
        self.steps = steps
        self.stoppedOnEOS = stoppedOnEOS
        self.latencyMilliseconds = latencyMilliseconds
        self.computeUnit = computeUnit
    }
}
