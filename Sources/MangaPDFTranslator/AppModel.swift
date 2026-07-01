import Combine
import CoreGraphics
import Foundation
import PDFKit

@MainActor
final class AppModel: ObservableObject {
    @Published var document: PDFDocument?
    @Published var documentURL: URL?
    @Published var isTranslating = false
    @Published var statusMessage = "打开 PDF 后即可拖选文字翻译。"

    // Live Text state.
    @Published var liveTextPageIndex = 0
    @Published var liveTextImage: CGImage?
    @Published var liveTextSelected = ""
    @Published var liveTextTranslation = ""
    private var resetLiveTextOriginalOnCommit = false

    let settings: AppSettings

    private let renderer = PDFPageRenderer()
    private let translator = ChatCompletionTranslator()

    init(settings: AppSettings) {
        self.settings = settings
    }

    var hasDocument: Bool {
        document != nil
    }

    func openPDF(_ url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let loadedDocument = PDFDocument(url: url) else {
            statusMessage = "无法打开 PDF。"
            return
        }

        document = loadedDocument
        documentURL = url
        liveTextPageIndex = 0
        liveTextSelected = ""
        liveTextTranslation = ""
        resetLiveTextOriginalOnCommit = false
        statusMessage = "已打开 \(url.lastPathComponent)。"
        renderLiveTextSpread()
    }

    // MARK: - Navigation

    var liveTextPageTitle: String {
        guard let document, document.pageCount > 0 else { return "未打开 PDF" }
        let start = liveTextPageIndex
        let end = min(start + 1, document.pageCount - 1)
        if start == end {
            return "第 \(start + 1) / \(document.pageCount) 页"
        }
        return "第 \(start + 1)-\(end + 1) / \(document.pageCount) 页"
    }

    var canLiveTextPrevious: Bool {
        document != nil && liveTextPageIndex > 0
    }

    var canLiveTextNext: Bool {
        guard let document else { return false }
        return liveTextPageIndex + 2 < document.pageCount
    }

    func liveTextGoPrevious() {
        guard canLiveTextPrevious else { return }
        liveTextPageIndex = max(0, liveTextPageIndex - 2)
        renderLiveTextSpread()
    }

    func liveTextGoNext() {
        guard let document, canLiveTextNext else { return }
        let maxStart = spreadStart(for: max(0, document.pageCount - 1))
        liveTextPageIndex = min(maxStart, liveTextPageIndex + 2)
        renderLiveTextSpread()
    }

    // MARK: - Selection & translation

    /// Called when a Live Text selection gesture finishes. Until the current
    /// original is translated, each new selection is appended instead of
    /// replacing what's there.
    func commitLiveTextSelection(_ piece: String) {
        let text = piece.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if resetLiveTextOriginalOnCommit || liveTextSelected.isEmpty {
            liveTextSelected = text
        } else {
            liveTextSelected += text
        }
        resetLiveTextOriginalOnCommit = false
    }

    /// Manual edits to the original text box.
    func updateLiveTextOriginal(_ text: String) {
        liveTextSelected = text
        resetLiveTextOriginalOnCommit = false
    }

    /// Removes every line break from the current original text.
    func removeLiveTextNewlines() {
        guard !liveTextSelected.isEmpty else { return }
        liveTextSelected = String(liveTextSelected.unicodeScalars.filter { !CharacterSet.newlines.contains($0) })
        resetLiveTextOriginalOnCommit = false
    }

    func translateLiveText(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = "未选择文字。"
            return
        }

        liveTextSelected = text
        isTranslating = true
        statusMessage = "正在翻译所选..."
        let snapshot = settings.snapshot()

        Task {
            do {
                let translated = try await translate(text, settings: snapshot)
                await MainActor.run {
                    liveTextTranslation = translated
                    statusMessage = "翻译完成。"
                    isTranslating = false
                    // Next selection starts a fresh original instead of appending.
                    resetLiveTextOriginalOnCommit = true
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    isTranslating = false
                }
            }
        }
    }

    private func translate(_ text: String, settings: AppSettingsSnapshot) async throws -> String {
        try await translator.translate(text, settings: settings)
    }

    // MARK: - Rendering

    private func renderLiveTextSpread() {
        guard let document, document.pageCount > 0 else {
            liveTextImage = nil
            return
        }
        liveTextSelected = ""
        liveTextTranslation = ""
        resetLiveTextOriginalOnCommit = false

        let start = liveTextPageIndex
        // Manga reads right-to-left: the lower page index is on the right.
        let indices = [start, start + 1].filter { $0 >= 0 && $0 < document.pageCount }
        do {
            var images: [CGImage] = []
            for index in indices {
                if let page = document.page(at: index) {
                    images.append(try renderer.render(page: page, scale: 2.0).image)
                }
            }
            liveTextImage = Self.composeSpread(images)
        } catch {
            liveTextImage = nil
            statusMessage = error.localizedDescription
        }
    }

    /// Composes pages `[rightPage, leftPage]` into one image laid out
    /// left-to-right as `leftPage | rightPage` for right-to-left manga reading.
    private static func composeSpread(_ images: [CGImage]) -> CGImage? {
        guard let right = images.first else { return nil }
        guard images.count > 1 else { return right }
        let left = images[1]

        let width = left.width + right.width
        let height = max(left.height, right.height)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return right
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Top-aligned; bottom-left origin context, so y = height - imageHeight.
        context.draw(left, in: CGRect(x: 0, y: height - left.height, width: left.width, height: left.height))
        context.draw(right, in: CGRect(x: left.width, y: height - right.height, width: right.width, height: right.height))
        return context.makeImage()
    }

    private func spreadStart(for pageIndex: Int) -> Int {
        max(0, pageIndex - (pageIndex % 2))
    }
}
