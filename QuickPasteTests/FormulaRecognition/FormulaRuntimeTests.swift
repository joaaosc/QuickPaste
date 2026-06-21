import Foundation
import Testing
@testable import QuickPaste

/// A scripted TokenModel: emits a fixed argmax token at each decoder position. No Core AI, so the
/// greedy loop is fully deterministic.
private struct ScriptedTokenModel: TokenModel {
    let scriptedArgmax: [Int]
    let vocabSize: Int

    func encodeMemory(pixels: [Float]) async throws -> [Float] { [0] }

    func decodeLogitsRow(ids: [Int32], memory: [Float], at position: Int) async throws -> [Float] {
        var logits = [Float](repeating: 0, count: vocabSize)
        let id = position < scriptedArgmax.count ? scriptedArgmax[position] : (vocabSize - 1)
        logits[id] = 1
        return logits
    }
}

struct GreedyDecoderTests {
    @Test("greedy decode stops on EOS and includes the emitted ids")
    func stopsOnEOS() async throws {
        let model = ScriptedTokenModel(scriptedArgmax: [5, 6, 7, 1], vocabSize: 10)
        let decoder = GreedyDecoder(sequenceLength: 257, bosId: 0, eosId: 1, padId: 2)

        let result = try await decoder.generate(pixels: [], using: model)

        #expect(result.tokenIds == [5, 6, 7, 1])
        #expect(result.stoppedOnEOS)
        #expect(result.steps == 4)
    }

    @Test("greedy decode caps at the fixed sequence length without EOS")
    func capsWithoutEOS() async throws {
        // Falls back to vocabSize-1 (never EOS=1), so the loop fills positions 1..256.
        let model = ScriptedTokenModel(scriptedArgmax: [], vocabSize: 6)
        let decoder = GreedyDecoder(sequenceLength: 257, bosId: 0, eosId: 1, padId: 2)

        let result = try await decoder.generate(pixels: [], using: model)

        #expect(result.stoppedOnEOS == false)
        #expect(result.steps == 256)
        #expect(result.tokenIds.count == 256)
    }

    @Test("argmax returns the first-occurrence index")
    func argmaxFirstOccurrence() {
        #expect(GreedyDecoder.argmax([0.1, 0.9, 0.9, 0.2]) == 1)
    }
}

struct LatexTokenizerTests {
    private func writeVocab() throws -> URL {
        let json = """
        {
          "id_to_token": ["<BOS>", "<EOS>", "<PAD>", "a", "b", "<UNK>"],
          "token_to_id": {"<BOS>": 0, "<EOS>": 1, "<PAD>": 2, "a": 3, "b": 4, "<UNK>": 5},
          "special_ids": {"BOS": 0, "EOS": 1, "PAD": 2, "UNK": 5},
          "runtime_vocab_size": 6
        }
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vocab-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        return url
    }

    @Test("encode wraps with BOS/EOS and maps unknown tokens to UNK")
    func encodeWrapsAndMapsUnknown() throws {
        let tokenizer = try LatexTokenizer(vocab: writeVocab())
        #expect(tokenizer.encode("a b") == [0, 3, 4, 1])
        #expect(tokenizer.encode("a z") == [0, 3, 5, 1]) // z → UNK(5)
        #expect(tokenizer.vocabSize == 6)
    }

    @Test("decode skips special tokens and joins on spaces")
    func decodeSkipsSpecials() throws {
        let tokenizer = try LatexTokenizer(vocab: writeVocab())
        #expect(tokenizer.decode([0, 3, 4, 1], skipSpecialTokens: true) == "a b")
        #expect(tokenizer.decode([3, 4], skipSpecialTokens: false) == "a b")
    }
}

@MainActor
struct ImageTensorConverterTests {
    @Test("tensor has CHW [3,160,640] shape in [0,1]")
    func tensorShape() {
        let tensor = ImageTensorConverter().tensor(from: OCRFixtures.image(width: 32, height: 8))
        #expect(tensor.channels == 3)
        #expect(tensor.height == 160)
        #expect(tensor.width == 640)
        #expect(tensor.pixels.count == 3 * 160 * 640)
        #expect(tensor.pixels.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
}

struct RecognitionResultValidatorTests {
    private func formula(_ latex: String, tokenIds: [Int] = [3, 4, 5]) -> RecognizedFormula {
        RecognizedFormula(
            latex: latex, tokenIds: tokenIds, steps: tokenIds.count,
            stoppedOnEOS: true, latencyMilliseconds: 0, computeUnit: .cpu
        )
    }

    @Test("accepts a plausible formula")
    func acceptsValid() {
        #expect(RecognitionResultValidator().validate(formula("E = m c ^ 2")) == .valid)
    }

    @Test("rejects empty, special-only, unbalanced, placeholder, and repeated-garbage output")
    func rejectsUnusable() {
        let validator = RecognitionResultValidator()
        #expect(validator.validate(formula("")) == .unusable)
        #expect(validator.validate(formula("x", tokenIds: [0, 1, 2])) == .unusable)
        #expect(validator.validate(formula("\\frac { 1 } { 2")) == .unusable) // unbalanced braces
        #expect(validator.validate(formula("<UNK>")) == .unusable)
        #expect(validator.validate(formula("x", tokenIds: Array(repeating: 9, count: 8))) == .unusable)
    }
}

struct LatexNormalizerTests {
    @Test("collapses whitespace runs and trims")
    func collapsesWhitespace() {
        #expect(LatexNormalizer().normalize("  a   b \n c ") == "a b c")
    }
}
