//
//  CoreAIFormulaRecognizer.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. FormulaRecognitionService backed by Core AI: composes preprocessing +
//  model loading + greedy decoding + tokenizer + normalization. Loads the asset from a local
//  runtime path (never bundled). Adds a `recognize(image:)` entry so it runs straight from an
//  inline CGImage. Gated `#if canImport(CoreAI)`; the #else stub keeps the app + pure tests
//  building when the framework is unavailable.
//

import CoreGraphics
import Foundation

#if canImport(CoreAI)

@available(macOS 27, *)
nonisolated struct CoreAIFormulaRecognizer: FormulaRecognitionService {
    let computeUnit: ComputeUnitSelection
    let sequenceLength: Int
    let locator: RuntimeLocator
    let converter = ImageTensorConverter()
    let normalizer = LatexNormalizer()

    init(
        computeUnit: ComputeUnitSelection = .cpu,
        sequenceLength: Int = 257,
        locator: RuntimeLocator = .resolved()
    ) {
        self.computeUnit = computeUnit
        self.sequenceLength = sequenceLength
        self.locator = locator
    }

    func recognize(imageAt url: URL) async throws -> RecognizedFormula {
        try await recognize(tensor: converter.loadTensor(from: url))
    }

    func recognize(image: CGImage) async throws -> RecognizedFormula {
        try await recognize(tensor: converter.tensor(from: image))
    }

    private func recognize(tensor: ImageTensor) async throws -> RecognizedFormula {
        let tokenizer = try LatexTokenizer(vocab: locator.resolvedVocabURL())
        let (encoder, decoder) = try await CoreAIModelLoader(
            computeUnit: computeUnit, locator: locator
        ).load()

        let backend = CoreAIModel(
            encoder: encoder,
            decoder: decoder,
            memoryCount: 100 * 192,
            sequenceLength: sequenceLength,
            vocabSize: tokenizer.vocabSize
        )
        let greedy = GreedyDecoder(
            sequenceLength: sequenceLength,
            bosId: tokenizer.bosId,
            eosId: tokenizer.eosId,
            padId: tokenizer.padId
        )

        let started = Date()
        let decoded = try await greedy.generate(pixels: tensor.pixels, using: backend)
        let latency = Date().timeIntervalSince(started) * 1000.0
        let latex = normalizer.normalize(tokenizer.decode(decoded.tokenIds, skipSpecialTokens: true))

        return RecognizedFormula(
            latex: latex,
            tokenIds: decoded.tokenIds,
            steps: decoded.steps,
            stoppedOnEOS: decoded.stoppedOnEOS,
            latencyMilliseconds: latency,
            computeUnit: computeUnit
        )
    }
}

#else

nonisolated struct CoreAIFormulaRecognizer: FormulaRecognitionService {
    let computeUnit: ComputeUnitSelection

    init(computeUnit: ComputeUnitSelection = .cpu, sequenceLength: Int = 257) {
        self.computeUnit = computeUnit
    }

    func recognize(imageAt url: URL) async throws -> RecognizedFormula {
        throw RecognitionError.coreAIUnavailable(
            "O framework Core AI não está disponível nesta build (SDK ou Metal Toolchain ausente)."
        )
    }

    func recognize(image: CGImage) async throws -> RecognizedFormula {
        throw RecognitionError.coreAIUnavailable(
            "O framework Core AI não está disponível nesta build (SDK ou Metal Toolchain ausente)."
        )
    }
}

#endif
