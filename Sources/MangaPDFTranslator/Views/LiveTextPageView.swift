import AppKit
import SwiftUI
import VisionKit

/// Hosts a page image with VisionKit's Live Text overlay (`ImageAnalysisOverlayView`)
/// — the same selectable-text pipeline as Quick Look / Preview. The user drags
/// to select text; each finished selection is committed to the original box, and
/// a configurable shortcut translates it.
///
/// Reading the selection programmatically (`selectedText`) requires macOS 14,
/// which is the app's deployment target.
struct LiveTextPageView: NSViewRepresentable {
    var image: CGImage?
    /// Identifies the current page so analysis only re-runs when the page changes.
    var pageToken: Int
    var translateShortcut: KeyShortcut
    var removeNewlinesShortcut: KeyShortcut
    /// Called when a selection gesture finishes, with the final selected text.
    var onCommitSelection: (String) -> Void
    /// Called when the translate shortcut is pressed.
    var onTranslate: () -> Void
    /// Called when the remove-newlines shortcut is pressed.
    var onRemoveNewlines: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1
        scrollView.maxMagnification = 8
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.postsFrameChangedNotifications = true

        let container = NSView()
        container.wantsLayer = true

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageFrameStyle = .none
        imageView.wantsLayer = true

        let overlay = ImageAnalysisOverlayView()
        overlay.autoresizingMask = [.width, .height]
        overlay.trackingImageView = imageView
        overlay.preferredInteractionTypes = .textSelection
        imageView.addSubview(overlay)
        container.addSubview(imageView)

        scrollView.documentView = container

        context.coordinator.container = container
        context.coordinator.imageView = imageView
        context.coordinator.overlay = overlay
        context.coordinator.scrollView = scrollView
        context.coordinator.installMonitors()
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewFrameChanged),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
        context.coordinator.apply(image: image, pageToken: pageToken)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(image: image, pageToken: pageToken)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
        coordinator.removeMonitors()
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: LiveTextPageView
        weak var container: NSView?
        weak var imageView: NSImageView?
        weak var overlay: ImageAnalysisOverlayView?
        weak var scrollView: NSScrollView?
        private var currentImage: CGImage?
        private var keyMonitor: Any?
        private var mouseMonitor: Any?
        private let analyzer = ImageAnalyzer()
        private var appliedToken: Int?

        init(_ parent: LiveTextPageView) {
            self.parent = parent
        }

        func apply(image: CGImage?, pageToken: Int) {
            guard let imageView, let overlay else { return }
            if appliedToken == pageToken, image != nil { return }
            appliedToken = image == nil ? nil : pageToken
            currentImage = image

            guard let image else {
                imageView.image = nil
                overlay.analysis = nil
                return
            }

            let size = NSSize(width: image.width, height: image.height)
            imageView.image = NSImage(cgImage: image, size: size)
            scrollView?.magnification = 1
            layoutToFit()
            overlay.analysis = nil

            let analyzer = self.analyzer
            Task { @MainActor in
                guard ImageAnalyzer.isSupported else { return }
                do {
                    let configuration = ImageAnalyzer.Configuration([.text])
                    let analysis = try await analyzer.analyze(image, orientation: .up, configuration: configuration)
                    if self.appliedToken == pageToken {
                        self.overlay?.analysis = analysis
                    }
                } catch {
                    // Leave the page selectable-free if analysis fails.
                }
            }
        }

        /// Sizes the page image to fit the visible area while preserving aspect,
        /// so a two-page spread fills the window.
        func layoutToFit() {
            guard let imageView, let overlay, let scrollView, let container, let image = currentImage else { return }
            let available = scrollView.contentSize
            guard available.width > 1, available.height > 1, image.width > 0, image.height > 0 else { return }
            let scale = min(available.width / CGFloat(image.width), available.height / CGFloat(image.height))
            let fittedSize = NSSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            // Keep the document at least as large as the visible area so a page
            // narrower/shorter than the window is centered instead of pinned to a corner.
            let containerSize = NSSize(
                width: max(available.width, fittedSize.width),
                height: max(available.height, fittedSize.height)
            )
            container.frame = NSRect(origin: .zero, size: containerSize)
            let originX = ((containerSize.width - fittedSize.width) / 2).rounded()
            let originY = ((containerSize.height - fittedSize.height) / 2).rounded()
            imageView.frame = NSRect(x: originX, y: originY, width: fittedSize.width, height: fittedSize.height)
            overlay.frame = imageView.bounds
        }

        @objc func scrollViewFrameChanged() {
            if (scrollView?.magnification ?? 1) <= 1.0001 {
                layoutToFit()
            }
        }

        func installMonitors() {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard
                    let self,
                    let overlay = self.overlay,
                    overlay.window?.isKeyWindow == true
                else {
                    return event
                }
                let translateMatches = self.parent.translateShortcut.matches(event)
                let removeNewlinesMatches = self.parent.removeNewlinesShortcut.matches(event)
                // If both shortcuts share the same combination, strip newlines first,
                // then translate the cleaned original.
                if translateMatches && removeNewlinesMatches {
                    self.parent.onRemoveNewlines()
                    self.parent.onTranslate()
                    return nil
                }
                if translateMatches {
                    self.parent.onTranslate()
                    return nil
                }
                if removeNewlinesMatches {
                    self.parent.onRemoveNewlines()
                    return nil
                }
                return event
            }

            // Commit the selection when a drag finishes inside the page.
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                guard
                    let self,
                    let overlay = self.overlay,
                    let window = overlay.window,
                    window.isKeyWindow,
                    event.window == window
                else {
                    return event
                }
                let pointInOverlay = overlay.convert(event.locationInWindow, from: nil)
                guard overlay.bounds.contains(pointInOverlay) else {
                    return event
                }
                // Read after the overlay has processed the mouse-up.
                DispatchQueue.main.async { [weak self] in
                    guard let self, let overlay = self.overlay else { return }
                    let text = overlay.selectedText
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.parent.onCommitSelection(text)
                    }
                }
                return event
            }
        }

        func removeMonitors() {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
            keyMonitor = nil
            mouseMonitor = nil
        }
    }
}
