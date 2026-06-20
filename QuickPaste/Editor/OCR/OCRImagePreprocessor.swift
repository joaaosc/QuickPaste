import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Vision

nonisolated enum OCRPreprocessingError: LocalizedError, Sendable {
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed: "Não foi possível preparar a imagem para OCR."
        }
    }
}

/// Detects document perspective, corrects it, then performs a bounded Lanczos upscale.
actor VisionOCRImagePreprocessor: ImagePreprocessing {
    var targetLongEdge = 1_600
    var maximumLongEdge = 2_400
    var maximumScale = 3.0
    var minimumDocumentCoverage = 0.2

    func prepare(_ image: CGImage) async throws -> OCRPreparedImage {
        var ciImage = CIImage(cgImage: image)
        var mode = OCRRecognitionMode.general

        let document = try await DetectDocumentSegmentationRequest().perform(on: image)
        try Task.checkCancellation()
        if let document,
           document.boundingBox.width * document.boundingBox.height >= minimumDocumentCoverage {
            ciImage = correctedDocument(ciImage, observation: document)
            mode = .document
        }

        ciImage = upscaledIfNeeded(ciImage)
        let extent = ciImage.extent.integral
        guard extent.isEmpty == false,
              let rendered = CIContext(options: [.cacheIntermediates: false]).createCGImage(ciImage, from: extent)
        else { throw OCRPreprocessingError.renderFailed }

        try Task.checkCancellation()
        return OCRPreparedImage(image: rendered, mode: mode)
    }

    private func correctedDocument(
        _ image: CIImage,
        observation: DetectedDocumentObservation
    ) -> CIImage {
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = image
        filter.topLeft = imagePoint(observation.topLeft, in: image.extent)
        filter.topRight = imagePoint(observation.topRight, in: image.extent)
        filter.bottomLeft = imagePoint(observation.bottomLeft, in: image.extent)
        filter.bottomRight = imagePoint(observation.bottomRight, in: image.extent)
        filter.crop = true
        return filter.outputImage ?? image
    }

    private func upscaledIfNeeded(_ image: CIImage) -> CIImage {
        let currentLongEdge = max(image.extent.width, image.extent.height)
        guard currentLongEdge > 0, currentLongEdge < CGFloat(targetLongEdge) else { return image }

        let requestedScale = CGFloat(targetLongEdge) / currentLongEdge
        let maximumEdgeScale = CGFloat(maximumLongEdge) / currentLongEdge
        let scale = min(CGFloat(maximumScale), requestedScale, maximumEdgeScale)
        guard scale > 1.05 else { return image }

        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(scale)
        filter.aspectRatio = 1
        return filter.outputImage ?? image
    }

    private func imagePoint(_ point: NormalizedPoint, in extent: CGRect) -> CGPoint {
        CGPoint(
            x: extent.minX + point.x * extent.width,
            y: extent.minY + point.y * extent.height
        )
    }
}
