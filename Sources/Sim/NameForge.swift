import Foundation

// MARK: - 名称铸造
enum NameForge {
    private static let prefixes = ["赤", "玄", "青", "白", "苍", "朔", "炎", "霜", "瀚", "幽",
                                   "云", "沧", "金", "铁", "北", "南", "东", "西", "大", "九"]
    private static let stems = ["岚", "庭", "川", "岭", "原", "海", "洲", "谷", "关", "城",
                               "垠", "野", "渊", "漠", "河", "山", "阙", "津", "陵", "泽"]
    private static let suffixes = ["国", "邦", "部", "盟", "王朝", "联邦", "公国", "氏"]

    static func factionName(seed: UInt64, index: Int) -> String {
        var rng = SeededRNG(state: seed &+ UInt64(index &* 7919) &+ 0x51ED)
        let a = prefixes[rng.int(0..<prefixes.count)]
        let b = stems[rng.int(0..<stems.count)]
        return a + b
    }

    static func worldName(seed: UInt64) -> String {
        var rng = SeededRNG(state: seed &+ 0xABCDEF)
        let a = prefixes[rng.int(0..<prefixes.count)]
        let b = stems[rng.int(0..<stems.count)]
        let tails = ["纪元", "长卷", "之战", "星图", "纪事"]
        return a + b + "·" + tails[rng.int(0..<tails.count)]
    }

    static func cityName(seed: UInt64, cell: Int) -> String {
        var rng = SeededRNG(state: seed &+ UInt64(cell &* 131))
        let a = prefixes[rng.int(0..<prefixes.count)]
        let b = stems[rng.int(0..<stems.count)]
        return a + b
    }

    static func factionTitle(_ index: Int) -> String {
        let t = ["部族", "城邦", "王国", "帝国", "联盟", "共和国", "王朝", "联邦"]
        return t[index % t.count]
    }
}

// MARK: - 背景文本 → AI 倾向解析
struct BackgroundRead {
    var doctrine: Doctrine = .conquest
    var aggression: Double = 0.5
    var industry: Double = 0.5
    var science: Double = 0.5
    var expansion: Double = 0.5
    var tags: [String] = []
    var summary: String = ""

    var isValid: Bool { !tags.isEmpty }

    var tagLine: String {
        tags.isEmpty ? "尚未输入背景" : tags.joined(separator: " · ")
    }
}

enum BackgroundInterpreter {
    private struct Rule {
        let doctrine: Doctrine
        let words: [String]
        let aggression: Double
        let industry: Double
        let science: Double
        let expansion: Double
    }

    private static let rules: [Rule] = [
        Rule(doctrine: .conquest,
             words: ["尚武", "军事", "征服", "铁血", "骑兵", "战神", "扩张", "掠夺", "战", "兵", "刀", "弓"],
             aggression: 0.24, industry: 0.04, science: -0.02, expansion: 0.18),
        Rule(doctrine: .commerce,
             words: ["商", "贸易", "财富", "商路", "市集", "钱", "税", "契约", "金融", "货"],
             aggression: -0.16, industry: 0.08, science: 0.04, expansion: 0.02),
        Rule(doctrine: .scholarship,
             words: ["学", "书", "科技", "发明", "研究", "学院", "工程", "天文", "算", "医"],
             aggression: -0.14, industry: 0.10, science: 0.26, expansion: -0.02),
        Rule(doctrine: .faith,
             words: ["神", "信仰", "祭司", "宗教", "圣", "祭", "巫", "庙", "仪式", "先知"],
             aggression: 0.02, industry: 0.02, science: -0.08, expansion: 0.06),
        Rule(doctrine: .nomad,
             words: ["游牧", "草原", "部落", "骑射", "迁徙", "马", "帐", "牧场", "风沙"],
             aggression: 0.14, industry: -0.10, science: -0.06, expansion: 0.26),
        Rule(doctrine: .maritime,
             words: ["海", "航", "船", "岛", "舰队", "港", "渔", "远洋", "潮"],
             aggression: 0.06, industry: 0.06, science: 0.06, expansion: 0.10),
        Rule(doctrine: .industry,
             words: ["工", "矿", "冶", "铁", "制造", "建筑", "匠", "炉", "机", "路"],
             aggression: 0.04, industry: 0.22, science: 0.10, expansion: 0.08)
    ]

    static func read(_ text: String) -> BackgroundRead {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return BackgroundRead() }
        var read = BackgroundRead()
        var best = 0
        var bestRule: Rule? = nil
        var tags: [String] = []

        for rule in rules {
            var score = 0
            for w in rule.words where t.contains(w) {
                score += (w.count >= 2 ? 2 : 1)
                if !tags.contains(w) { tags.append(w) }
            }
            if score > best {
                best = score
                bestRule = rule
            }
        }

        if let rule = bestRule {
            read.doctrine = rule.doctrine
            let k = min(1.0, Double(best) / 8.0)
            read.aggression = clamp(rule.aggression * k + 0.5)
            read.industry = clamp(rule.industry * k + 0.5)
            read.science = clamp(rule.science * k + 0.5)
            read.expansion = clamp(rule.expansion * k + 0.5)
            read.summary = "判定为「\(rule.doctrine.title)」路线"
        } else {
            read.summary = "背景未给出明确路线，按均衡发展"
        }
        read.tags = Array(tags.prefix(6))
        return read
    }

    private static func clamp(_ v: Double) -> Double { min(0.95, max(0.05, v)) }

    @discardableResult
    static func apply(to faction: inout Faction) -> BackgroundRead {
        let read = read(faction.background)
        faction.doctrine = read.doctrine
        faction.aggression = read.aggression
        faction.industry = read.industry
        faction.science = read.science
        faction.expansion = read.expansion
        return read
    }
}
