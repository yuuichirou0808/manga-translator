import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            LiveTextReader()
        }
        .onOpenURL(perform: openExternalPDF)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: openPDF) {
                Label("打开 PDF", systemImage: "doc")
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()
                .frame(height: 22)

            Button(action: model.liveTextGoPrevious) {
                Label("上一页", systemImage: "chevron.left")
            }
            .disabled(!model.canLiveTextPrevious)

            Button(action: model.liveTextGoNext) {
                Label("下一页", systemImage: "chevron.right")
            }
            .disabled(!model.canLiveTextNext)

            Text(model.liveTextPageTitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(minWidth: 96)

            Spacer()

            if model.isTranslating {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            }

            Text(model.statusMessage)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)

            Button(action: showSettings) {
                Label("设置", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .help("设置")
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private func openPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            model.openPDF(url)
        }
    }

    private func openExternalPDF(_ url: URL) {
        guard url.isFileURL, url.pathExtension.lowercased() == "pdf" else {
            model.statusMessage = "只能打开 PDF 文件。"
            return
        }
        model.openPDF(url)
    }

    private func showSettings() {
        SettingsWindowPresenter.shared.show(settings: settings)
    }
}
