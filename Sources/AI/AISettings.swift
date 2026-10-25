import SwiftUI

// MARK: - 用户自备 AI（OpenAI 兼容接口）
final class AISettings: ObservableObject {
    static let shared = AISettings()

    private let defaults = UserDefaults.standard

    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "ai.enabled") }
    }
    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: "ai.baseURL") }
    }
    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: "ai.key") }
    }
    @Published var model: String {
        didSet { defaults.set(model, forKey: "ai.model") }
    }
    @Published var lastStatus: String = "尚未连接"

    private init() {
        enabled = defaults.bool(forKey: "ai.enabled")
        baseURL = defaults.string(forKey: "ai.baseURL") ?? "https://api.openai.com/v1"
        apiKey = defaults.string(forKey: "ai.key") ?? ""
        model = defaults.string(forKey: "ai.model") ?? "gpt-4o-mini"
    }

    var isConfigured: Bool {
        enabled
            && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
            && !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var maskedKey: String {
        guard apiKey.count > 8 else { return apiKey.isEmpty ? "未填写" : "••••" }
        return String(apiKey.prefix(4)) + "••••" + String(apiKey.suffix(4))
    }

    func reset() {
        enabled = false
        apiKey = ""
        baseURL = "https://api.openai.com/v1"
        model = "gpt-4o-mini"
        lastStatus = "尚未连接"
    }
}
