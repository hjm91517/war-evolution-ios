import SwiftUI

// MARK: - 视口变换（世界坐标 0...360 × 0...142）
struct MapTransform {
    var zoom: CGFloat = 1
    var offset: CGSize = .zero

    static let worldW: CGFloat = 360
    static let worldH: CGFloat = 142

    func scale(for size: CGSize) -> CGFloat {
        min(size.width / MapTransform.worldW, size.height / MapTransform.worldH) * zoom
    }

    func viewPoint(fromMap p: CGPoint, in size: CGSize, yUp: Bool = false) -> CGPoint {
        let s = scale(for: size)
        let cx = size.width / 2 + offset.width
        let cy = size.height / 2 + offset.height
        return CGPoint(x: cx + (p.x - MapTransform.worldW / 2) * s,
                       y: cy + (p.y - MapTransform.worldH / 2) * s)
    }

    func mapPoint(fromView p: CGPoint, in size: CGSize) -> CGPoint {
        let s = max(0.0001, scale(for: size))
        let cx = size.width / 2 + offset.width
        let cy = size.height / 2 + offset.height
        return CGPoint(x: (p.x - cx) / s + MapTransform.worldW / 2,
                       y: (p.y - cy) / s + MapTransform.worldH / 2)
    }

    func clampedOffset(_ proposed: CGSize, size: CGSize) -> CGSize {
        let s = scale(for: size)
        let mapW = MapTransform.worldW * s
        let mapH = MapTransform.worldH * s
        let maxX = max(0, (mapW - size.width) / 2 + size.width * 0.25)
        let maxY = max(0, (mapH - size.height) / 2 + size.height * 0.25)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }
}

// MARK: - 疆域网格（预烘焙成 Path，避免逐帧遍历 5 万格）
struct TerritoryMesh {
    var fills: [Path]
    var borders: [Path]
    var claimRatio: Double
    var tick: Int

    static func empty(count: Int) -> TerritoryMesh {
        TerritoryMesh(fills: [Path](repeating: Path(), count: max(1, count)),
                      borders: [Path](repeating: Path(), count: max(1, count)),
                      claimRatio: 0, tick: -1)
    }

    static func build(_ world: World, geo: GeoWorld = .shared, step: Int = 1) -> TerritoryMesh {
        let W = geo.gridW, H = geo.gridH
        let n = max(1, world.factions.count)
        var fills = [Path](repeating: Path(), count: n)
        var borders = [Path](repeating: Path(), count: n)
        let cells = world.territory.cells
        guard cells.count == W * H else {
            return .empty(count: n)
        }
        let st = max(1, step)
        var claimed = 0

        for row in stride(from: 0, to: H, by: st) {
            var col = 0
            while col < W {
                let o = Int(cells[row * W + col])
                if o == 0 { col += st; continue }
                var end = col + st
                while end < W, Int(cells[row * W + end]) == o { end += st }
                if o <= n {
                    fills[o - 1].addRect(CGRect(x: CGFloat(col), y: CGFloat(row),
                                                width: CGFloat(end - col), height: CGFloat(st)))
                }
                claimed += end - col
                col = end
            }
        }

        if step == 1 {
            for idx in geo.landIndices {
                let o = Int(cells[idx])
                guard o > 0, o <= n else { continue }
                let col = idx % W
                let row = idx / W
                let right = (col + 1) % W
                if Int(cells[row * W + right]) != o {
                    borders[o - 1].move(to: CGPoint(x: CGFloat(col + 1), y: CGFloat(row)))
                    borders[o - 1].addLine(to: CGPoint(x: CGFloat(col + 1), y: CGFloat(row + 1)))
                }
                if row + 1 < H {
                    if Int(cells[(row + 1) * W + col]) != o {
                        borders[o - 1].move(to: CGPoint(x: CGFloat(col), y: CGFloat(row + 1)))
                        borders[o - 1].addLine(to: CGPoint(x: CGFloat(col + 1), y: CGFloat(row + 1)))
                    }
                } else {
                    borders[o - 1].move(to: CGPoint(x: CGFloat(col), y: CGFloat(row + 1)))
                    borders[o - 1].addLine(to: CGPoint(x: CGFloat(col + 1), y: CGFloat(row + 1)))
                }
            }
        }

        return TerritoryMesh(fills: fills, borders: borders,
                             claimRatio: Double(claimed) / Double(max(1, geo.landCount)),
                             tick: world.tick)
    }
}

extension GeoWorld {
    var landCount: Int { landIndices.count }
}

// MARK: - 地图画布
struct WorldMapCanvas: View {
    var world: World
    var mesh: TerritoryMesh?
    var selectedFaction: Int? = nil
    var zoom: CGFloat = 1
    var offset: CGSize = .zero
    var showGraticule: Bool = true
    var showTerritory: Bool = true
    var dimUnclaimed: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 360, size.height / 142) * zoom
            let cx = size.width / 2 + offset.width
            let cy = size.height / 2 + offset.height

            // 海面
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x0B171C), Color(hex: 0x050C0F), Color(hex: 0x04090B)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width * 0.4, y: size.height)))

            ctx.translateBy(x: cx, y: cy)
            ctx.scaleBy(x: s, y: s)
            ctx.translateBy(x: -180, y: -71)

            let geo = GeoWorld.shared

            // 经纬网
            if showGraticule {
                var grid = Path()
                for lon in stride(from: -180.0, through: 180.0, by: 15.0) {
                    grid.move(to: CGPoint(x: lon + 180, y: 0))
                    grid.addLine(to: CGPoint(x: lon + 180, y: 142))
                }
                for lat in stride(from: 84.0, through: -58.0, by: 15.0) {
                    let y = 84 - lat
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: 360, y: y))
                }
                ctx.stroke(grid, with: .color(Color.white.opacity(0.045)), lineWidth: 0.25)
                var equator = Path()
                equator.move(to: CGPoint(x: 0, y: 84))
                equator.addLine(to: CGPoint(x: 360, y: 84))
                ctx.stroke(equator, with: .color(Theme.gold.opacity(0.16)),
                           style: StrokeStyle(lineWidth: 0.32, dash: [3, 5]))
            }

            // 陆地
            ctx.fill(geo.landPath,
                     with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x2C3229), Color(hex: 0x3A3B2B), Color(hex: 0x2A2F26)]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: 142)),
                     style: FillStyle(eoFill: true))
            ctx.stroke(geo.landPath, with: .color(Theme.gold.opacity(0.20)), lineWidth: 0.30)

            // 疆域
            if showTerritory, let mesh {
                for (i, path) in mesh.fills.enumerated() where i < world.factions.count {
                    let color = Theme.factionColor(world.factions[i].colorIndex)
                    let isSelected = selectedFaction == i
                    let alpha = world.factions[i].isAlive ? (isSelected ? 0.95 : 0.78) : 0.28
                    ctx.fill(path, with: .color(color.opacity(alpha)))
                }
                for (i, path) in mesh.borders.enumerated() where i < world.factions.count {
                    let color = Theme.factionColor(world.factions[i].colorIndex)
                    let isSelected = selectedFaction == i
                    ctx.stroke(path, with: .color(color.opacity(isSelected ? 1.0 : 0.85)),
                               lineWidth: isSelected ? 0.65 : 0.42)
                }
            }

            // 外框
            var frame = Path()
            frame.addRect(CGRect(x: 0, y: 0, width: 360, height: 142))
            ctx.stroke(frame, with: .color(Color.white.opacity(0.06)), lineWidth: 0.4)
        }
    }
}

// MARK: - 缩略图
struct WorldThumbnail: View {
    var world: World
    var size: CGSize = CGSize(width: 104, height: 58)

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width / 360, canvasSize.height / 142)
            ctx.fill(Path(CGRect(origin: .zero, size: canvasSize)),
                     with: .color(Color(hex: 0x081216)))
            ctx.translateBy(x: (canvasSize.width - 360 * s) / 2,
                            y: (canvasSize.height - 142 * s) / 2)
            ctx.scaleBy(x: s, y: s)

            let geo = GeoWorld.shared
            ctx.fill(geo.landPath,
                     with: .color(Color(hex: 0x2E3228)),
                     style: FillStyle(eoFill: true))

            let W = geo.gridW, H = geo.gridH
            let cells = world.territory.cells
            guard cells.count == W * H else { return }
            var paths = [Path](repeating: Path(), count: max(1, world.factions.count))
            let st = 2
            for row in stride(from: 0, to: H, by: st) {
                var col = 0
                while col < W {
                    let o = Int(cells[row * W + col])
                    if o == 0 { col += st; continue }
                    var end = col + st
                    while end < W, Int(cells[row * W + end]) == o { end += st }
                    if o <= paths.count {
                        paths[o - 1].addRect(CGRect(x: CGFloat(col), y: CGFloat(row),
                                                    width: CGFloat(end - col), height: CGFloat(st)))
                    }
                    col = end
                }
            }
            for (i, p) in paths.enumerated() where i < world.factions.count {
                ctx.fill(p, with: .color(Theme.factionColor(world.factions[i].colorIndex).opacity(0.9)))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
        )
    }
}

// MARK: - 行动标记
struct MapMarkerBadge: View {
    var marker: ActionMarker
    var tint: Color
    var age: Int
    var highlight: Bool = false

    @State private var appear = false

    private var scale: CGFloat {
        let base: CGFloat = marker.kind == .space ? 1.15 : (marker.kind == .battle ? 1.0 : 0.9)
        return base * CGFloat(0.6 + 0.4 * min(1, Double(age) / 3.0))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 30, height: 30)
                .blur(radius: 6)
                .breathing(min: 0.4, max: 1.0, duration: 2.6)

            Circle()
                .strokeBorder(tint.opacity(0.45), lineWidth: 1)
                .frame(width: 24, height: 24)

            Circle()
                .fill(Theme.ink.opacity(0.88))
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(tint.opacity(0.7), lineWidth: 0.9))

            Image(systemName: marker.kind.symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
        }
        .scaleEffect((appear ? 1 : 0.2) * scale)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(Motion.spring.delay(Double(age) * 0.01)) { appear = true }
        }
    }
}
