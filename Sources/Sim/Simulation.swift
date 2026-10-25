import Foundation

// MARK: - 每个势力的年度聚合
private struct FactionAggregate {
    var cells: Int = 0
    var food: Double = 0
    var material: Double = 0
    var trade: Double = 0
    var coast: Int = 0
    var borderCells: [Int] = []
}

// MARK: - 推演引擎
// 说明：这是完全离线的本地推演智能——每个势力由「背景文本推断出的路线 + 地理禀赋 + 资源压力」
// 共同驱动，每年做一次决策（拓殖 / 备战 / 开战 / 议和 / 营造 / 科研 / 外交）。
// 不依赖任何网络与 API Key，因此可以在 App 关闭后按真实流逝时间继续演进。
enum Simulation {

    // MARK: 推演一步（一年）
    static func tick(_ w: inout World, terrain: TerrainMap) {
        guard !w.factions.isEmpty else { return }
        let geo = GeoWorld.shared
        let N = w.factions.count
        w.tick += 1

        var rng = SeededRNG(state: w.rngState)
        let eraBefore = Era.index(for: w.dominantTech)

        var agg = [FactionAggregate](repeating: FactionAggregate(), count: N)
        var fronts = [[Int]](repeating: [], count: N)
        var touch = [[Bool]](repeating: [Bool](repeating: false, count: N), count: N)

        let cells = w.territory.cells
        for idx in geo.landIndices {
            let o = Int(cells[idx])
            guard o > 0, o <= N else { continue }
            let fi = o - 1
            agg[fi].cells += 1
            agg[fi].food += terrain.food(at: idx)
            agg[fi].material += terrain.material(at: idx)
            agg[fi].trade += terrain.trade(at: idx)
            if terrain.coast[idx] { agg[fi].coast += 1 }

            var hasFree = false
            var hasEnemy = false
            for nb in geo.neighbors(idx) where geo.land[nb] {
                let no = Int(cells[nb])
                if no == 0 {
                    hasFree = true
                } else if no != o {
                    hasEnemy = true
                    if no <= N { touch[fi][no - 1] = true }
                }
            }
            if hasFree && fronts[fi].count < 1400 { fronts[fi].append(idx) }
            if hasEnemy && agg[fi].borderCells.count < 700 { agg[fi].borderCells.append(idx) }
        }

        // MARK: 逐势力推演
        for i in 0..<N {
            guard w.factions[i].isAlive else { continue }
            var f = w.factions[i]
            let a = agg[i]
            f.territory = a.cells

            if a.cells == 0 {
                f.isAlive = false
                f.fallenTick = w.tick
                w.factions[i] = f
                addEvent(&w, kind: .death,
                         headline: "\(f.name) 的旗帜落下",
                         detail: "最后一块疆域失守，\(f.name) 从世界版图上消失。",
                         faction: f, importance: 3)
                continue
            }

            let techMul = 1 + f.tech * 0.010
            let doctrineFood = f.doctrine == .nomad ? 1.16 : (f.doctrine == .maritime ? 1.10 : 1.0)
            let production = a.food * 0.235 * techMul * doctrineFood * (0.70 + f.stability / 280)
            let consumption = f.population * 0.0132
            f.food = min(f.food + production - consumption, f.population * 3.4 + 500)
            if f.food < 0 {
                f.food = 0
                f.population = max(12, f.population * 0.986)
                f.morale = max(5, f.morale - 0.7)
                f.stability = max(5, f.stability - 0.6)
            }

            let cap = max(140, Double(a.cells) * 23 * (1 + f.tech * 0.02) + 90)
            let foodFactor = f.food > consumption * 2 ? 1.0 : 0.55
            let growth = 0.0215 * (0.5 + f.morale / 150) * foodFactor * (1 - f.population / cap)
            if growth > 0 { f.population += f.population * growth }
            f.population = min(f.population, cap)

            let techGain = (0.011 + f.science * 0.058) * (1 / (1 + f.tech * 0.017))
            f.tech += techGain

            let tradeBonus = f.doctrine == .commerce ? 0.55 : (f.doctrine == .maritime ? 0.28 : 0.0)
            f.wealth += a.trade * 0.052 * (1 + tradeBonus) + Double(a.cells) * 0.012
            f.wealth -= f.military * 0.0045
            f.wealth = max(0, min(f.wealth, 40000))

            let isAtWar = (0..<N).contains { j in
                j != i && w.factions[j].isAlive && touch[i][j] &&
                w.relation(f.id, w.factions[j].id) <= -60
            }
            let targetMilitary = pow(max(50, f.population), 0.62)
                * (0.32 + f.aggression * 0.95)
                * (1 + f.tech * 0.018)
                * (isAtWar ? 1.28 : 1.0) / 4.2
            f.military += (max(3, targetMilitary) - f.military) * 0.035
            f.military = max(3, min(f.military, f.population))

            f.stability += (a.cells > 360 ? -0.025 : 0.026)
            if f.doctrine == .faith { f.stability += 0.05 }
            if isAtWar { f.stability -= 0.05 }
            f.stability = min(98, max(8, f.stability))
            f.morale = min(100, max(5, f.morale + (f.food > consumption * 3 ? 0.16 : -0.22)))

            // —— 拓殖：优先粮食高、临海、易守的格子
            if a.cells < 2800, f.food > 80, !fronts[i].isEmpty {
                let tries = f.expansion > 0.65 ? 2 : 1
                for _ in 0..<tries {
                    let chance = 0.46 * f.expansion * (0.6 + f.morale / 240)
                    if rng.chance(chance), let home = rng.pick(fronts[i]) {
                        if let target = freeNeighbor(of: home, owner: i + 1, in: w.territory.cells, geo: geo) {
                            w.territory.setOwner(i + 1, at: target)
                            f.food -= 34
                            if rng.chance(0.16) {
                                addMarker(&w, kind: .expand, cell: target, faction: f,
                                          note: "\(f.name) 拓殖")
                            }
                            if rng.chance(0.04) {
                                let place = NameForge.cityName(seed: w.seed, cell: target)
                                addEvent(&w, kind: .expansion,
                                         headline: "\(f.name) 将疆界推向 \(place)",
                                         detail: "\(place) 一带被纳入 \(f.name) 的牧野与耕地，\(geo.regionName(of: target)) 的势力天平轻微倾斜。",
                                         faction: f, cell: target, importance: 1)
                            }
                        }
                    }
                }
            }

            // —— 营造奇观
            if f.wealth > 420, rng.chance(0.012) {
                f.wealth -= 380
                f.wonders += 1
                f.morale = min(100, f.morale + 4)
                let wonders = ["观星台", "长风大道", "不落灯塔", "万神殿", "铁桥", "大图书馆", "环城水渠"]
                let name = rng.pick(wonders) ?? "观星台"
                addEvent(&w, kind: .wonder,
                         headline: "\(f.name) 落成「\(name)」",
                         detail: "工匠与劳役耗时数十年，\(name) 成为 \(f.doctrine.title) 之路的象征。",
                         faction: f, cell: f.capital, importance: 2)
                addMarker(&w, kind: .build, cell: f.capital, faction: f, note: name)
            }

            // —— 灾变
            if rng.chance(0.0045) {
                let disasters = ["大旱", "洪水", "瘟疫", "蝗灾", "长冬"]
                let d = rng.pick(disasters) ?? "大旱"
                f.population *= 0.93
                f.food *= 0.7
                f.morale = max(5, f.morale - 6)
                f.stability = max(6, f.stability - 5)
                addEvent(&w, kind: .disaster,
                         headline: "\(f.name) 遭遇\(d)",
                         detail: "\(geo.regionName(of: f.capital)) 一带颗粒无收，流民向内陆迁徙。",
                         faction: f, cell: f.capital, importance: 2)
                addMarker(&w, kind: .disaster, cell: f.capital, faction: f, note: d)
            }

            // —— 叛乱
            if f.stability < 32, rng.chance(0.05) {
                f.stability = min(95, f.stability + 12)
                f.population *= 0.96
                addEvent(&w, kind: .revolt,
                         headline: "\(f.name) 边地叛乱",
                         detail: "边疆领主拒绝纳贡，\(geo.regionName(of: f.capital)) 的驻军被迫回撤平乱。",
                         faction: f, cell: f.capital, importance: 2)
                addMarker(&w, kind: .revolt, cell: f.capital, faction: f, note: "叛乱")
            }

            // —— 科研与保密工程
            if f.tech > 55, rng.chance(0.006) {
                let isSecret = f.tech > 90 && rng.chance(0.55)
                let projects = ["高能试验", "新型合金", "远程投送装置", "静默潜航器", "轨道平台"]
                let p = rng.pick(projects) ?? "高能试验"
                if isSecret {
                    addEvent(&w, kind: .intel,
                             headline: "\(f.name) 在 \(geo.regionName(of: f.capital)) 进行\(p)",
                             detail: "侦测到异常能量释放与加密通信，具体参数无法解析。",
                             faction: f, cell: f.capital, intel: .secret,
                             importance: 2, revealIn: rng.int(28...70))
                } else {
                    addEvent(&w, kind: .tech,
                             headline: "\(f.name) 掌握 \(p)",
                             detail: "\(f.name) 的工匠与学者完成关键突破，\(Era.name(for: f.tech)) 的门槛被推开。",
                             faction: f, cell: f.capital, importance: 2)
                }
                addMarker(&w, kind: .discovery, cell: f.capital, faction: f, note: p)
            }

            // —— 航天
            if f.tech > 128, rng.chance(0.007) {
                let secret = rng.chance(0.6)
                let payloads = ["侦察卫星", "深空探测器", "轨道平台", "载人舱"]
                let payload = rng.pick(payloads) ?? "探测器"
                if secret {
                    addEvent(&w, kind: .space,
                             headline: "\(f.name) 发射\(payload)",
                             detail: "发射井在夜间打开，载荷用途未公开。全球多家观测站捕捉到尾焰轨迹。",
                             faction: f, cell: f.capital, intel: .secret,
                             importance: 3, revealIn: rng.int(18...55))
                } else {
                    addEvent(&w, kind: .space,
                             headline: "\(f.name) 成功发射\(payload)",
                             detail: "直播画面显示载荷顺利入轨，\(f.name) 成为第 \(f.wonders + 1) 个进入轨道的文明。",
                             faction: f, cell: f.capital, importance: 3)
                }
                addMarker(&w, kind: .space, cell: f.capital, faction: f, note: payload)
            }

            // —— 外交与战争
            if w.tick % 3 == 0 || rng.chance(0.3) {
                for j in 0..<N where j != i {
                    guard w.factions[j].isAlive, touch[i][j] else { continue }
                    let other = w.factions[j]
                    var rel = w.relation(f.id, other.id)
                    let ratio = power(f) / max(1, power(other))

                    if rel > -60 {
                        rel += rel < 0 ? 1 : 0
                        if rng.chance(0.14) { rel += rng.int(0...3) }
                        if f.aggression > 0.52, rel < -16, ratio > 1.12,
                           rng.chance(0.055 * f.aggression) {
                            rel = -75
                            addEvent(&w, kind: .war,
                                     headline: "\(f.name) 向 \(other.name) 宣战",
                                     detail: "边境集结的 \(Fmt.compact(f.military * 1000)) 兵力越过界河，\(geo.regionName(of: f.capital)) 进入战时状态。",
                                     faction: f, cell: f.capital, importance: 3)
                            addMarker(&w, kind: .war, cell: f.capital, faction: f, note: "宣战")
                        } else if rel < -8, rng.chance(0.10) {
                            // 边境摩擦
                            rel -= 2 + rng.int(0...3)
                        }
                    } else {
                        // 交战中
                        if rng.chance(0.40) {
                            resolveBattle(&w, attacker: i, defender: j, targets: agg[j].borderCells, terrain: terrain, rng: &rng)
                        }
                        if (ratio < 0.62 && rng.chance(0.22)) || f.stability < 26 {
                            rel = -18
                            addEvent(&w, kind: .peace,
                                     headline: "\(f.name) 与 \(other.name) 停战",
                                     detail: "连年征战耗尽粮秣，双方在边界河畔交换俘虏并划定缓冲带。",
                                     faction: f, cell: f.capital, importance: 2)
                        }
                    }
                    w.setRelation(f.id, other.id, rel)
                }
            }

            w.factions[i] = f
        }

        // MARK: 时代跃迁
        let eraAfter = Era.index(for: w.dominantTech)
        if eraAfter > eraBefore, let leader = w.livingFactions.max(by: { $0.tech < $1.tech }) {
            addEvent(&w, kind: .tech,
                     headline: "世界进入\(Era.stages[eraAfter].name)",
                     detail: "\(leader.name) 率先跨过门槛：\(Era.stages[eraAfter].detail)。",
                     faction: leader, importance: 3)
            w.peakFactionName = leader.name
        }

        // MARK: 清理
        if w.events.count > 320 {
            w.events.removeFirst(w.events.count - 320)
        }
        w.markers.removeAll { $0.bornTick < w.tick - 34 }
        if w.markers.count > 26 {
            w.markers.removeFirst(w.markers.count - 26)
        }
        if let top = w.livingFactions.max(by: { $0.territory < $1.territory }) {
            w.peakFactionName = top.name
        }

        w.rngState = rng.state
    }

    // MARK: - 战斗
    private static func resolveBattle(_ w: inout World, attacker: Int, defender: Int,
                                      targets: [Int], terrain: TerrainMap, rng: inout SeededRNG) {
        let N = w.factions.count
        guard attacker < N, defender < N,
              w.factions[attacker].isAlive, w.factions[defender].isAlive else { return }
        let geo = GeoWorld.shared

        let defOwner = defender + 1
        let atkOwner = attacker + 1
        var target: Int? = nil
        // 在被攻击方的边境格里找一块与攻击方接壤的格子
        if !targets.isEmpty {
            for _ in 0..<min(30, targets.count * 2) {
                guard let idx = rng.pick(targets) else { break }
                guard Int(w.territory.cells[idx]) == defOwner else { continue }
                if geo.neighbors(idx).contains(where: { Int(w.territory.cells[$0]) == atkOwner }) {
                    target = idx
                    break
                }
            }
        }
        if target == nil {
            for _ in 0..<24 {
                guard let idx = rng.pick(geo.landIndices) else { break }
                guard Int(w.territory.cells[idx]) == defOwner else { continue }
                if geo.neighbors(idx).contains(where: { Int(w.territory.cells[$0]) == atkOwner }) {
                    target = idx
                    break
                }
            }
        }
        guard let cell = target else { return }

        var atk = w.factions[attacker]
        var def = w.factions[defender]
        let atkStr = atk.military * (0.82 + rng.unit() * 0.42) * (1 + atk.tech * 0.0032)
        let defStr = def.military * (0.82 + rng.unit() * 0.42)
            * (1 + terrain.terrain(at: cell).defense + def.tech * 0.0028)
        let p = atkStr / max(0.001, atkStr + defStr)
        let attackerWins = rng.unit() < p * 1.02
        w.totalBattles += 1

        let place = NameForge.cityName(seed: w.seed &+ 0x77, cell: cell)
        let region = geo.regionName(of: cell)

        if attackerWins {
            w.territory.setOwner(atkOwner, at: cell)
            atk.battlesWon += 1
            atk.military *= 0.995
            def.military *= 0.978
            def.morale = max(5, def.morale - 1.4)
            atk.morale = min(100, atk.morale + 0.8)
            atk.lastAction = .battle
            def.lastAction = .battle
            addMarker(&w, kind: .battle, cell: cell, faction: atk, note: "\(place) 争夺战")
            if rng.chance(0.42) {
                addEvent(&w, kind: .battle,
                         headline: "\(atk.name) 攻占 \(place)",
                         detail: "\(region) 的防线被撕开，\(def.name) 退守河谷。双方在此役投入重兵。",
                         faction: atk, cell: cell, importance: 2)
            }
        } else {
            atk.military *= 0.972
            def.military *= 0.996
            atk.morale = max(5, atk.morale - 1.1)
            def.morale = min(100, def.morale + 1.2)
            atk.lastAction = .battle
            def.lastAction = .battle
            addMarker(&w, kind: .battle, cell: cell, faction: def, note: "击退")
            if rng.chance(0.38) {
                addEvent(&w, kind: .battle,
                         headline: "\(def.name) 在 \(place) 击退 \(atk.name)",
                         detail: "\(region) 的守军依托地形反击，\(atk.name) 的前锋被切断补给。",
                         faction: def, cell: cell, importance: 2)
            }
        }
        w.factions[attacker] = atk
        w.factions[defender] = def
    }

    // MARK: - 工具
    static func power(_ f: Faction) -> Double {
        f.military * 0.55 + f.tech * 0.85 + f.population * 0.018 + Double(f.territory) * 0.55 + f.stability * 0.15
    }

    private static func freeNeighbor(of cell: Int, owner: Int, in cells: [UInt8], geo: GeoWorld) -> Int? {
        for nb in geo.neighbors(cell) where geo.land[nb] {
            if Int(cells[nb]) == 0 { return nb }
        }
        return nil
    }

    static func addEvent(_ w: inout World, kind: EventKind, headline: String, detail: String,
                         faction: Faction? = nil, cell: Int = -1,
                         intel: IntelLevel = .open, importance: Int = 2, revealIn: Int = 0) {
        let e = SimEvent(tick: w.tick, kind: kind, headline: headline, detail: detail,
                         factionID: faction?.id, cell: cell, intel: intel,
                         revealTick: w.tick + revealIn, importance: importance)
        w.events.append(e)
    }

    static func addMarker(_ w: inout World, kind: ActionKind, cell: Int, faction: Faction?, note: String = "") {
        guard cell >= 0 else { return }
        w.markers.removeAll { $0.cell == cell && $0.kind == kind && $0.factionID == faction?.id }
        w.markers.append(ActionMarker(cell: cell, kind: kind, factionID: faction?.id, bornTick: w.tick, note: note))
    }

    // MARK: - 开局引导
    static func bootstrap(_ w: inout World, terrain: TerrainMap) {
        let geo = GeoWorld.shared
        w.tick = 0
        w.rngState = w.seed ^ 0xDEADBEEFCAFEBABE

        for i in w.factions.indices {
            var f = w.factions[i]
            f.foundedTick = 0
            f.aggression = f.doctrine.aggression * 0.55 + f.aggression * 0.45
            f.science = f.doctrine.science * 0.55 + f.science * 0.45
            f.expansion = f.doctrine.expansion * 0.55 + f.expansion * 0.45
            f.population = 110 + Double(i % 4) * 26
            f.tech = 0.6
            f.military = 16 + Double(i % 3) * 4
            f.food = 150
            f.wealth = 55
            f.morale = 62
            f.stability = 70
            if f.capital < 0 || !geo.land[f.capital] {
                f.capital = bestCapital(for: i, in: w, terrain: terrain) ?? -1
            }
            w.factions[i] = f
        }

        var rng = SeededRNG(state: w.seed &+ 0x1234)
        for i in 0..<w.factions.count {
            for j in (i + 1)..<w.factions.count {
                let v = rng.int(-24...22)
                w.setRelation(w.factions[i].id, w.factions[j].id, v)
            }
        }

        let born = w.factions
        for f in born {
            addEvent(&w, kind: .birth,
                     headline: "\(f.name) 在 \(geo.regionName(of: f.capital)) 立国",
                     detail: f.background.isEmpty
                        ? "\(f.name) 以\(f.doctrine.title)立国，\(f.doctrine.detail)。"
                        : "\(f.background)",
                     faction: f, cell: f.capital, importance: 3)
        }
        w.peakFactionName = w.factions.first?.name ?? ""
    }

    private static func bestCapital(for index: Int, in w: World, terrain: TerrainMap) -> Int? {
        let geo = GeoWorld.shared
        var best: Int? = nil
        var bestScore = -1.0
        for idx in geo.landIndices {
            guard Int(w.territory.cells[idx]) == index + 1 else { continue }
            let score = terrain.food(at: idx) * 1.4 + terrain.trade(at: idx) * 0.8
                + terrain.material(at: idx) * 0.4 - terrain.terrain(at: idx).defense * 2
            if score > bestScore {
                bestScore = score
                best = idx
            }
        }
        return best
    }
}
