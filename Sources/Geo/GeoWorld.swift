import SwiftUI
import CoreGraphics

// 世界几何：1° 等距圆柱投影，纬度 84°N → 58°S（裁掉南极的畸变带）
// 地图坐标：x = lon + 180 (0...360)，y = latTop - lat (0...142)
final class GeoWorld {
    static let shared = GeoWorld()

    let gridW: Int
    let gridH: Int
    let latTop: Double
    let latBottom: Double
    let land: [Bool]
    let landIndices: [Int]
    let rings: [[CGPoint]]
    let landPath: Path
    let coastal: [Bool]

    var aspect: CGFloat { CGFloat(gridW) / CGFloat(gridH) }

    /// 每格边长（度）
    var cellSize: CGFloat { 360.0 / CGFloat(gridW) }
    var mapWidth: CGFloat { 360.0 }
    var mapHeight: CGFloat { CGFloat(latTop - latBottom) }

    private struct Packed: Codable {
        let gridW: Int
        let gridH: Int
        let latTop: Double
        let latBottom: Double
        let land: Int
        let mask: String
        let rings: [[[Double]]]
    }

    private init() {
        var pw = 360, ph = 142
        var top = 84.0, bottom = -58.0
        var maskBits = Data()
        var ringData: [[[Double]]] = []

        if let url = Bundle.main.url(forResource: "world", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let packed = try? JSONDecoder().decode(Packed.self, from: data) {
            pw = packed.gridW
            ph = packed.gridH
            top = packed.latTop
            bottom = packed.latBottom
            maskBits = Data(base64Encoded: packed.mask) ?? Data()
            ringData = packed.rings
        }

        self.gridW = pw
        self.gridH = ph
        self.latTop = top
        self.latBottom = bottom

        var mask = [Bool](repeating: false, count: pw * ph)
        if !maskBits.isEmpty {
            maskBits.withUnsafeBytes { raw in
                guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                for i in 0..<(pw * ph) {
                    let byte = base[i / 8]
                    mask[i] = (byte >> UInt8(i % 8)) & 1 == 1
                }
            }
        }
        self.land = mask

        var indices: [Int] = []
        indices.reserveCapacity(16_000)
        for i in 0..<mask.count where mask[i] { indices.append(i) }
        self.landIndices = indices

        var pts: [[CGPoint]] = []
        pts.reserveCapacity(ringData.count)
        var path = Path()
        for ring in ringData {
            var line: [CGPoint] = []
            line.reserveCapacity(ring.count)
            for pair in ring where pair.count >= 2 {
                let x = pair[0] + 180.0
                let y = top - pair[1]
                line.append(CGPoint(x: x, y: y))
            }
            guard line.count >= 3 else { continue }
            pts.append(line)
            path.move(to: line[0])
            for p in line.dropFirst() { path.addLine(to: p) }
            path.closeSubpath()
        }
        self.rings = pts
        self.landPath = path

        // 海岸线标记
        var coast = [Bool](repeating: false, count: pw * ph)
        for i in indices {
            let col = i % pw
            let row = i / pw
            var isCoast = false
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nc = (col + dc + pw) % pw
                let nr = row + dr
                if nr < 0 || nr >= ph { continue }
                if !mask[nr * pw + nc] { isCoast = true; break }
            }
            coast[i] = isCoast
        }
        self.coastal = coast
    }

    // MARK: - 坐标换算
    func cellIndex(col: Int, row: Int) -> Int? {
        guard row >= 0 && row < gridH else { return nil }
        let c = (col % gridW + gridW) % gridW
        return row * gridW + c
    }

    func cellIndex(mapPoint p: CGPoint) -> Int? {
        let col = Int(floor(p.x / cellSize))
        let row = Int(floor(p.y / cellSize))
        return cellIndex(col: col, row: row)
    }

    func center(of cell: Int) -> CGPoint {
        let col = cell % gridW
        let row = cell / gridW
        let cs = cellSize
        return CGPoint(x: (CGFloat(col) + 0.5) * cs, y: (CGFloat(row) + 0.5) * cs)
    }

    func rect(of cell: Int) -> CGRect {
        let col = cell % gridW
        let row = cell / gridW
        let cs = cellSize
        return CGRect(x: CGFloat(col) * cs, y: CGFloat(row) * cs, width: cs, height: cs)
    }

    func latLon(of cell: Int) -> (lat: Double, lon: Double) {
        let col = cell % gridW
        let row = cell / gridW
        let lon = -180.0 + Double(col) + 0.5
        let lat = latTop - Double(row) - 0.5
        return (lat, lon)
    }

    func neighbors(_ cell: Int) -> [Int] {
        let col = cell % gridW
        let row = cell / gridW
        var out: [Int] = []
        out.reserveCapacity(4)
        for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let nr = row + dr
            if nr < 0 || nr >= gridH { continue }
            let nc = (col + dc + gridW) % gridW
            out.append(nr * gridW + nc)
        }
        return out
    }

    func longitude(of cell: Int) -> Double { latLon(of: cell).lon }
    func latitude(of cell: Int) -> Double { latLon(of: cell).lat }

    // 粗略大洲判定，用于地名生成
    func regionName(of cell: Int) -> String {
        let ll = latLon(of: cell)
        let lon = ll.lon, lat = ll.lat
        var continent = "远洋"
        if lon >= -170 && lon < -30 && lat > 12 { continent = "北陆" }
        else if lon >= -85 && lon < -30 && lat <= 12 { continent = "南陆" }
        else if lon >= -20 && lon < 55 && lat > 34 { continent = "西洲" }
        else if lon >= -20 && lon < 55 && lat <= 34 { continent = "中洲" }
        else if lon >= 55 && lon < 180 && lat > 10 { continent = "东陆" }
        else if lon >= 55 && lon < 180 && lat <= 10 { continent = "南洋" }
        else if lon >= 110 && lat <= -10 { continent = "南方大陆" }

        let ew = lon < -60 ? "西" : (lon > 100 ? "东" : "中")
        let ns = lat > 40 ? "北" : (lat < -15 ? "南" : "中")
        return "\(ew)\(ns)·\(continent)"
    }
}
