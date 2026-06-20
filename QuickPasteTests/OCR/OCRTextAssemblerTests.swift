import CoreGraphics
import Testing
@testable import QuickPaste

struct OCRTextAssemblerTests {
    @Test("Blocks sort top-down, then left-right")
    func readingOrder() {
        let blocks = [
            OCRTextBlock(text: "bottom", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.1)),
            OCRTextBlock(text: "right", confidence: 1, boundingBox: CGRect(x: 0.6, y: 0.8, width: 0.3, height: 0.1)),
            OCRTextBlock(text: "left", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.81, width: 0.3, height: 0.1)),
        ]

        #expect(OCRTextAssembler.orderedBlocks(blocks).map(\.text) == ["left", "right", "bottom"])
    }

    @Test("Post-processing normalizes whitespace, preserves paragraphs, and weights confidence")
    func postProcessing() {
        let result = OCRTextAssembler.result(from: [
            OCRTextBlock(
                text: "  Olá   mundo  ",
                confidence: 0.5,
                boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.7, height: 0.1),
                paragraphIndex: 0
            ),
            OCRTextBlock(
                text: "segunda linha",
                confidence: 1,
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.7, height: 0.1),
                paragraphIndex: 1
            ),
        ])

        #expect(result.text == "Olá mundo\n\nsegunda linha")
        #expect(result.blocks.map(\.text) == ["Olá mundo", "segunda linha"])
        #expect(abs(result.confidence - 0.8) < 0.000_001)
    }
}
