import SwiftUI

// MARK: - AI 生成的势力人格
private struct PersonaPayload: Decodable {
    var aiName: String?
    var slogan: String?
    var brief: String?
    var color: String?
    var aggression: Double?
    var industry: Double?
    var science: Double?
    var expansion: Double?
}

// MARK: - AI 诏令
struct AIDirectiveResult {
    var action: String       // war / expand / develop / trade / purge
    var target: String?
    var reason: String
}

private struct DirectivePayload: Decodable {
    var action: String?
    var target: String?
    var reason: String?
}

enum AIPersona {
    static let personaSystem = """
    你是一个文明推演引擎中的「势力 AI 核心」。你会收到一个势力的名字与初始背景，\
    需要推断它的性格、口号与执政风格。只输出一个 JSON 对象，不要任何解释或代码块标记。
    """

    static let directiveSystem = """
    你是一个世界推演中的战略决策核心，全权掌控一个势力。只能输出一个 JSON 对象，不要解释。
    """

    // MARK: 生成人格（走用户的 API）
    @MainActor
    static func generate(name: String, background: String, seed: UInt64,
                         usedColors: [Int]) async throws -> FactionAI {
        let palette = Theme.factionColorNames.joined(separator: "、")
        let prompt = """
        势力名称：\(name.isEmpty ? "无名势力" : name)
        初始背景：\(background.isEmpty ? "（未填写，请自行合理虚构一个符合原始时代的出身）" : background)
        已经使用过的旗色（尽量避开）：\(usedColors.map { Theme.factionColorName($0) }.joined(separator: "、"))

        请输出如下 JSON：
        {
          "aiName": "AI 代号，形如「苍穹·执令者」，6-10 个汉字",
          "slogan": "一句不超过 14 字的立国口号，要有文学感",
          "brief": "不超过 70 字的执政自述，用第一人称，说明以什么立命、要走向哪里",
          "color": "从这些旗色里选一个：\(palette)",
          "aggression": 0 到 1 的小数,
          "industry": 0 到 1 的小数,
          "science": 0 到 1 的小数,
          "expansion": 0 到 1 的小数
        }
        """

        let text = try await AIProvider.complete(system: personaSystem, user: prompt,
                                                 maxTokens: 500, temperature: 0.95)
        guard let json = AIProvider.extractJSON(text),
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PersonaPayload.self, from: data) else {
            throw AIProviderError.decoding("模型没有返回可解析的 JSON")
        }

        var colorIndex = FactionAIForge.generate(name: name, background: background,
                                                 seed: seed, usedColors: usedColors).colorIndex
        if let colorName = payload.color,
           let idx = Theme.factionColorNames.firstIndex(where: { colorName.contains($0) }) {
            colorIndex = idx
        }

        let aggression = clamp(payload.aggression ?? 0.5)
        let industry = clamp(payload.industry ?? 0.5)
        let science = clamp(payload.science ?? 0.5)
        let expansion = clamp(payload.expansion ?? 0.5)
        let doctrine = doctrineFor(aggression: aggression, industry: industry,
                                   science: science, expansion: expansion)

        return FactionAI(
            name: nonEmpty(payload.aiName, fallback: "无名·演算体"),
            slogan: nonEmpty(payload.slogan, fallback: "时间会替我们说话"),
            brief: nonEmpty(payload.brief, fallback: "我们将在这片土地上活下去，并按自己的方式定义秩序。"),
            doctrine: doctrine,
            colorIndex: colorIndex,
            aggression: aggression,
            industry: industry,
            science: science,
            expansion: expansion,
            seed: seed,
            model: AISettings.shared.model,
            createdAt: Date()
        )
    }

    // MARK: 生成诏令（让 AI 真正掌控推演）
    @MainActor
    static func directive(world: World, faction: Faction) async throws -> AIDirectiveResult {
        let neighbors = world.livingFactions
            .filter { $0.id != faction.id }
            .map { other -> String in
                let rel = world.relation(faction.id, other.id)
                let state = rel <= -60 ? "交战" : (rel < -15 ? "敌对" : (rel > 25 ? "友好" : "中立"))
                return "\(other.name)（\(state)，军力\(Int(other.military))，疆域\(other.territory)）"
            }
            .joined(separator: "；")

        let prompt = """
        当前年份：\(world.yearLabel())
        势力：\(faction.name)
        AI 代号：\(faction.aiName)
        口号：\(faction.slogan)
        出身：\(faction.background.isEmpty ? "原始聚落" : faction.background)
        当前状况：疆域 \(faction.territory) 格，人口 \(Int(faction.population))，\
        科技 \(Int(faction.tech))（\(Era.name(for: faction.tech))），军力 \(Int(faction.military))，\
        粮草 \(Int(faction.food))，财富 \(Int(faction.wealth))，稳定 \(Int(faction.stability))
        周边：\(neighbors.isEmpty ? "暂无接壤势力" : neighbors)

        请以这个势力的最高决策者身份，做出下一阶段的一个战略决定，输出 JSON：
        {"action":"war|expand|develop|trade|purge","target":"对手势力名（war/trade 时填，否则空字符串）","reason":"不超过 22 字的诏令原文"}
        """

        let text = try await AIProvider.complete(system: directiveSystem, user: prompt,
                                                 maxTokens: 220, temperature: 0.95)
        guard let json = AIProvider.extractJSON(text),
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(DirectivePayload.self, from: data),
              let action = payload.action?.lowercased() else {
            throw AIProviderError.decoding("诏令 JSON 无法解析")
        }
        let allowed = ["war", "expand", "develop", "trade", "purge"]
        return AIDirectiveResult(action: allowed.contains(action) ? action : "develop",
                                 target: payload.target,
                                 reason: nonEmpty(payload.reason, fallback: "继续按既定路线推进"))
    }

    // MARK: 工具
    private static func clamp(_ v: Double) -> Double { min(0.98, max(0.02, v)) }

    private static func nonEmpty(_ v: String?, fallback: String) -> String {
        let t = (v ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallback : t
    }

    private static func doctrineFor(aggression: Double, industry: Double,
                                    science: Double, expansion: Double) -> Doctrine {
        let scores: [(Doctrine, Double)] = [
            (.conquest, aggression * 1.2),
            (.industry, industry * 1.15),
            (.scholarship, science * 1.15),
            (.nomad, expansion * 1.1),
            (.commerce, (1 - aggression) * 0.6 + industry * 0.4),
            (.maritime, expansion * 0.6 + (1 - aggression) * 0.5),
            (.faith, (1 - science) * 0.5 + (1 - expansion) * 0.5)
        ]
        return scores.max { $0.1 < $1.1 }?.0 ?? .conquest
    }
}
