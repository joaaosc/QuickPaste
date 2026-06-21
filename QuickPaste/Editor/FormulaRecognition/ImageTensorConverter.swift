//
//  ImageTensorConverter.swift
//  QuickPaste — Editor/FormulaRecognition
//
//  Ported from LatexOCRlab. CGImage -> Float32 CHW [1,3,160,640] in [0,1] (min-ratio fit,
//  center on white 640x160, /255). `tensor(from: CGImage)` lets the converter run from an inline
//  attachment image without writing to disk.
//

import CoreGraphics
import Foundation
import ImageIO

nonisolated struct ImageTensor: Sendable {
    let pixels: [Float] // CHW: 3 * 160 * 640
    let channels: Int
    let height: Int
    let width: Int
}

nonisolated struct ImageTensorConverter: Sendable {
    static let width = 640
    static let height = 160
    static let channels = 3

    init() {}

    func loadTensor(from url: URL) throws -> ImageTensor {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw RecognitionError.imageDecodingFailed(url)
        }
        return tensor(from: image)
    }

    func tensor(from image: CGImage) -> ImageTensor {
        let targetW = Self.width
        let targetH = Self.height
        let srcW = max(1, image.width)
        let srcH = max(1, image.height)

        let scale = min(Double(targetW) / Double(srcW), Double(targetH) / Double(srcH))
        let resizedW = max(1, min(targetW, Int((Double(srcW) * scale).rounded())))
        let resizedH = max(1, min(targetH, Int((Double(srcH) * scale).rounded())))
        let offsetX = (targetW - resizedW) / 2
        let offsetYTop = (targetH - resizedH) / 2 // top-left origin, like PIL

        let bytesPerRow = targetW * 4
        var buffer = [UInt8](repeating: 255, count: bytesPerRow * targetH)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        buffer.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: targetW,
                height: targetH,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return }
            context.interpolationQuality = .high
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: targetW, height: targetH))
            let cgY = targetH - offsetYTop - resizedH // CG origin is bottom-left
            context.draw(image, in: CGRect(x: offsetX, y: cgY, width: resizedW, height: resizedH))
        }

        let plane = targetW * targetH
        var pixels = [Float](repeating: 0, count: Self.channels * plane)
        for row in 0..<targetH {
            let bufferRow = targetH - 1 - row // tensor row 0 = top
            let rowBase = bufferRow * bytesPerRow
            for col in 0..<targetW {
                let px = rowBase + col * 4
                let idx = row * targetW + col
                pixels[idx] = Float(buffer[px]) / 255.0
                pixels[plane + idx] = Float(buffer[px + 1]) / 255.0
                pixels[2 * plane + idx] = Float(buffer[px + 2]) / 255.0
            }
        }
        return ImageTensor(pixels: pixels, channels: Self.channels, height: targetH, width: targetW)
    }
}
