//
//  LatexTokenizer.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. Whitespace tokenizer backed by latexocr-v1-vocab.json
//  (BOS/EOS wrapping; decode skips specials, joins on " ").
//

import Foundation

nonisolated struct LatexVocab: Decodable, Sendable {
    let idToToken: [String]
    let tokenToId: [String: Int]
    let specialIds: [String: Int]
    let runtimeVocabSize: Int

    enum CodingKeys: String, CodingKey {
        case idToToken = "id_to_token"
        case tokenToId = "token_to_id"
        case specialIds = "special_ids"
        case runtimeVocabSize = "runtime_vocab_size"
    }
}

nonisolated struct LatexTokenizer: Sendable {
    let idToToken: [String]
    let tokenToId: [String: Int]
    let bosId: Int
    let eosId: Int
    let padId: Int
    let unkId: Int
    let vocabSize: Int

    init(vocab url: URL) throws {
        let data = try Data(contentsOf: url)
        let vocab = try JSONDecoder().decode(LatexVocab.self, from: data)
        idToToken = vocab.idToToken
        tokenToId = vocab.tokenToId
        bosId = vocab.specialIds["BOS"] ?? 0
        eosId = vocab.specialIds["EOS"] ?? 1
        padId = vocab.specialIds["PAD"] ?? 2
        unkId = vocab.specialIds["UNK"] ?? (vocab.runtimeVocabSize - 1)
        vocabSize = vocab.runtimeVocabSize
    }

    func encode(_ latex: String, addSpecialTokens: Bool = true) -> [Int] {
        let ids = latex
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .map { tokenToId[String($0)] ?? unkId }
        return addSpecialTokens ? [bosId] + ids + [eosId] : ids
    }

    func decode(_ ids: [Int], skipSpecialTokens: Bool = true) -> String {
        let specials: Set<Int> = [bosId, eosId, padId]
        var tokens: [String] = []
        for id in ids {
            if skipSpecialTokens, specials.contains(id) { continue }
            if id >= 0, id < idToToken.count {
                tokens.append(idToToken[id])
            } else {
                tokens.append("<UNK>")
            }
        }
        return tokens.joined(separator: " ")
    }
}
