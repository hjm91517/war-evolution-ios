import SwiftUI

// MARK: - 接入你自己的 AI
struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AISettings.shared
    @State private var testing = false
    @State private var testMessage: String?
    @State private var testOK = false

    private let presets: [(String, String, String)] = [
        ("OpenAI", "https://api.openai.com/v1", "gpt-4o-mini"),
        ("DeepSeek", "https://api.deepseek.com/v1", "deepseek-chat"),
        ("Moonshot", "https://api.moonshot.cn/v1", "moonshot-v1-8k"),
        ("自建网关", "https://", "your-model")
    ]

    var body: some View {
        ZStack {
            Backdrop(showGrid: false)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("AI 接入")
                                .font(Theme.display(24, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(Theme.text)
                            Text("YOUR OWN MODEL")
                                .font(Theme.mono(8))
                                .tracking(2)
                                .foregroundStyle(Theme.gold.opacity(0.8))
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.textDim)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 24)

                    Text("势力和推演由你自己的模型接管。支持 OpenAI 兼容的 /chat/completions 接口，密钥只保存在本机。")
                        .font(Theme.body(11.5))
                        .lineSpacing(4.5)
                        .foregroundStyle(Theme.textDim)

                    Panel(padding: 16) {
                        VStack(spacing: 14) {
                            Toggle(isOn: $settings.enabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("启用自备 AI")
                                        .font(Theme.title(13, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                    Text(settings.isConfigured ? "推演时由模型下达诏令" : "未启用时使用本地核心")
                                        .font(Theme.label(9))
                                        .foregroundStyle(Theme.textFaint)
                                }
                            }
                            .tint(Theme.gold)

                            field("接口地址", placeholder: "https://api.openai.com/v1", text: $settings.baseURL, secure: false)
                            field("密钥", placeholder: "sk-...", text: $settings.apiKey, secure: true)
                            field("模型", placeholder: "gpt-4o-mini", text: $settings.model, secure: false)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "快捷模板", english: "PRESETS")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(presets.indices), id: \.self) { i in
                                    let p = presets[i]
                                    Button {
                                        Haptics.select()
                                        settings.baseURL = p.1
                                        settings.model = p.2
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.0)
                                                .font(Theme.body(11.5, weight: .semibold))
                                                .foregroundStyle(Theme.textSoft)
                                            Text(p.2)
                                                .font(Theme.mono(8))
                                                .foregroundStyle(Theme.textFaint)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(Color.white.opacity(0.04)))
                                        .hairlineBorder(Color.white.opacity(0.08), radius: 9)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Button {
                        test()
                    } label: {
                        HStack(spacing: 8) {
                            if testing {
                                ProgressView().tint(Theme.ink).scaleEffect(0.7)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text(testing ? "正在连接…" : "测试连接")
                                .font(Theme.body(12.5, weight: .semibold))
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                            .fill(settings.isConfigured ? Theme.gold : Color.white.opacity(0.1)))
                    }
                    .buttonStyle(Pressable())
                    .disabled(testing || !settings.isConfigured)

                    if let testMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: testOK ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(testOK ? Theme.success : Theme.ember)
                            Text(testMessage)
                                .font(Theme.body(10.5))
                                .lineSpacing(3)
                                .foregroundStyle(Theme.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous)
                            .fill(Color.white.opacity(0.04)))
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.teal)
                        Text("密钥写入本机偏好设置，仅用于直连你填写的地址。建议使用 HTTPS 与独立的限额密钥；若接口不允许 http 明文，App 已为其开放本地例外。")
                            .font(Theme.body(10.5))
                            .lineSpacing(4)
                            .foregroundStyle(Theme.textFaint)
                    }

                    GhostButton(title: "恢复默认", symbol: "arrow.counterclockwise") {
                        settings.reset()
                        testMessage = nil
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDragIndicator(.visible)
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.label(9))
                .tracking(1.2)
                .foregroundStyle(Theme.textFaint)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(Theme.mono(12))
            .foregroundStyle(Theme.textSoft)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous)
                .fill(Color.white.opacity(0.04)))
            .hairlineBorder(Color.white.opacity(0.08), radius: Theme.rSmall)
        }
    }

    private func test() {
        testing = true
        testMessage = nil
        let start = Date()
        Task { @MainActor in
            defer { testing = false }
            do {
                let text = try await AIProvider.complete(system: "你是一个连接测试端点。",
                                                         user: "只回复四个字：连接成功",
                                                         maxTokens: 20, temperature: 0)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                testOK = true
                testMessage = "连接成功 · \(ms) ms · 模型回复「\(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))」"
                settings.lastStatus = "已连接 · \(ms) ms"
                Haptics.success()
            } catch {
                testOK = false
                testMessage = error.localizedDescription
                settings.lastStatus = "连接失败"
                Haptics.warning()
            }
        }
    }
}
