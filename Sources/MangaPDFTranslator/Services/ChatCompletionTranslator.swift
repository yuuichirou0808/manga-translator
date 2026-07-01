import Foundation

enum ChatCompletionTranslatorError: LocalizedError {
    case missingAPIKey
    case missingModel
    case invalidEndpoint
    case invalidPrompt(String)
    case requestFailed(String)
    case emptyTranslation

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先配置 API Key。"
        case .missingModel:
            return "请先配置模型。"
        case .invalidEndpoint:
            return "API 地址无效。"
        case .invalidPrompt(let message):
            return "Prompt 格式无效：\(message)"
        case .requestFailed(let message):
            return message
        case .emptyTranslation:
            return "接口没有返回译文。"
        }
    }
}

/// Translation via any OpenAI-compatible Chat Completions endpoint
/// (OpenAI, Groq, Together, local llama.cpp / Ollama, etc.).
struct ChatCompletionTranslator {
    func translate(_ text: String, settings: AppSettingsSnapshot) async throws -> String {
        guard !settings.chatAPIKey.isEmpty else {
            throw ChatCompletionTranslatorError.missingAPIKey
        }

        guard !settings.chatModel.isEmpty else {
            throw ChatCompletionTranslatorError.missingModel
        }

        guard let url = URL(string: settings.chatEndpoint), !settings.chatEndpoint.isEmpty else {
            throw ChatCompletionTranslatorError.invalidEndpoint
        }

        let messages = try buildMessages(from: settings.chatPromptTemplate, text: text)
        let body = ChatRequest(
            model: settings.chatModel,
            messages: messages,
            temperature: settings.chatTemperature
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.chatAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ChatCompletionTranslatorError.requestFailed("请求失败：HTTP \(httpResponse.statusCode) \(body)")
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let rawTranslation = decoded.choices.first?.message.content ?? ""
        let translation = removeThinkingContent(from: rawTranslation)
        guard !translation.isEmpty else {
            throw ChatCompletionTranslatorError.emptyTranslation
        }
        return translation
    }

    private func buildMessages(from promptTemplate: String, text: String) throws -> [ChatMessage] {
        let data = Data(promptTemplate.utf8)
        do {
            let templates = try JSONDecoder().decode([ChatMessage].self, from: data)
            let messages = templates.map { message in
                ChatMessage(
                    role: message.role,
                    content: message.content.replacingOccurrences(of: "{text}", with: text)
                )
            }
            guard !messages.isEmpty else {
                throw ChatCompletionTranslatorError.invalidPrompt("messages 不能为空。")
            }
            return messages
        } catch let error as ChatCompletionTranslatorError {
            throw error
        } catch {
            throw ChatCompletionTranslatorError.invalidPrompt("请输入 JSON 数组，例如 [{\"role\":\"user\",\"content\":\"翻译：{text}\"}]。")
        }
    }

    private func removeThinkingContent(from content: String) -> String {
        var cleaned = content
        cleaned = replacingMatches(
            in: cleaned,
            pattern: #"<think\b[^>]*>[\s\S]*?</think>"#,
            with: ""
        )
        cleaned = replacingMatches(
            in: cleaned,
            pattern: #"</think>"#,
            with: ""
        )
        cleaned = replacingMatches(
            in: cleaned,
            pattern: #"<think\b[^>]*>[\s\S]*$"#,
            with: ""
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func replacingMatches(in text: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}

private struct ChatRequest: Encodable {
    var model: String
    var messages: [ChatMessage]
    var temperature: Double
    var stream = false
}

private struct ChatMessage: Codable {
    var role: String
    var content: String
}

private struct ChatResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String
    }
}
