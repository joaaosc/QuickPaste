//
//  RecognitionError.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. User-facing errors for resource location and recognition.
//  `assetMissing` carries the actionable install instructions shown when the local .aimodel
//  (never bundled or committed) can't be found. Messages are Portuguese to match the app.
//

import Foundation

nonisolated enum RuntimeResourceError: LocalizedError {
    case assetMissing(searched: [String])
    case vocabMissing(URL)

    var errorDescription: String? {
        switch self {
        case let .assetMissing(searched):
            return """
            O modelo LatexOCR.aimodel não foi encontrado. O QuickPaste carrega este modelo de um \
            caminho local — ele nunca é embutido no app nem versionado.

            Procurado em:
            \(searched.map { "  • \($0)" }.joined(separator: "\n"))

            Como resolver: copie o pacote LatexOCR.aimodel para:
              ~/Library/Containers/com.joaaosc.QuickPaste/Data/Library/Application Support/\
            QuickPaste/coreai/latexocr-v1/LatexOCR.aimodel
            e tente novamente.
            """
        case let .vocabMissing(url):
            return "Vocabulário do tokenizer não encontrado em \(url.path)."
        }
    }
}

nonisolated enum RecognitionError: LocalizedError {
    case imageDecodingFailed(URL)
    case coreAIUnavailable(String)
    /// The decoded output is empty or did not pass the result validator.
    case noFormula

    var errorDescription: String? {
        switch self {
        case let .imageDecodingFailed(url):
            return "Não foi possível decodificar a imagem em \(url.path)."
        case let .coreAIUnavailable(reason):
            return "O runtime do Core AI está indisponível: \(reason)"
        case .noFormula:
            return "Nenhuma fórmula detectada ou o resultado não é utilizável."
        }
    }
}
