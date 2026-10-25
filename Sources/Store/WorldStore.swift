import SwiftUI
import Combine
import UIKit

struct CatchUpReport: Equatable {
    var worldName: String
    var ticks: Int
    var progress: Double
}

// MARK: - 世界仓库 / 时间推进器
@MainActor
final class WorldStore: ObservableObject {
    @Published private(set) var worlds: [World] = []
    @Published var runningWorldID: UUID? = nil
    @Published var isPaused: Bool = false
    @Published var catchUp: CatchUpReport? = nil
    @Published var toast: String? = nil

    private var terrainCache: [UInt64: TerrainMap] = [:]
    private var timer: Timer?
    private var accumulator: Double = 0
    private var lastFrame = Date()
    private var lastSave = Date()
    private var dirty = false
    private var catchUpTask: Task<Void, Never>?

    private static var storeURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("worlds.json")
    }

    init() {
        load()
        lastFrame = Date()
        startLoop()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            await catchUpAll()
        }
    }

    // MARK: - 地形（按种子缓存，不落盘）
    func terrain(for world: World) -> TerrainMap {
        if let t = terrainCache[world.seed] { return t }
        let t = TerrainMap.generate(seed: world.seed)
        terrainCache[world.seed] = t
        return t
    }

    // MARK: - 查询
    func index(of id: UUID) -> Int? {
        worlds.firstIndex { $0.id == id }
    }

    func world(_ id: UUID) -> World? {
        guard let i = index(of: id) else { return nil }
        return worlds[i]
    }

    // MARK: - 增删改
    func add(_ world: World) {
        worlds.append(world)
        dirty = true
        save()
    }

    func update(_ world: World) {
        guard let i = index(of: world.id) else { return }
        worlds[i] = world
        dirty = true
    }

    func delete(_ id: UUID) {
        worlds.removeAll { $0.id == id }
        if runningWorldID == id { runningWorldID = nil }
        save()
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = index(of: id) else { return }
        worlds[i].name = name
        dirty = true
    }

    func setContinuous(_ id: UUID, _ value: Bool) {
        guard let i = index(of: id) else { return }
        worlds[i].continuous = value
        worlds[i].lastActiveAt = Date()
        dirty = true
        save()
        flash(value ? "已开启持续演变" : "已停止持续演变")
    }

    func setSpeed(_ id: UUID, _ speed: Int) {
        guard let i = index(of: id) else { return }
        worlds[i].speed = speed
        dirty = true
    }

    func togglePause() {
        isPaused.toggle()
        Haptics.select()
    }

    func flash(_ message: String) {
        withAnimation(Motion.quick) { toast = message }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            withAnimation(Motion.quick) { self.toast = nil }
        }
    }

    // MARK: - 进入 / 退出推演
    func enter(_ id: UUID) {
        runningWorldID = id
        isPaused = false
        accumulator = 0
        if let i = index(of: id) {
            worlds[i].lastActiveAt = Date()
        }
        catchUpIfNeeded(id)
    }

    func exit() {
        if let id = runningWorldID, let i = index(of: id) {
            worlds[i].lastActiveAt = Date()
        }
        runningWorldID = nil
        save()
    }

    // MARK: - 主循环
    private func startLoop() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func advance() {
        let now = Date()
        let dt = min(0.3, now.timeIntervalSince(lastFrame))
        lastFrame = now

        if let rid = runningWorldID, !isPaused, let i = index(of: rid) {
            let rate = SimSpeed.ticksPerSecond(worlds[i].speed)
            accumulator += dt * rate
            var steps = Int(accumulator)
            accumulator -= Double(steps)
            steps = min(steps, 8)
            if steps > 0 {
                var w = worlds[i]
                let map = terrain(for: w)
                for _ in 0..<steps {
                    Simulation.tick(&w, terrain: map)
                }
                w.lastActiveAt = now
                worlds[i] = w
                dirty = true
            }
        }

        // 其他开启「持续演变」的世界在后台按真实时间缓慢推进
        for i in worlds.indices {
            let w = worlds[i]
            guard w.continuous, w.phase == .evolving, w.id != runningWorldID else { continue }
            let elapsed = now.timeIntervalSince(w.lastActiveAt)
            if elapsed >= 1.4 {
                var work = w
                let map = terrain(for: work)
                let steps = min(3, max(1, Int(elapsed / 1.4)))
                for _ in 0..<steps { Simulation.tick(&work, terrain: map) }
                work.lastActiveAt = now
                worlds[i] = work
                dirty = true
            }
        }

        if dirty, now.timeIntervalSince(lastSave) > 4 {
            save()
        }
    }

    // MARK: - 时间补算
    func catchUpIfNeeded(_ id: UUID) {
        guard catchUp == nil, let i = index(of: id) else { return }
        let w = worlds[i]
        guard w.continuous, w.phase == .evolving else { return }
        let elapsed = Date().timeIntervalSince(w.lastActiveAt)
        let ticks = min(5000, Int(elapsed))
        guard ticks > 4 else { return }
        runCatchUp(index: i, ticks: ticks, map: terrain(for: w))
    }

    private func catchUpAll() async {
        for w in worlds where w.continuous && w.phase == .evolving {
            guard let i = index(of: w.id) else { continue }
            let elapsed = Date().timeIntervalSince(w.lastActiveAt)
            let ticks = min(3000, Int(elapsed))
            if ticks > 4 {
                runCatchUp(index: i, ticks: ticks, map: terrain(for: w))
                try? await Task.sleep(nanoseconds: 1_600_000_000)
            }
        }
    }

    private func runCatchUp(index i: Int, ticks: Int, map: TerrainMap) {
        var work = worlds[i]
        let name = work.name
        catchUp = CatchUpReport(worldName: name, ticks: ticks, progress: 0)
        catchUpTask?.cancel()
        catchUpTask = Task { @MainActor in
            var done = 0
            while done < ticks && !Task.isCancelled {
                let chunk = min(120, ticks - done)
                for _ in 0..<chunk { Simulation.tick(&work, terrain: map) }
                done += chunk
                if let c = catchUp {
                    catchUp = CatchUpReport(worldName: c.worldName, ticks: c.ticks,
                                            progress: Double(done) / Double(max(1, ticks)))
                }
                try? await Task.sleep(nanoseconds: 6_000_000)
            }
            work.lastActiveAt = Date()
            if let idx = self.index(of: work.id) {
                self.worlds[idx] = work
            }
            self.save()
            withAnimation(Motion.quick) { self.catchUp = nil }
        }
    }

    // MARK: - 持久化
    func save() {
        dirty = false
        lastSave = Date()
        do {
            let data = try JSONEncoder().encode(worlds)
            try data.write(to: WorldStore.storeURL, options: .atomic)
        } catch {
            // 静默失败：推演不应被存储问题打断
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: WorldStore.storeURL),
              let decoded = try? JSONDecoder().decode([World].self, from: data) else {
            return
        }
        worlds = decoded
    }

    // MARK: - 手动步进
    func stepOnce(_ id: UUID, years: Int = 10) {
        guard let i = index(of: id) else { return }
        var w = worlds[i]
        let map = terrain(for: w)
        for _ in 0..<years { Simulation.tick(&w, terrain: map) }
        worlds[i] = w
        dirty = true
    }
}

// MARK: - 世界搭建工具
enum WorldBuilder {
    static func blankWorld(name: String, seed: UInt64, level: RegionLevel) -> World {
        let geo = GeoWorld.shared
        var w = World(seed: seed, cellCount: geo.gridW * geo.gridH)
        w.name = name
        w.level = level
        return w
    }

    static func newFaction(index: Int, seed: UInt64) -> Faction {
        var f = Faction()
        f.colorIndex = index % Theme.factionColors.count
        f.name = NameForge.factionName(seed: seed, index: index)
        f.doctrine = Doctrine.allCases[index % Doctrine.allCases.count]
        f.aggression = f.doctrine.aggression
        f.industry = 0.5
        f.science = f.doctrine.science
        f.expansion = f.doctrine.expansion
        f.background = ""
        f.symbol = f.doctrine.symbol
        return f
    }

    @discardableResult
    static func paint(_ w: inout World, center: Int, radius: Int, owner: Int, terrain: TerrainMap) -> Int {
        let geo = GeoWorld.shared
        guard center >= 0, center < w.territory.cells.count else { return 0 }
        let cx = center % geo.gridW
        let cy = center / geo.gridW
        // radius 以「度」为单位，换算成格数
        let rCells = max(1, Int((Double(radius) / Double(geo.cellSize)).rounded()))
        var painted = 0
        for row in max(0, cy - rCells)...min(geo.gridH - 1, cy + rCells) {
            for col in (cx - rCells)...(cx + rCells) {
                var dc = col - cx
                if dc > geo.gridW / 2 { dc -= geo.gridW }
                if dc < -geo.gridW / 2 { dc += geo.gridW }
                let dr = row - cy
                if dc * dc + dr * dr > rCells * rCells { continue }
                let cc = (col % geo.gridW + geo.gridW) % geo.gridW
                let idx = row * geo.gridW + cc
                guard geo.land[idx] else { continue }
                w.territory.setOwner(owner, at: idx)
                painted += 1
            }
        }
        return painted
    }

    /// 智能初始分布：最远点采样，确保势力之间留有空间
    static func autoDistribute(_ w: inout World, terrain: TerrainMap) {
        let geo = GeoWorld.shared
        let count = w.factions.count
        guard count > 0 else { return }
        var rng = SeededRNG(state: w.seed &+ 0x22)
        let candidates = geo.landIndices
        guard !candidates.isEmpty else { return }

        var seeds: [Int] = []
        if let first = candidates.randomElement(using: &rng) { seeds.append(first) }
        while seeds.count < count {
            var best = -1.0
            var bestCell = candidates[0]
            for _ in 0..<420 {
                guard let cand = candidates.randomElement(using: &rng) else { break }
                let p = geo.center(of: cand)
                var minD = Double.greatestFiniteMagnitude
                for s in seeds {
                    let q = geo.center(of: s)
                    let dx = min(abs(p.x - q.x), Double(geo.gridW) - abs(p.x - q.x))
                    let dy = p.y - q.y
                    minD = min(minD, dx * dx + dy * dy)
                }
                if minD > best { best = minD; bestCell = cand }
            }
            seeds.append(bestCell)
        }

        let radius = max(3, w.level.brush + 2)
        for (i, seed) in seeds.enumerated() {
            guard i < w.factions.count else { break }
            paint(&w, center: seed, radius: radius, owner: i + 1, terrain: terrain)
            w.factions[i].capital = seed
        }
    }

    static func finish(_ w: inout World, terrain: TerrainMap) {
        for i in w.factions.indices {
            if let ai = w.factions[i].ai {
                w.factions[i].doctrine = ai.doctrine
                w.factions[i].aggression = ai.aggression
                w.factions[i].industry = ai.industry
                w.factions[i].science = ai.science
                w.factions[i].expansion = ai.expansion
                w.factions[i].colorIndex = ai.colorIndex
            }
            if w.factions[i].capital < 0 || !GeoWorld.shared.land[w.factions[i].capital] {
                w.factions[i].capital = bestOwnedCell(owner: i + 1, in: w, terrain: terrain) ?? -1
            }
        }
        Simulation.bootstrap(&w, terrain: terrain)
    }

    static func bestOwnedCell(owner: Int, in w: World, terrain: TerrainMap) -> Int? {
        let geo = GeoWorld.shared
        var best: Int? = nil
        var score = -Double.greatestFiniteMagnitude
        for idx in geo.landIndices where Int(w.territory.cells[idx]) == owner {
            let s = terrain.food(at: idx) * 1.5 + terrain.trade(at: idx) * 1.1
            if s > score { score = s; best = idx }
        }
        return best
    }

    // MARK: 示例战场
    static func sampleWorld() -> World {
        let geo = GeoWorld.shared
        var w = blankWorld(name: "赤土纪元", seed: 0x5EED_7742, level: .nation)
        let map = TerrainMap.generate(seed: w.seed)
        let specs: [(String, Double, Double, Doctrine, String)] = [
            ("朔方王朝", 38, 108, .conquest,
             "朔方起于黄河以北的苦寒之地，骑射为本，军功授爵。历代君主相信，边界只应存在于敌人的地图上。"),
            ("青霜公国", 48, 12, .industry,
             "青霜多山而少田，于是把全部才智投入炉火与机械。公会掌握矿山，工程师比贵族更受尊敬。"),
            ("赤铜商盟", 30, 44, .commerce,
             "赤铜盘踞三洲要冲，以商路与契约立国。没有常备大军，却能让邻国的粮价随它的心情涨落。"),
            ("白塔教国", 22, 78, .faith,
             "白塔的祭司观测星象，以历法统治时间。信众相信秩序来自天上，而人间只是它的影子。"),
            ("九泽联邦", -8, -55, .nomad,
             "九泽由数十个逐水草迁徙的部族结盟而成，没有固定的都城。谁能在雨季前找到牧场，谁就能号令诸部。")
        ]
        for (i, spec) in specs.enumerated() {
            var f = newFaction(index: i, seed: w.seed)
            f.name = spec.0
            f.background = spec.4
            let ai = FactionAIForge.generate(name: f.name, background: f.background,
                                             seed: w.seed &+ UInt64(i &* 997),
                                             usedColors: w.factions.map(\.colorIndex))
            f.ai = ai
            f.colorIndex = ai.colorIndex
            f.doctrine = ai.doctrine
            f.symbol = ai.doctrine.symbol
            f.aggression = ai.aggression
            f.industry = ai.industry
            f.science = ai.science
            f.expansion = ai.expansion
            w.factions.append(f)
            let cell = nearestLandCell(lat: spec.1, lon: spec.2)
            if cell >= 0 {
                w.factions[i].capital = cell
                paint(&w, center: cell, radius: 8, owner: i + 1, terrain: map)
            }
        }
        w.phase = .evolving
        finish(&w, terrain: map)
        w.continuous = true
        w.speed = 4
        w.lastActiveAt = Date()
        return w
    }

    static func previewDraft() -> World {
        var w = blankWorld(name: "朔风纪元", seed: 0x5EED_7742, level: .nation)
        w.factions = (0..<4).map { idx -> Faction in
            var f = newFaction(index: idx, seed: w.seed)
            let ai = FactionAIForge.generate(name: f.name,
                                             background: "起于河谷的农耕部族，重视历法与灌溉，信奉秩序。",
                                             seed: w.seed &+ UInt64(idx &* 97),
                                             usedColors: [])
            f.ai = ai
            f.colorIndex = ai.colorIndex
            f.doctrine = ai.doctrine
            f.symbol = ai.doctrine.symbol
            f.aggression = ai.aggression
            f.industry = ai.industry
            f.science = ai.science
            f.expansion = ai.expansion
            return f
        }
        let map = TerrainMap.generate(seed: w.seed)
        autoDistribute(&w, terrain: map)
        return w
    }

    static func nearestLandCell(lat: Double, lon: Double) -> Int {
        let geo = GeoWorld.shared
        var best = -1
        var bestD = Double.greatestFiniteMagnitude
        for idx in geo.landIndices {
            let ll = geo.latLon(of: idx)
            let d = pow(ll.lat - lat, 2) + pow((ll.lon - lon) * cos(lat * .pi / 180), 2)
            if d < bestD { bestD = d; best = idx }
        }
        return best
    }
}
