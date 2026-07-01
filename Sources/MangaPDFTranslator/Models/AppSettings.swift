import Combine
import Foundation

struct AppSettingsSnapshot {
    var chatAPIKey: String
    var chatEndpoint: String
    var chatModel: String
    var chatPromptTemplate: String
    var chatTemperature: Double
}

final class AppSettings: ObservableObject {
    static let defaultChatEndpoint = "https://api.groq.com/openai/v1/chat/completions"
    static let defaultChatModel = "qwen/qwen3-32b"
    static let defaultChatTemperature = 0.3

    static let defaultChatPromptTemplate = """
[
  {
    "role": "system",
    "content": "你是翻译助手，根据用户提供的日文，结合语境纠正可能的错别字并翻译成自然的简体中文。只输出翻译内容，禁止输出注释或非译文内容。"
  },
  {
    "role": "user",
    "content": "翻译：{text}"
  }
]
"""

    private enum Key {
        static let liveTextTranslateShortcut = "liveTextTranslateShortcut"
        static let liveTextRemoveNewlinesShortcut = "liveTextRemoveNewlinesShortcut"
        static let chatAPIKey = "chatAPIKey"
        static let chatEndpoint = "chatEndpoint"
        static let chatModel = "chatModel"
        static let chatPromptTemplate = "chatPromptTemplate"
        static let chatTemperature = "chatTemperature"
    }

    /// Legacy UserDefaults keys used before the Groq-specific backend became a
    /// generic Chat Completion backend. Read as fallback so existing config carries over.
    private enum LegacyKey {
        static let groqAPIKey = "groqAPIKey"
        static let groqEndpoint = "groqEndpoint"
        static let groqModel = "groqModel"
        static let groqPromptTemplate = "groqPromptTemplate"
    }

    private let defaults: UserDefaults

    @Published var liveTextTranslateShortcut: KeyShortcut {
        didSet { defaults.set(liveTextTranslateShortcut.encoded(), forKey: Key.liveTextTranslateShortcut) }
    }

    @Published var liveTextRemoveNewlinesShortcut: KeyShortcut {
        didSet { defaults.set(liveTextRemoveNewlinesShortcut.encoded(), forKey: Key.liveTextRemoveNewlinesShortcut) }
    }

    @Published var chatAPIKey: String {
        didSet { defaults.set(chatAPIKey, forKey: Key.chatAPIKey) }
    }

    @Published var chatEndpoint: String {
        didSet { defaults.set(chatEndpoint, forKey: Key.chatEndpoint) }
    }

    @Published var chatModel: String {
        didSet { defaults.set(chatModel, forKey: Key.chatModel) }
    }

    @Published var chatPromptTemplate: String {
        didSet { defaults.set(chatPromptTemplate, forKey: Key.chatPromptTemplate) }
    }

    @Published var chatTemperature: Double {
        didSet { defaults.set(chatTemperature, forKey: Key.chatTemperature) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        liveTextTranslateShortcut = KeyShortcut.decoded(defaults.string(forKey: Key.liveTextTranslateShortcut)) ?? .translateDefault
        liveTextRemoveNewlinesShortcut = KeyShortcut.decoded(defaults.string(forKey: Key.liveTextRemoveNewlinesShortcut)) ?? .removeNewlinesDefault
        chatAPIKey = defaults.string(forKey: Key.chatAPIKey) ?? defaults.string(forKey: LegacyKey.groqAPIKey) ?? ""
        chatEndpoint = defaults.string(forKey: Key.chatEndpoint) ?? defaults.string(forKey: LegacyKey.groqEndpoint) ?? Self.defaultChatEndpoint
        chatModel = defaults.string(forKey: Key.chatModel) ?? defaults.string(forKey: LegacyKey.groqModel) ?? Self.defaultChatModel
        chatPromptTemplate = defaults.string(forKey: Key.chatPromptTemplate) ?? defaults.string(forKey: LegacyKey.groqPromptTemplate) ?? Self.defaultChatPromptTemplate
        chatTemperature = defaults.object(forKey: Key.chatTemperature) as? Double ?? Self.defaultChatTemperature
    }

    func snapshot() -> AppSettingsSnapshot {
        AppSettingsSnapshot(
            chatAPIKey: chatAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            chatEndpoint: chatEndpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            chatModel: chatModel.trimmingCharacters(in: .whitespacesAndNewlines),
            chatPromptTemplate: chatPromptTemplate,
            chatTemperature: chatTemperature
        )
    }
}
