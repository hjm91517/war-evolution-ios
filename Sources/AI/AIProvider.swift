import Foundation

// MARK: - 通用 Chat Completions 客户端（兼容 OpenAI / DeepSeek / Moonshot / 自建网关）
enum AIProviderError: LocalizedError {
    case notConfigured
    case invalidURL
    case http(Int, String)
    case empty
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "尚未配置 AI 接口"
        case .invalidURL: return "接口地址无效"
        case .http(let code, let body):
            let snippet = body.prefix(120).replacingOccurrences(of: "\n", with: " ")
            return "接口返回 \(code)：\(snippet)"
        case .empty: return "接口没有返回内容"
        case .decoding(let reason): return "解析失败：\(reason)"
        }
    }
}

enum AIProvider {
    /// 直接返回模型文本
    @MainActor
    static func complete(system: String, user: String,
                         maxTokens: Int = 700, temperature: Double = 0.9) async throws -> String {
        let settings = AISettings.shared
        guard settings.isConfigured else { throw AIProviderError.notConfigured }

        var base = settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        if !base.hasSuffix("/chat/completions") {
            if base.hasSuffix("/v1") {
                base += "/chat/completions"
            } else {
                base += "/v1/chat/completions"
            }
        }
        guard let url = URL(string: base) else { throw AIProviderError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 50
        request.addValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": settings.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 50
        config.timeoutIntervalForResource = 70
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIProviderError.decoding("无 HTTP 响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AIProviderError.http(http.statusCode,
                                       String(data: data.prefix(400), encoding: .utf8) ?? "")
        }

        struct Resp: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String? }
                let message: Msg
            }
            let choices: [Choice]
        }
        do {
            let decoded = try JSONDecoder().decode(Resp.self, from: data)
            guard let text = decoded.choices.first?.message.content,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIProviderError.empty
            }
            return text
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.decoding(error.localizedDescription)
        }
    }

    /// 从可能带 ```json 包裹的文本里抽出 JSON 对象
    static func extractJSON(_ text: String) -> String? {
        var t = text
        if let start = t.firstIndex(of: "{"), let end = t.lastIndex(of: "}"), start < end {
            t = String(t[start...end])
        }
        return t.hasPrefix("{") ? t : nil
    }
}
