import SwiftUI

// MARK: - 地形类型
enum TerrainType: Int, CaseIterable {
    case ocean = 0, ice, tundra, taiga, forest, grassland, steppe, desert, savanna, rainforest, wetland, hills, mountain, plateau

    var name: String {
        switch self {
        case .ocean:      return "海洋"
        case .ice:        return "冰原"
        case .tundra:     return "苔原"
        case .taiga:      return "针叶林"
        case .forest:     return "温带林"
        case .grassland:  return "草原"
        case .steppe:     return "干草原"
        case .desert:     return "荒漠"
        case .savanna:    return "稀树草原"
        case .rainforest: return "雨林"
        case .wetland:    return "湿地"
        case .hills:      return "丘陵"
        case .mountain:   return "山地"
        case .plateau:    return "高原"
        }
    }

    var baseFood: Double {
        switch self {
        case .ocean: return 0
        case .ice: return 0.4
        case .tundra: return 1.8
        case .taiga: return 3.0
        case .forest: return 5.0
        case .grassland: return 7.4
        case .steppe: return 4.4
        case .desert: return 0.9
        case .savanna: return 5.2
        case .rainforest: return 5.6
        case .wetland: return 6.6
        case .hills: return 4.2
        case .mountain: return 1.6
        case .plateau: return 1.9
        }
    }

    var baseMaterial: Double {
        switch self {
        case .ocean: return 0
        case .ice: return 1.0
        case .tundra: return 2.0
        case .taiga: return 3.4
        case .forest: return 4.2
        case .grassland: return 2.6
        case .steppe: return 2.4
        case .desert: return 3.0
        case .savanna: return 2.8
        case .rainforest: return 4.8
        case .wetland: return 2.2
        case .hills: return 6.2
        case .mountain: return 8.0
        case .plateau: return 7.0
        }
    }

    var defense: Double {
        switch self {
        case .mountain: return 0.55
        case .plateau: return 0.40
        case .hills: return 0.28
        case .ice: return 0.30
        case .taiga: return 0.22
        case .rainforest: return 0.30
        case .wetland: return 0.24
        case .desert: return 0.10
        default: return 0
        }
    }

    var tint: Color {
        switch self {
        case .ocean: return Theme.ocean
        case .ice: return Color(hex: 0xA7B6B8)
        case .tundra: return Color(hex: 0x6F7C6B)
        case .taiga: return Color(hex: 0x39493B)
        case .forest: return Color(hex: 0x445741)
        case .grassland: return Color(hex: 0x6B6E45)
        case .steppe: return Color(hex: 0x82764C)
        case .desert: return Color(hex: 0x9D8659)
        case .savanna: return Color(hex: 0x8A7B47)
        case .rainforest: return Color(hex: 0x39533A)
        case .wetland: return Color(hex: 0x3F5A56)
        case .hills: return Color(hex: 0x5B5C42)
        case .mountain: return Color(hex: 0x625E56)
        case .plateau: return Color(hex: 0x6E6553)
        }
    }
}

// MARK: - 地形图（由种子确定性生成，不落盘）
final class TerrainMap {
    let gridW: Int
    let gridH: Int
    var type: [UInt8]
    var food: [UInt8]
    var material: [UInt8]
    var trade: [UInt8]
    var coastDist: [UInt8]
    let coast: [Bool]
    let land: [Bool]
    let landIndices: [Int]

    var landCount: Int { landIndices.count }

    init(gridW: Int, gridH: Int) {
        self.gridW = gridW
        self.gridH = gridH
        let n = gridW * gridH
        type = [UInt8](repeating: 0, count: n)
        food = [UInt8](repeating: 0, count: n)
        material = [UInt8](repeating: 0, count: n)
        trade = [UInt8](repeating: 0, count: n)
        coastDist = [UInt8](repeating: 0, count: n)
        let geo = GeoWorld.shared
        land = geo.land
        coast = geo.coastal
        landIndices = geo.landIndices
    }

    static func generate(seed: UInt64, geo: GeoWorld = .shared) -> TerrainMap {
        let map = TerrainMap(gridW: geo.gridW, gridH: geo.gridH)
        let noise = SeededNoise(seed: seed)
        let n = geo.gridW * geo.gridH

        // 距海距离（BFS）
        var dist = [Int](repeating: -1, count: n)
        var queue = [Int]()
        queue.reserveCapacity(n / 4)
        for i in 0..<n where !geo.land[i] {
            dist[i] = 0
            queue.append(i)
        }
        var head = 0
        while head < queue.count {
            let cur = queue[head]; head += 1
            let d = dist[cur]
            if d >= 40 { continue }
            for nb in geo.neighbors(cur) where dist[nb] == -1 {
                dist[nb] = d + 1
                queue.append(nb)
            }
        }

        for i in geo.landIndices {
            let col = i % geo.gridW
            let row = i / geo.gridW
            let lat = geo.latTop - Double(row) - 0.5
            let absLat = abs(lat)
            let d = max(0, dist[i])
            let continentality = min(1.0, Double(d) / 15.0)

            let fx = Double(col) * 0.052
            let fy = Double(row) * 0.052
            let rough = noise.fbm(fx, fy, octaves: 4, periodX: geo.gridW)
            let ridgeRaw = noise.fbm(fx * 0.62 + 41.3, fy * 0.62 + 9.1, octaves: 3, periodX: geo.gridW)
            let ridge = 1.0 - abs(ridgeRaw * 2.0 - 1.0)
            let detail = noise.fbm(fx * 3.1 + 7.7, fy * 3.1 + 2.3, octaves: 2, periodX: geo.gridW)

            let elevation = rough * 0.62 + ridge * ridge * 0.55 * (0.35 + 0.65 * continentality)
            let moistureRaw = noise.fbm(fx * 0.72 + 91.4, fy * 0.72 + 17.9, octaves: 3, periodX: geo.gridW)
            let moisture = moistureRaw * 0.72 + 0.34 - continentality * 0.30 + (geo.coastal[i] ? 0.10 : 0)
            let temp = 1.0 - absLat / 76.0 - elevation * 0.20 + (detail - 0.5) * 0.10

            var t: TerrainType
            if absLat > 68.5 || temp < 0.05 {
                t = .ice
            } else if absLat > 56.0 || temp < 0.17 {
                t = .tundra
            } else if temp < 0.36 && moisture > 0.40 {
                t = .taiga
            } else if moisture < 0.235 && absLat > 8 {
                t = .desert
            } else if absLat < 11.5 && moisture > 0.60 {
                t = .rainforest
            } else if absLat < 20.0 && moisture > 0.34 {
                t = .savanna
            } else if elevation > 0.70 {
                t = .mountain
            } else if elevation > 0.585 {
                t = .plateau
            } else if elevation > 0.485 {
                t = .hills
            } else if moisture > 0.66 && elevation < 0.30 {
                t = .wetland
            } else if moisture > 0.52 {
                t = .forest
            } else if moisture < 0.31 {
                t = .steppe
            } else {
                t = .grassland
            }

            let fert = 0.72 + moisture * 0.55 + (detail - 0.5) * 0.18
            var f = t.baseFood * fert
            if geo.coastal[i] { f *= 1.10 }
            var m = t.baseMaterial * (0.78 + rough * 0.5)
            if noise.hash2(col, row) > 0.937 { m += 6.5 }
            var tr = 0.6 + (geo.coastal[i] ? 6.4 : 0.0) + moisture * 1.4
            if t == .desert { tr *= 0.7 }
            if t == .ice || t == .tundra { tr *= 0.5 }

            map.type[i] = UInt8(t.rawValue)
            map.food[i] = UInt8(max(0, min(255, Int(f * 10))))
            map.material[i] = UInt8(max(0, min(255, Int(m * 10))))
            map.trade[i] = UInt8(max(0, min(255, Int(tr * 10))))
            map.coastDist[i] = UInt8(min(255, d))
        }
        return map
    }

    func terrain(at cell: Int) -> TerrainType {
        guard cell >= 0 && cell < type.count else { return .ocean }
        return TerrainType(rawValue: Int(type[cell])) ?? .ocean
    }

    func food(at cell: Int) -> Double { Double(food[cell]) / 10.0 }
    func material(at cell: Int) -> Double { Double(material[cell]) / 10.0 }
    func trade(at cell: Int) -> Double { Double(trade[cell]) / 10.0 }
}

// MARK: - 确定性噪声
struct SeededNoise {
    let seed: UInt64

    func hash2(_ x: Int, _ y: Int) -> Double {
        var h = UInt64(bitPattern: Int64(x)) &* 0x9E3779B97F4A7C15
        h ^= UInt64(bitPattern: Int64(y)) &* 0xC2B2AE3D27D4EB4F
        h ^= seed
        h ^= h >> 30
        h = h &* 0xBF58476D1CE4E5B9
        h ^= h >> 27
        h = h &* 0x94D049BB133111EB
        h ^= h >> 31
        return Double(h >> 11) / Double(1 << 53)
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    func value(_ x: Double, _ y: Double, periodX: Int) -> Double {
        let x0 = Int(floor(x)), y0 = Int(floor(y))
        let fx = x - Double(x0), fy = y - Double(y0)
        let p = max(1, periodX)
        func wx(_ v: Int) -> Int { ((v % p) + p) % p }
        let a = hash2(wx(x0), y0)
        let b = hash2(wx(x0 + 1), y0)
        let c = hash2(wx(x0), y0 + 1)
        let d = hash2(wx(x0 + 1), y0 + 1)
        let sx = smooth(fx), sy = smooth(fy)
        return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy
    }

    func fbm(_ x: Double, _ y: Double, octaves: Int, periodX: Int) -> Double {
        var sum = 0.0, amp = 0.55, freq = 1.0, norm = 0.0
        for _ in 0..<max(1, octaves) {
            sum += value(x * freq, y * freq, periodX: Int(Double(periodX) * freq)) * amp
            norm += amp
            amp *= 0.5
            freq *= 2.0
        }
        return norm > 0 ? sum / norm : sum
    }
}

// MARK: - 随机数（确定性，状态随世界持久化）
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64

    init(state: UInt64) { self.state = state == 0 ? 0x9E3779B97F4A7C15 : state }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func int(_ range: Range<Int>) -> Int {
        guard range.count > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % UInt64(range.count))
    }

    mutating func chance(_ p: Double) -> Bool { unit() < p }

    mutating func pick<T>(_ array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        return array[int(0..<array.count)]
    }
}
