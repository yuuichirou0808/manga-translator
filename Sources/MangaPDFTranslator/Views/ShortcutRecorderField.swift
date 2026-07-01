import AppKit
import SwiftUI

/// A button that records a keyboard shortcut: click it, then press the desired
/// key combination. Esc cancels, Delete clears.
struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: KeyShortcut

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.target = context.coordinator
        button.action = #selector(Coordinator.toggle(_:))
        context.coordinator.button = button
        context.coordinator.updateTitle()
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.parent = self
        if !context.coordinator.isRecording {
            context.coordinator.updateTitle()
        }
    }

    static func dismantleNSView(_ nsView: NSButton, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: ShortcutRecorderField
        weak var button: NSButton?
        private(set) var isRecording = false
        private var monitor: Any?

        init(_ parent: ShortcutRecorderField) {
            self.parent = parent
        }

        @objc func toggle(_ sender: NSButton) {
            if isRecording { stop() } else { start() }
        }

        private func start() {
            isRecording = true
            button?.title = "按下快捷键…（Esc 取消，⌫ 清除）"
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                switch event.keyCode {
                case 53: // Escape
                    self.stop()
                case 51: // Delete
                    self.parent.shortcut = KeyShortcut(key: "", modifiers: 0)
                    self.stop()
                default:
                    if let recorded = KeyShortcut.from(event) {
                        self.parent.shortcut = recorded
                        self.stop()
                    }
                }
                return nil
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            isRecording = false
            updateTitle()
        }

        func updateTitle() {
            button?.title = parent.shortcut.isEmpty ? "点击设置快捷键" : parent.shortcut.displayString
        }
    }
}
