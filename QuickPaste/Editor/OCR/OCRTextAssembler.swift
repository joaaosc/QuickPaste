import CoreGraphics
import Foundation

/// Pure OCR post-processing: normalizes lines, restores reading order, and computes confidence.
nonisolated enum OCRTextAssembler {
    static func result(from rawBlocks: [OCRTextBlock]) -> RecognizedText {
        let blocks = orderedBlocks(rawBlocks.compactMap(normalizedBlock))
        guard blocks.isEmpty == false else { return .empty }

        var text = blocks[0].text
        for index in 1..<blocks.count {
            let previous = blocks[index - 1]
            let current = blocks[index]
            text += separator(after: previous, before: current) + current.text
        }

        let weighted = blocks.reduce(into: (confidence: 0.0, characters: 0)) { partial, block in
            let characters = block.text.filter { $0.isWhitespace == false }.count
            partial.confidence += block.confidence * Double(characters)
            partial.characters += characters
        }
        let confidence = weighted.characters > 0
            ? weighted.confidence / Double(weighted.characters)
            : 0
        return RecognizedText(text: text, confidence: confidence, blocks: blocks)
    }

    static func orderedBlocks(_ blocks: [OCRTextBlock]) -> [OCRTextBlock] {
        blocks.sorted { lhs, rhs in
            let verticalDistance = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
            let sameLineTolerance = max(lhs.boundingBox.height, rhs.boundingBox.height) * 0.5
            if verticalDistance <= sameLineTolerance {
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            return lhs.boundingBox.midY > rhs.boundingBox.midY
        }
    }

    private static func normalizedBlock(_ block: OCRTextBlock) -> OCRTextBlock? {
        let normalized = block.text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard normalized.isEmpty == false else { return nil }
        return OCRTextBlock(
            text: normalized,
            confidence: min(max(block.confidence, 0), 1),
            boundingBox: block.boundingBox,
            paragraphIndex: block.paragraphIndex
        )
    }

    private static func separator(after previous: OCRTextBlock, before current: OCRTextBlock) -> String {
        if let previousParagraph = previous.paragraphIndex,
           let currentParagraph = current.paragraphIndex,
           previousParagraph != currentParagraph {
            return "\n\n"
        }

        let verticalGap = previous.boundingBox.minY - current.boundingBox.maxY
        let significantGap = max(previous.boundingBox.height, current.boundingBox.height) * 0.8
        return verticalGap > significantGap ? "\n\n" : "\n"
    }
}
