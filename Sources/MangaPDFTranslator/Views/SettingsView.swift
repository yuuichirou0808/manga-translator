import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Live Text") {
                LabeledContent("翻译快捷键") {
                    ShortcutRecorderField(shortcut: $settings.liveTextTranslateShortcut)
                        .frame(width: 240, height: 24)
                }
                LabeledContent("移除所选换行快捷键") {
                    ShortcutRecorderField(shortcut: $settings.liveTextRemoveNewlinesShortcut)
                        .frame(width: 240, height: 24)
                }
                Text("像预览一样拖选文字：翻译快捷键翻译所选原文，移除换行快捷键清除所选原文里的全部换行。点击右侧按钮后直接按下想要的组合键即可设置（Esc 取消，⌫ 清除）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("翻译 (Chat Completion)") {
                SecureField("API Key", text: $settings.chatAPIKey)
                TextField("API 地址", text: $settings.chatEndpoint)
                TextField("模型", text: $settings.chatModel)
                LabeledContent("Temperature") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.chatTemperature, in: 0...2)
                        Text(String(format: "%.2f", settings.chatTemperature))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                TextEditor(text: $settings.chatPromptTemplate)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                HStack {
                    Button("恢复默认 Prompt") {
                        settings.chatPromptTemplate = AppSettings.defaultChatPromptTemplate
                    }
                    Button("恢复默认接口") {
                        settings.chatEndpoint = AppSettings.defaultChatEndpoint
                        settings.chatModel = AppSettings.defaultChatModel
                        settings.chatTemperature = AppSettings.defaultChatTemperature
                    }
                }
                Text("任何 OpenAI 兼容的 Chat Completions 接口均可（OpenAI / Groq / 本地 llama.cpp、Ollama 等）。Prompt 必须是 chat messages 的 JSON 数组；用 {text} 表示所选原文。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }
}
