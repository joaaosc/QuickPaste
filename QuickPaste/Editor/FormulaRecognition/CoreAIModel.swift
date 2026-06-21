//
//  CoreAIModel.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. TokenModel backed by Core AI inference functions. Inputs/outputs
//  cross the boundary as flat [Float]/[Int32]; int32 ids satisfy the Core AI runtime requirement.
//  memory is [1,100,192], logits [1,257,580]. Gated `#if canImport(CoreAI)` + `@available`.
//

import Foundation

#if canImport(CoreAI)
import CoreAI

@available(macOS 27, *)
nonisolated struct CoreAIModel: TokenModel {
    let encoder: InferenceFunction
    let decoder: InferenceFunction
    let memoryCount: Int
    let sequenceLength: Int
    let vocabSize: Int

    func encodeMemory(pixels: [Float]) async throws -> [Float] {
        let images = NDArray(scalars: pixels, shape: [1, 3, 160, 640])
        var outputs = try await encoder.run(inputs: ["images": images])
        guard let value = outputs.remove("memory") else {
            throw RecognitionError.coreAIUnavailable("encoder produced no 'memory' output")
        }
        return try Self.copyFloats(from: value, count: memoryCount)
    }

    func decodeLogitsRow(ids: [Int32], memory: [Float], at position: Int) async throws -> [Float] {
        let idsArray = NDArray(scalars: ids, shape: [1, sequenceLength])
        let memoryArray = NDArray(scalars: memory, shape: [1, 100, 192])
        var outputs = try await decoder.run(
            inputs: ["decoder_input_ids": idsArray, "memory": memoryArray]
        )
        guard let value = outputs.remove("logits") else {
            throw RecognitionError.coreAIUnavailable("decoder produced no 'logits' output")
        }
        let logits = try Self.copyFloats(from: value, count: sequenceLength * vocabSize)
        let start = position * vocabSize
        return Array(logits[start ..< start + vocabSize])
    }

    static func copyFloats(from value: consuming InferenceValue, count: Int) throws -> [Float] {
        guard let array = value.ndArray else {
            throw RecognitionError.coreAIUnavailable("output value is not an NDArray")
        }
        var result = [Float](repeating: 0, count: count)
        let view = array.view(as: Float.self)
        view.withUnsafePointer { pointer, _, _ in
            result.withUnsafeMutableBufferPointer { destination in
                if let base = destination.baseAddress {
                    base.update(from: pointer, count: count)
                }
            }
        }
        return result
    }
}
#endif
