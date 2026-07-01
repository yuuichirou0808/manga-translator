import AppKit
import CoreGraphics
import Foundation
import PDFKit

enum PDFPageRendererError: LocalizedError {
    case invalidPageSize
    case cannotCreateContext
    case cannotCreateImage

    var errorDescription: String? {
        switch self {
        case .invalidPageSize:
            return "PDF 页面尺寸无效。"
        case .cannotCreateContext:
            return "无法创建 PDF 渲染上下文。"
        case .cannotCreateImage:
            return "无法生成页面图像。"
        }
    }
}

struct RenderedPDFPage {
    var image: CGImage
    var pageBounds: CGRect
    var scale: CGFloat

    func pageRect(for normalizedRect: CGRect) -> CGRect {
        CGRect(
            x: pageBounds.minX + normalizedRect.minX * pageBounds.width,
            y: pageBounds.minY + normalizedRect.minY * pageBounds.height,
            width: normalizedRect.width * pageBounds.width,
            height: normalizedRect.height * pageBounds.height
        )
    }
}

final class PDFPageRenderer {
    func render(page: PDFPage, scale: CGFloat = 2.0) throws -> RenderedPDFPage {
        let bounds = page.bounds(for: .cropBox)
        guard bounds.width > 0, bounds.height > 0 else {
            throw PDFPageRendererError.invalidPageSize
        }

        let width = max(1, Int((bounds.width * scale).rounded(.up)))
        let height = max(1, Int((bounds.height * scale).rounded(.up)))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw PDFPageRendererError.cannotCreateContext
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
        page.draw(with: .cropBox, to: context)
        context.restoreGState()

        guard let image = context.makeImage() else {
            throw PDFPageRendererError.cannotCreateImage
        }

        return RenderedPDFPage(image: image, pageBounds: bounds, scale: scale)
    }
}
