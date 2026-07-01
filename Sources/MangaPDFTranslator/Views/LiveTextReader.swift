import SwiftUI

/// Live Text reading mode: a page with selectable text (like Preview) plus a
/// panel showing the selected original and its translation.
struct LiveTextReader: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            pageArea
                .frame(minHeight: 300, maxHeight: .infinity)
            Divider()
            panel
                .frame(height: 170)
        }
    }

    @ViewBuilder
    private var pageArea: some View {
        if model.liveTextImage != nil {
            LiveTextPageView(
                image: model.liveTextImage,
                pageToken: model.liveTextPageIndex,
                translateShortcut: settings.liveTextTranslateShortcut,
                removeNewlinesShortcut: settings.liveTextRemoveNewlinesShortcut,
                onCommitSelection: model.commitLiveTextSelection,
                onTranslate: { model.translateLiveText(model.liveTextSelected) },
                onRemoveNewlines: model.removeLiveTextNewlines
            )
        } else {
            VStack(spacing: 14) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("打开 PDF 后，可在此像预览一样直接选字翻译。")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var panel: some View {
        HStack(spacing: 0) {
            originalView
            Divider()
            translationView
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var originalView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("所选原文")
                    .font(.headline)
                Spacer()
                Button("移除换行") { model.removeLiveTextNewlines() }
                    .buttonStyle(.borderless)
                    .help("移除所选原文中的全部换行（\(settings.liveTextRemoveNewlinesShortcut.displayString)）")
                    .disabled(model.liveTextSelected.isEmpty)
                Button("清空") { model.updateLiveTextOriginal("") }
                    .buttonStyle(.borderless)
                    .disabled(model.liveTextSelected.isEmpty)
            }
            TextEditor(text: Binding(
                get: { model.liveTextSelected },
                set: { model.updateLiveTextOriginal($0) }
            ))
            .font(.body)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var translationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("译文")
                    .font(.headline)
                Spacer()
                Button(action: { model.translateLiveText(model.liveTextSelected) }) {
                    if model.isTranslating {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("翻译所选 (\(settings.liveTextTranslateShortcut.displayString))", systemImage: "arrow.right.circle")
                    }
                }
                .disabled(model.liveTextSelected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isTranslating)
            }

            ScrollView {
                Text(model.liveTextTranslation.isEmpty ? " " : model.liveTextTranslation)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
