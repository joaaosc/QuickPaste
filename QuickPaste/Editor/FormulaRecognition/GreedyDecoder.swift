//
//  GreedyDecoder.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. Fixed-length greedy decode matching the validated reference. The
//  Core AI decoder has a fixed [1,257] input, so we keep a PAD-filled int32 buffer, place BOS at
//  index 0, and read logits[length-1] (causal masking makes positions >= length irrelevant).
//  int32 ids satisfy the Core AI runtime boundary. Pure Swift — testable with a fake TokenModel.
//

nonisolated struct GreedyDecoder: Sendable {
    let sequenceLength: Int
    let bosId: Int32
    let eosId: Int32
    let padId: Int32

    init(sequenceLength: Int, bosId: Int, eosId: Int, padId: Int) {
        self.sequenceLength = sequenceLength
        self.bosId = Int32(bosId)
        self.eosId = Int32(eosId)
        self.padId = Int32(padId)
    }

    func generate(pixels: [Float], using model: TokenModel) async throws -> GreedyDecodeResult {
        let memory = try await model.encodeMemory(pixels: pixels)
        var ids = [Int32](repeating: padId, count: sequenceLength)
        ids[0] = bosId
        var generated: [Int] = []
        var stoppedOnEOS = false
        var length = 1
        while length < sequenceLength {
            let logits = try await model.decodeLogitsRow(ids: ids, memory: memory, at: length - 1)
            let next = Int32(Self.argmax(logits))
            generated.append(Int(next))
            if next == eosId { stoppedOnEOS = true; break }
            ids[length] = next
            length += 1
        }
        return GreedyDecodeResult(tokenIds: generated, stoppedOnEOS: stoppedOnEOS, steps: generated.count)
    }

    /// First-occurrence argmax, matching numpy's `argmax` tie-breaking.
    static func argmax(_ values: [Float]) -> Int {
        var bestIndex = 0
        var bestValue = -Float.greatestFiniteMagnitude
        for (index, value) in values.enumerated() where value > bestValue {
            bestValue = value
            bestIndex = index
        }
        return bestIndex
    }
}
