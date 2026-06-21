//
//  TokenModel.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. Numeric model boundary used by the greedy decoder, in plain Swift
//  arrays so the loop is testable with a fake (no Core AI). `memory` is the flat encoder output
//  (100*192); `decodeLogitsRow` returns the vocab-sized logits at one decoder position.
//

nonisolated protocol TokenModel: Sendable {
    func encodeMemory(pixels: [Float]) async throws -> [Float]
    func decodeLogitsRow(ids: [Int32], memory: [Float], at position: Int) async throws -> [Float]
}
