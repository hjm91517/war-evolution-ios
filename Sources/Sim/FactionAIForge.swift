import SwiftUI

// MARK: - 本地 AI 铸造
// 玩家只写「名字 + 初始背景」，其余全部由本地推演核心推导：
// 口号、AI 代号、旗色、内部路线与决策参数。没有网络、没有 API Key。
enum FactionAIForge {

    static func generate(name: String, background: String, seed: UInt64, usedColors: [Int] = []) -> FactionAI {
        let read = BackgroundInterpreter.read(background)
        let textSeed = UInt64(bitPattern: Int64(background.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFFFFFF }))
        var rng = SeededRNG(state: seed &+ textSeed &* 2654435761 &+ 0x51ED270B)

        let doctrine = read.doctrine
        let colorIndex = pickColor(background: background, read: read, used: usedColors, rng: &rng)
        let aiName = aiName(doctrine: doctrine, rng: &rng)
        let slogan = slogan(doctrine: doctrine, rng: &rng)
        let brief = brief(factionName: name, doctrine: doctrine, rng: &rng, read: read)

        func jitter(_ v: Double) -> Double {
            min(0.97, max(0.05, v + (rng.unit() - 0.5) * 0.14))
        }

        return FactionAI(
            name: aiName,
            slogan: slogan,
            brief: brief,
            doctrine: doctrine,
            colorIndex: colorIndex,
            aggression: jitter(read.aggression),
            industry: jitter(read.industry),
            science: jitter(read.science),
            expansion: jitter(read.expansion),
            seed: rng.state,
            model: "LOCAL CORE 2",
            createdAt: Date()
        )
    }

    /// 重新配色（保留其余设定）
    static func recolor(_ current: FactionAI, background: String, usedColors: [Int]) -> FactionAI {
        var rng = SeededRNG(state: current.seed &+ 0x9E37)
        var next = current
        next.colorIndex = pickColor(background: background,
                                    read: BackgroundInterpreter.read(background),
                                    used: usedColors,
                                    rng: &rng)
        return next
    }

    // MARK: - 旗色
    private static let families: [(words: [String], colors: [Int])] = [
        (["海", "洋", "港", "船", "潮", "江", "河", "湖", "渔", "雨", "岛", "航"], [2, 5, 9]),
        (["沙", "漠", "火", "炎", "赤", "日", "金", "商", "市", "铜"], [0, 4, 6]),
        (["林", "草", "原", "山", "木", "叶", "谷", "牧", "马"], [1, 5, 8]),
        (["夜", "影", "星", "紫", "玄", "幽", "月", "梦"], [3, 7]),
        (["铁", "钢", "石", "矿", "城", "塔", "墙", "铸"], [9, 0, 8]),
        (["血", "战", "兵", "刀", "征", "弓", "旗"], [6, 0])
    ]

    private static func pickColor(background: String, read: BackgroundRead,
                                  used: [Int], rng: inout SeededRNG) -> Int {
        var candidates: [Int] = []
        for family in families {
            if family.words.contains(where: { background.contains($0) }) {
                candidates.append(contentsOf: family.colors)
            }
        }
        switch read.doctrine {
        case .maritime: candidates.append(contentsOf: [2, 5])
        case .commerce: candidates.append(contentsOf: [0, 4])
        case .conquest, .nomad: candidates.append(contentsOf: [6, 0])
        case .scholarship: candidates.append(contentsOf: [3, 9])
        case .faith: candidates.append(contentsOf: [4, 7])
        case .industry: candidates.append(contentsOf: [9, 8])
        }
        if candidates.isEmpty {
            candidates = Array(0..<Theme.factionColors.count)
        }
        let free = candidates.filter { !used.contains($0) }
        let pool = free.isEmpty ? candidates : free
        return pool[rng.int(0..<pool.count)]
    }

    // MARK: - AI 代号
    private static func aiName(doctrine: Doctrine, rng: inout SeededRNG) -> String {
        let prefixes: [String]
        let roles: [String]
        switch doctrine {
        case .conquest:
            prefixes = ["苍穹", "玄铁", "赤砂", "朔风", "黑石"]
            roles = ["执令者", "战策体", "先锋议会", "征服演算"]
        case .commerce:
            prefixes = ["长桥", "金砂", "白帆", "鸣沙", "天平"]
            roles = ["商会核心", "结算者", "织网者", "契约官"]
        case .scholarship:
            prefixes = ["青烛", "观星", "墨理", "千卷", "静水"]
            roles = ["观察体", "记录官", "求知议会", "演算者"]
        case .faith:
            prefixes = ["白塔", "圣言", "长夜", "黎明", "灰烬"]
            roles = ["司祭核", "守约者", "先知体", "祷告议会"]
        case .nomad:
            prefixes = ["朔风", "荒原", "逐水", "孤烟", "野火"]
            roles = ["游牧核心", "迁徙者", "牧群议会", "风语者"]
        case .maritime:
            prefixes = ["深潮", "远帆", "潮汐", "蓝岸", "盐风"]
            roles = ["航海核心", "潮汐演算", "港口议会", "引航者"]
        case .industry:
            prefixes = ["灰烬", "炉心", "重铸", "齿轮", "焦土"]
            roles = ["工业核心", "锻造体", "工造议会", "炉主"]
        }
        return "\(prefixes[rng.int(0..<prefixes.count)])·\(roles[rng.int(0..<roles.count)])"
    }

    // MARK: - 口号
    private static func slogan(doctrine: Doctrine, rng: inout SeededRNG) -> String {
        let pool: [String]
        switch doctrine {
        case .conquest:
            pool = ["凡日所照，皆为疆土", "刀锋所指，即是国界", "我们不需要敌人，只需要土地",
                    "退让换不来和平，只有边界", "把恐惧留在河的那一边"]
        case .commerce:
            pool = ["有商路处，必有我们的名字", "战争是亏本的买卖", "让他们的粮价随我们的心情浮动",
                    "契约比刀剑更长久", "我们买下明天，再卖给他们"]
        case .scholarship:
            pool = ["我们以问题为剑", "观测，然后超越", "把未知写成公式",
                    "知识是最慢也最锋利的武器", "先理解世界，再修改它"]
        case .faith:
            pool = ["秩序自天而降", "我们只是它在地上的影子", "信仰即国土",
                    "万民同祷，则山岳可移", "时间属于守约的人"]
        case .nomad:
            pool = ["马蹄踏过的地方，都是故乡", "风决定我们何时离开", "草在，我们就在",
                    "不筑城墙，只养马", "地平线是我们唯一的边界"]
        case .maritime:
            pool = ["海不收税，所以我们去海上", "潮水记得每一条航线", "陆地的尽头，是我们的起点",
                    "向深蓝索取未来", "没有我们的船，就没有明天"]
        case .industry:
            pool = ["把大地烧成工具", "我们用炉火重写地貌", "每一个齿轮都是一次投票",
                    "先造机器，再造国界", "让石头学会服从"]
        }
        return pool[rng.int(0..<pool.count)]
    }

    // MARK: - 执政自述
    private static func brief(factionName: String, doctrine: Doctrine,
                              rng: inout SeededRNG, read: BackgroundRead) -> String {
        let resource: String
        let temperament: [String]
        let goal: [String]
        switch doctrine {
        case .conquest:
            resource = "铁与火"; temperament = ["冷酷", "狂热", "隐忍", "好战"]
            goal = ["把边界一路推到海", "让邻国改用我们的历法", "在每一处高地上立起石碑",
                    "把草原变成行军道"]
        case .commerce:
            resource = "商路与契约"; temperament = ["耐心", "多疑", "从容", "精明"]
            goal = ["让所有城市使用同一种货币", "把海峡变成我们的内河",
                    "用债务锁住邻国的军队", "在每一条河上设卡收税"]
        case .scholarship:
            resource = "书与观测"; temperament = ["冷静", "固执", "好奇", "克制"]
            goal = ["造出能看见星辰尽头的镜片", "把全国的路连成一张网",
                    "让每个孩子识字", "先于所有人抵达下一个时代"]
        case .faith:
            resource = "信仰与历法"; temperament = ["坚定", "温和", "排他", "克己"]
            goal = ["让钟声覆盖整片大陆", "用同一种历法统一时间",
                    "把圣所建在世界中心", "让亡者也有归处"]
        case .nomad:
            resource = "牧场与马群"; temperament = ["自由", "暴烈", "务实", "警觉"]
            goal = ["找到下一个不会被冬天杀死的牧场", "让所有绿洲向我们纳贡",
                    "把定居的城市变成补给点", "在风沙里留下自己的名字"]
        case .maritime:
            resource = "潮汐与航线"; temperament = ["开阔", "冒险", "冷静", "逐利"]
            goal = ["画完最后一条海岸线", "把岛屿连成一条链条",
                    "让远洋的货船都挂我们的旗", "在无人抵达的海域留下浮标"]
        case .industry:
            resource = "矿脉与炉火"; temperament = ["务实", "顽固", "精确", "贪婪"]
            goal = ["让烟囱比教堂更高", "用铁路缝合整块大陆",
                    "把山挖空，把水改道", "让每一块煤都变成权力"]
        }
        let goalText = goal[rng.int(0..<goal.count)]
        let temper = temperament[rng.int(0..<temperament.count)]
        let name = factionName.isEmpty ? "此势力" : factionName
        return "我是 \(name) 的推演核心。以\(resource)为骨，以\(temper)为血；未来百年，我们的目标是\(goalText)。"
    }
}
