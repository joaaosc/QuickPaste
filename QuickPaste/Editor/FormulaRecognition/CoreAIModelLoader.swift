//
//  CoreAIModelLoader.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. Loads + specializes the on-disk LatexOCR.aimodel (CPU by default)
//  and resolves its two named inference functions. The specialized AIModel can be released once
//  the functions are loaded. Gated `#if canImport(CoreAI)` + `@available`.
//

import Foundation

#if canImport(CoreAI)
import CoreAI

@available(macOS 27, *)
nonisolated struct CoreAIModelLoader {
    let computeUnit: ComputeUnitSelection
    let locator: RuntimeLocator

    func load() async throws -> (encoder: InferenceFunction, decoder: InferenceFunction) {
        let assetURL = try locator.resolvedAssetURL()
        let options = SpecializationOptions(preferredComputeUnitKind: Self.kind(for: computeUnit))
        let model = try await AIModel(contentsOf: assetURL, options: options)
        guard
            let encoder = try model.loadFunction(named: "encoder"),
            let decoder = try model.loadFunction(named: "decoder")
        else {
            throw RecognitionError.coreAIUnavailable("asset is missing encoder/decoder entrypoints")
        }
        return (encoder, decoder)
    }

    static func kind(for unit: ComputeUnitSelection) -> ComputeUnitKind {
        switch unit {
        case .cpu: return .cpu
        case .gpu: return .gpu
        case .neuralEngine: return .neuralEngine
        case .automatic: return .cpu // deterministic, headless-safe default
        }
    }
}
#endif
