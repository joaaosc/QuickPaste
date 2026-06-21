//
//  ComputeUnitSelection.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. Compute unit the runner requests. Default `.cpu` matches the
//  validated reference; preserve CPU specialization for now.
//

nonisolated enum ComputeUnitSelection: String, Sendable {
    case cpu
    case gpu
    case neuralEngine
    case automatic
}
