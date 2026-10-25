import SwiftUI

// MARK: - 区域级别
enum RegionLevel: String, Codable, CaseIterable, Identifiable {
    case nation, region, city

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nation: return "国家级"
        case .region: return "地区级"
        case .city:   return "城邦级"
        }
    }

    var caption: String {
        switch self {
        case .nation: return "大片疆域 · 粗笔刷"
        case .region: return "中等辖区 · 中笔刷"
        case .city:   return "单点城邦 · 细笔刷"
        }
    }

    var brush: Int {
        switch self {
        case .nation: return 6
        case .region: return 3
        case .city:   return 1
        }
    }

    var symbol: String {
        switch self {
        case .nation: return "globe.asia.australia.fill"
        case .region: return "map.fill"
        case .city:   return "building.2.fill"
        }
    }

    var scaleHint: String {
        switch self {
        case .nation: return "每格约 110 km"
        case .region: return "每格约 110 km"
        case .city:   return "每格约 110 km"
        }
    }
}

// MARK: - 治国路线（AI 倾向）
enum Doctrine: String, Codable, CaseIterable, Identifiable {
    case conquest, commerce, scholarship, faith, nomad, maritime, industry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .conquest:    return "尚武"
        case .commerce:    return "重商"
        case .scholarship: return "崇文"
        case .faith:       return "神权"
        case .nomad:       return "游牧"
        case .maritime:    return "航海"
        case .industry:    return "工造"
        }
    }

    var detail: String {
        switch self {
        case .conquest:    return "以兵立国，扩张优先，外交强硬"
        case .commerce:    return "以商养国，偏好贸易与结盟"
        case .scholarship: return "重学兴教，科技跃迁更快"
        case .faith:       return "以信仰凝聚人心，稳定度高"
        case .nomad:       return "逐水草而居，机动扩张，掠夺为生"
        case .maritime:    return "向海而生，港口与航路带来财富"
        case .industry:    return "以工强国，资源转化效率高"
        }
    }

    var symbol: String {
        switch self {
        case .conquest:    return "shield.lefthalf.filled"
        case .commerce:    return "cart.fill"
        case .scholarship: return "book.closed.fill"
        case .faith:       return "building.columns.fill"
        case .nomad:       return "figure.walk"
        case .maritime:    return "sailboat.fill"
        case .industry:    return "hammer.fill"
        }
    }

    var aggression: Double {
        switch self {
        case .conquest: return 0.82
        case .nomad: return 0.72
        case .maritime: return 0.42
        case .commerce: return 0.28
        case .scholarship: return 0.30
        case .faith: return 0.46
        case .industry: return 0.40
        }
    }

    var science: Double {
        switch self {
        case .scholarship: return 0.85
        case .industry: return 0.66
        case .commerce: return 0.52
        case .maritime: return 0.55
        case .faith: return 0.40
        case .conquest: return 0.38
        case .nomad: return 0.26
        }
    }

    var expansion: Double {
        switch self {
        case .nomad: return 0.88
        case .conquest: return 0.80
        case .industry: return 0.52
        case .maritime: return 0.50
        case .commerce: return 0.44
        case .scholarship: return 0.36
        case .faith: return 0.42
        }
    }
}

// MARK: - 行动类型（地图图标）
enum ActionKind: String, Codable, CaseIterable {
    case expand, battle, war, build, explore, trade, diplomacy, disaster, space, revolt, discovery, landfall

    var symbol: String {
        switch self {
        case .expand:    return "arrow.up.right"
        case .battle:    return "flame.fill"
        case .war:       return "shield.lefthalf.filled"
        case .build:     return "hammer.fill"
        case .explore:   return "binoculars.fill"
        case .trade:     return "cart.fill"
        case .diplomacy: return "hand.raised.fill"
        case .disaster:  return "exclamationmark.triangle.fill"
        case .space:     return "antenna.radiowaves.left.and.right"
        case .revolt:    return "person.3.fill"
        case .discovery: return "sparkles"
        case .landfall:  return "sailboat.fill"
        }
    }

    var label: String {
        switch self {
        case .expand:    return "拓殖"
        case .battle:    return "交战"
        case .war:       return "宣战"
        case .build:     return "营造"
        case .explore:   return "探索"
        case .trade:     return "通商"
        case .diplomacy: return "外交"
        case .disaster:  return "灾变"
        case .space:     return "航天"
        case .revolt:    return "叛乱"
        case .discovery: return "发现"
        case .landfall:  return "登陆"
        }
    }

    var tint: Color {
        switch self {
        case .battle, .war: return Theme.ember
        case .space:        return Theme.goldBright
        case .disaster, .revolt: return Theme.danger
        case .trade, .build: return Theme.gold
        case .explore, .discovery: return Theme.teal
        case .diplomacy:    return Theme.sand
        case .expand:       return Theme.sand
        case .landfall:     return Theme.teal
        }
    }
}

// MARK: - 事件
enum EventKind: String, Codable, CaseIterable {
    case expansion, battle, war, peace, tech, wonder, disaster, intel, space, trade, revolt, discovery, politics, birth, death

    var symbol: String {
        switch self {
        case .expansion: return "arrow.up.right"
        case .battle:    return "flame.fill"
        case .war:       return "shield.lefthalf.filled"
        case .peace:     return "leaf.fill"
        case .tech:      return "bolt.fill"
        case .wonder:    return "building.columns.fill"
        case .disaster:  return "exclamationmark.triangle.fill"
        case .intel:     return "eye.fill"
        case .space:     return "antenna.radiowaves.left.and.right"
        case .trade:     return "cart.fill"
        case .revolt:    return "person.3.fill"
        case .discovery: return "sparkles"
        case .politics:  return "hand.raised.fill"
        case .birth:     return "circle.dotted"
        case .death:     return "xmark"
        }
    }

    var tint: Color {
        switch self {
        case .battle, .war: return Theme.ember
        case .disaster, .revolt, .death: return Theme.danger
        case .tech, .space: return Theme.goldBright
        case .trade, .wonder: return Theme.gold
        case .discovery, .peace: return Theme.teal
        case .intel: return Theme.textSoft
        default: return Theme.sand
        }
    }
}

enum IntelLevel: String, Codable, CaseIterable {
    case open, classified, secret

    var tag: String {
        switch self {
        case .open:       return ""
        case .classified: return "机密"
        case .secret:     return "绝密"
        }
    }

    var tint: Color {
        switch self {
        case .open: return Theme.textDim
        case .classified: return Theme.gold
        case .secret: return Theme.ember
        }
    }
}

struct SimEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var tick: Int
    var kind: EventKind
    var headline: String
    var detail: String
    var factionID: UUID?
    var cell: Int
    var intel: IntelLevel = .open
    var revealTick: Int = 0
    var importance: Int = 2

    var isRedacted: Bool { intel != .open && tick < revealTick }
    var isDeclassified: Bool { intel != .open && tick >= revealTick }
}

// MARK: - 地图行动标记
struct ActionMarker: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var cell: Int
    var kind: ActionKind
    var factionID: UUID?
    var bornTick: Int
    var note: String = ""
    var scale: Double = 1.0
}

// MARK: - 疆域数据（每格 1 字节：0 无主，n 为 factions[n-1]）
struct TerritoryData: Codable, Equatable {
    var cells: [UInt8]

    init(cells: [UInt8]) { self.cells = cells }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        self.cells = [UInt8](data)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Data(cells))
    }

    func owner(at index: Int) -> Int {
        guard index >= 0 && index < cells.count else { return 0 }
        return Int(cells[index])
    }

    mutating func setOwner(_ owner: Int, at index: Int) {
        guard index >= 0 && index < cells.count else { return }
        cells[index] = UInt8(max(0, min(255, owner)))
    }
}

// MARK: - 势力 AI（全权接管）
struct FactionAI: Codable, Equatable {
    var code: String          // AI 代号
    var slogan: String        // 口号
    var brief: String         // 自述
    var doctrine: Doctrine
    var colorIndex: Int
    var aggression: Double
    var industry: Double
    var science: Double
    var expansion: Double
    var seed: UInt64
    var model: String

    var modelTag: String { model }
}

// MARK: - 势力的 AI 核心
// 玩家只提供名字与初始背景；AI 由此推导口号、旗色、路线与决策参数，全权接管该势力。
struct FactionAI: Codable, Equatable {
    var name: String            // AI 代号，如「苍穹·执令者」
    var slogan: String          // 立国口号
    var brief: String           // AI 自述的执政方针
    var doctrine: Doctrine      // 内部路线（不再由玩家选择）
    var colorIndex: Int         // AI 生成的旗色
    var aggression: Double
    var industry: Double
    var science: Double
    var expansion: Double
    var seed: UInt64
    var model: String = "LOCAL CORE 2"
    var createdAt: Date = Date()

    var isReady: Bool { true }
}

// MARK: - 势力
struct Faction: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var colorIndex: Int = 0
    var symbol: String = "shield.lefthalf.filled"
    var doctrine: Doctrine = .conquest
    var background: String = ""
    var ai: FactionAI? = nil
    var ai: FactionAI? = nil

    // 性格权重 0...1
    var aggression: Double = 0.5
    var industry: Double = 0.5
    var science: Double = 0.5
    var expansion: Double = 0.5

    // 状态
    var population: Double = 120
    var tech: Double = 0.6
    var military: Double = 22
    var food: Double = 120
    var wealth: Double = 40
    var morale: Double = 60
    var stability: Double = 68

    var capital: Int = -1
    var isAlive: Bool = true
    var wonders: Int = 0
    var battlesWon: Int = 0
    var foundedTick: Int = 0
    var fallenTick: Int = -1
    var lastAction: ActionKind? = nil

    // 运行期缓存（不持久化）
    var territory: Int = 0

    private enum CodingKeys: String, CodingKey {
        case id, name, colorIndex, symbol, doctrine, background, ai, aggression, industry,
             science, expansion, population, tech, military, food, wealth, morale,
             stability, capital, isAlive, wonders, battlesWon, foundedTick, fallenTick,
             lastAction
    }

    var color: Color { Theme.factionColor(colorIndex) }

    var isAIConfigured: Bool { ai != nil }
    var aiName: String { ai?.name ?? "未配置 AI" }
    var slogan: String { ai?.slogan ?? "" }

    var isReady: Bool { ai != nil }

    var power: Double {
        military * 0.55 + tech * 0.9 + population * 0.02 + Double(territory) * 0.5
    }

    var techName: String { Era.name(for: tech) }

    var populationCap: Double { 60 + tech * 5 + Double(territory) * 2 }
}

// MARK: - 时代
struct Era {
    static let stages: [(threshold: Double, name: String, detail: String)] = [
        (0,    "石器时代", "磨制石器与火，族群聚落初成"),
        (8,    "青铜时代", "冶炼与城邦，战车与祭司"),
        (18,   "铁器时代", "铁犁与铁剑，帝国胚芽"),
        (32,   "古典时代", "法典、道路与常备军"),
        (50,   "火药时代", "火药与印刷，旧秩序崩解"),
        (72,   "工业时代", "蒸汽、铁路与钢铁洪流"),
        (96,   "电气时代", "电网、无线电与总体战"),
        (124,  "信息时代", "计算、卫星与无声的战争"),
        (158,  "轨道时代", "近地轨道与深空前哨"),
        (200,  "星海纪元", "行星尺度的文明博弈")
    ]

    static func index(for tech: Double) -> Int {
        var result = 0
        for (i, stage) in stages.enumerated() where tech >= stage.threshold {
            result = i
        }
        return result
    }

    static func name(for tech: Double) -> String { stages[index(for: tech)].name }
    static func detail(for tech: Double) -> String { stages[index(for: tech)].detail }
    static func threshold(for tech: Double) -> Double { stages[index(for: tech)].threshold }
    static func nextThreshold(for tech: Double) -> Double {
        let i = index(for: tech)
        return i + 1 < stages.count ? stages[i + 1].threshold : stages[i].threshold
    }
}

// MARK: - 世界
enum WorldPhase: String, Codable {
    case draft, evolving
}

struct World: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var seed: UInt64 = 1
    var level: RegionLevel = .nation
    var phase: WorldPhase = .draft
    var createdAt: Date = Date()
    var lastActiveAt: Date = Date()
    var tick: Int = 0
    var speed: Int = 4                // 1 / 4 / 16 / 64
    var continuous: Bool = false
    var factions: [Faction] = []
    var territory: TerritoryData
    var events: [SimEvent] = []
    var markers: [ActionMarker] = []
    var relations: [String: Int] = [:]
    var rngState: UInt64 = 0x9E3779B97F4A7C15
    var totalBattles: Int = 0
    var peakFactionName: String = ""

    init(seed: UInt64, cellCount: Int) {
        self.seed = seed
        self.rngState = seed ^ 0xDEADBEEFCAFEBABE
        self.territory = TerritoryData(cells: [UInt8](repeating: 0, count: cellCount))
    }

    var livingFactions: [Faction] { factions.filter { $0.isAlive } }

    var dominantTech: Double {
        factions.filter { $0.isAlive }.map(\.tech).max() ?? 0
    }

    var eraName: String { Era.name(for: dominantTech) }

    var claimedLand: Int {
        var n = 0
        for c in territory.cells where c != 0 { n += 1 }
        return n
    }

    func faction(id: UUID?) -> Faction? {
        guard let id else { return nil }
        return factions.first { $0.id == id }
    }

    func factionIndex(id: UUID?) -> Int? {
        guard let id else { return nil }
        return factions.firstIndex { $0.id == id }
    }

    func faction(owner: Int) -> Faction? {
        guard owner > 0 && owner <= factions.count else { return nil }
        return factions[owner - 1]
    }

    static func relationKey(_ a: UUID, _ b: UUID) -> String {
        let x = a.uuidString, y = b.uuidString
        return x < y ? "\(x)|\(y)" : "\(y)|\(x)"
    }

    func relation(_ a: UUID, _ b: UUID) -> Int {
        relations[World.relationKey(a, b)] ?? 0
    }

    mutating func setRelation(_ a: UUID, _ b: UUID, _ value: Int) {
        relations[World.relationKey(a, b)] = max(-100, min(100, value))
    }
}

// MARK: - 时间
enum SimSpeed {
    static let options: [Int] = [1, 4, 16, 64]
    static func label(_ v: Int) -> String { "×\(v)" }
    static func ticksPerSecond(_ v: Int) -> Double { Double(v) * 1.6 }
}
