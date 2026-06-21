//
//  ResourceLocator.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported & adapted from LatexOCRlab for the sandboxed app. Resolves the on-disk model directory.
//  Resolution order for the .aimodel: the app's Application Support **container** first (the
//  shippable, sandbox-legal location), then an optional `$LATEXOCR_RUNTIME_DIR` dev override.
//  The tokenizer vocab is bundled in the app, so it resolves from `Bundle.main` first. The
//  .aimodel is never bundled or committed; a missing asset surfaces RuntimeResourceError.assetMissing.
//

import Foundation

nonisolated struct RuntimeLocator: Sendable {
    static let environmentKey = "LATEXOCR_RUNTIME_DIR"
    static let assetRelativePath = "coreai/latexocr-v1/LatexOCR.aimodel"
    static let vocabRelativePath = "tokenizer/latexocr-v1-vocab.json"
    static let bundledVocabName = "latexocr-v1-vocab"

    let modelsDirectory: URL

    init(modelsDirectory: URL) {
        self.modelsDirectory = modelsDirectory
    }

    var assetURL: URL { modelsDirectory.appendingPathComponent(Self.assetRelativePath) }
    var vocabURL: URL { modelsDirectory.appendingPathComponent(Self.vocabRelativePath) }

    func resolvedAssetURL() throws -> URL {
        let candidates = Self.candidateModelDirectories()
        for directory in candidates {
            let candidate = directory.appendingPathComponent(Self.assetRelativePath)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        throw RuntimeResourceError.assetMissing(
            searched: candidates.map { $0.appendingPathComponent(Self.assetRelativePath).path }
        )
    }

    func resolvedVocabURL() throws -> URL {
        // The vocab ships inside the app bundle, so it's the first and normal source.
        if let bundled = Bundle.main.url(forResource: Self.bundledVocabName, withExtension: "json") {
            return bundled
        }
        for directory in Self.candidateModelDirectories() {
            let candidate = directory.appendingPathComponent(Self.vocabRelativePath)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        throw RuntimeResourceError.vocabMissing(vocabURL)
    }

    static func resolved() -> RuntimeLocator {
        RuntimeLocator(modelsDirectory: candidateModelDirectories().first ?? applicationSupportModelsDirectory())
    }

    /// Application Support container first (sandbox-resolved), then an optional dev override.
    static func candidateModelDirectories() -> [URL] {
        var directories: [URL] = [applicationSupportModelsDirectory()]
        if let override = ProcessInfo.processInfo.environment[environmentKey], override.isEmpty == false {
            directories.append(URL(fileURLWithPath: override, isDirectory: true))
        }
        return directories
    }

    /// `<App Support>/QuickPaste`. Under the sandbox this resolves inside the app's container.
    static func applicationSupportModelsDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        )) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("QuickPaste", isDirectory: true)
    }
}
