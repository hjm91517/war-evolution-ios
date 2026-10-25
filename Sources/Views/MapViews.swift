import SwiftUI
import UIKit

// MARK: - 视口变换（世界坐标以「度」为单位：0...360 × 0...142）
struct MapTransform {
    var zoom: CGFloat = 1
    var offset: CGSize = .zero

    static var worldW: CGFloat { GeoWorld.shared.mapWidth }
    static var worldH: CGFloat { GeoWorld.shared.mapHeight }

    func scale(for size: CGSize) -> CGFloat {
        min(size.width / MapTransform.worldW, size.height / MapTransform.worldH) * zoom
    }

    func viewPoint(fromMap p: CGPoint, in size: CGSize) -> CGPoint {
        let s = scale(for: size)
        let cx = size.width / 2 + offset.width
        let cy = size.height / 2 + offset.height
        return CGPoint(x: cx + (p.x - MapTransform.worldW / 2) * s,
                       y: cy + (p.y - MapTransform.worldH / 2) * s)
    }

    func mapRect(in size: CGSize) -> CGRect {
        let s = scale(for: size)
        let center = viewPoint(fromMap: CGPoint(x: MapTransform.worldW / 2, y: MapTransform.worldH / 2),
                               in: size)
        return CGRect(x: center.x - MapTransform.worldW / 2 * s,
                      y: center.y - MapTransform.worldH / 2 * s,
                      width: MapTransform.worldW * s,
                      height: MapTransform.worldH * s)
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
        let maxX = max(0, (mapW - size.width) / 2 + size.width * 0.22)
        let maxY = max(0, (mapH - size.height) / 2 + size.height * 0.22)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }
}

// MARK: - 疆域网格（烘焙成 Path，用于边界与缩略图）
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
        guard cells.count == W * H else { return .empty(count: n) }
        let st = max(1, step)
        let cs = geo.cellSize
        var claimed = 0

        for row in stride(from: 0, to: H, by: st) {
            var col = 0
            while col < W {
                let o = Int(cells[row * W + col])
                if o == 0 { col += st; continue }
                var end = col + st
                while end < W, Int(cells[row * W + end]) == o { end += st }
                if o <= n {
                    fills[o - 1].addRect(CGRect(x: CGFloat(col) * cs, y: CGFloat(row) * cs,
                                                width: CGFloat(end - col) * cs, height: CGFloat(st) * cs))
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
                let x0 = CGFloat(col) * cs
                let y0 = CGFloat(row) * cs
                let x1 = x0 + cs
                let y1 = y0 + cs
                let right = (col + 1) % W
                if Int(cells[row * W + right]) != o {
                    borders[o - 1].move(to: CGPoint(x: x1, y: y0))
                    borders[o - 1].addLine(to: CGPoint(x: x1, y: y1))
                }
                if row + 1 < H {
                    if Int(cells[(row + 1) * W + col]) != o {
                        borders[o - 1].move(to: CGPoint(x: x0, y: y1))
                        borders[o - 1].addLine(to: CGPoint(x: x1, y: y1))
                    }
                } else {
                    borders[o - 1].move(to: CGPoint(x: x0, y: y1))
                    borders[o - 1].addLine(to: CGPoint(x: x1, y: y1))
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

// MARK: - 疆域栅格（把格子画进位图再高质量放大，彻底消掉方格与锯齿）
enum TerritoryRaster {
    static func make(world: World, geo: GeoWorld = .shared) -> UIImage? {
        let w = geo.gridW
        let h = geo.gridH
        let cells = world.territory.cells
        guard cells.count == w * h, !world.factions.isEmpty else { return nil }

        var palette: [(UInt8, UInt8, UInt8)] = []
        palette.reserveCapacity(world.factions.count)
        for f in world.factions {
            let ui = UIColor(f.color)
            var r: CGFloat = 0.7, g: CGFloat = 0.7, b: CGFloat = 0.7, a: CGFloat = 1
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            palette.append((UInt8(r * 255), UInt8(g * 255), UInt8(b * 255)))
        }

        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        pixels.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            for i in 0..<(w * h) {
                let o = Int(cells[i])
                guard o > 0, o <= palette.count else { continue }
                let p = palette[o - 1]
                let j = i * 4
                base[j] = p.0
                base[j + 1] = p.1
                base[j + 2] = p.2
                base[j + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let cg = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                               bytesPerRow: w * 4, space: cs, bitmapInfo: info,
                               provider: provider, decode: nil, shouldInterpolate: true,
                               intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - 陆地遮罩形状
struct LandShape: Shape {
    func path(in rect: CGRect) -> Path {
        let geo = GeoWorld.shared
        var t = CGAffineTransform(translationX: rect.minX, y: rect.minY)
        t = t.scaledBy(x: rect.width / geo.mapWidth, y: rect.height / geo.mapHeight)
        var p = Path()
        p.addPath(geo.landPath, transform: t)
        return p
    }
}

// MARK: - 地图画布
struct WorldMapCanvas: View {
    var world: World
    var mesh: TerritoryMesh? = nil
    var territoryImage: UIImage? = nil
    var selectedFaction: Int? = nil
    var zoom: CGFloat = 1
    var offset: CGSize = .zero
    var showGraticule: Bool = true
    var showTexture: Bool = true
    var territoryOpacity: Double = 0.62
    var softEdge: Bool = true

    var body: some View {
        GeometryReader { g in
            let sz = g.size
            let s = min(sz.width / MapTransform.worldW, sz.height / MapTransform.worldH) * zoom
            let cx = sz.width / 2 + offset.width
            let cy = sz.height / 2 + offset.height
            let rect = CGRect(x: cx - MapTransform.worldW / 2 * s,
                              y: cy - MapTransform.worldH / 2 * s,
                              width: MapTransform.worldW * s,
                              height: MapTransform.worldH * s)

            ZStack {
                // 海面
                Rectangle()
                    .fill(
                        RadialGradient(colors: [Color(hex: 0x163A42), Color(hex: 0x0B2027), Color(hex: 0x071319)],
                                       center: UnitPoint(x: 0.28, y: 0.18),
                                       startRadius: 10, endRadius: max(sz.width, sz.height) * 0.95)
                    )

                // 经纬网
                if showGraticule {
                    Canvas { ctx, size in
                        ctx.translateBy(x: cx, y: cy)
                        ctx.scaleBy(x: s, y: s)
                        ctx.translateBy(x: -MapTransform.worldW / 2, y: -MapTransform.worldH / 2)
                        var grid = Path()
                        for lon in stride(from: -180.0, through: 180.0, by: 15.0) {
                            grid.move(to: CGPoint(x: lon + 180, y: 0))
                            grid.addLine(to: CGPoint(x: lon + 180, y: MapTransform.worldH))
                        }
                        for lat in stride(from: 84.0, through: -58.0, by: 15.0) {
                            let y = 84 - lat
                            grid.move(to: CGPoint(x: 0, y: y))
                            grid.addLine(to: CGPoint(x: MapTransform.worldW, y: y))
                        }
                        ctx.stroke(grid, with: .color(Color.white.opacity(0.055)), lineWidth: 0.28)
                        var equator = Path()
                        equator.move(to: CGPoint(x: 0, y: 84))
                        equator.addLine(to: CGPoint(x: MapTransform.worldW, y: 84))
                        ctx.stroke(equator, with: .color(Theme.gold.opacity(0.20)),
                                   style: StrokeStyle(lineWidth: 0.34, dash: [3, 6]))
                        _ = size
                    }
                }

                // 陆地卫星纹理
                if showTexture {
                    Image("earth")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: rect.width, height: rect.height)
                        .mask(
                            LandShape()
                                .frame(width: rect.width, height: rect.height)
                        )
                        .saturation(1.02)
                        .brightness(-0.03)
                        .contrast(1.04)
                        .position(x: rect.midX, y: rect.midY)
                } else {
                    LandShape()
                        .fill(Color(hex: 0x3A4638))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }

                // 疆域（栅格放大）
                if let image = territoryImage {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: rect.width, height: rect.height)
                        .opacity(territoryOpacity)
                        .blur(radius: softEdge ? 0.7 : 0)
                        .position(x: rect.midX, y: rect.midY)
                } else if let mesh, !mesh.fills.isEmpty {
                    Canvas { ctx, size in
                        ctx.translateBy(x: cx, y: cy)
                        ctx.scaleBy(x: s, y: s)
                        ctx.translateBy(x: -MapTransform.worldW / 2, y: -MapTransform.worldH / 2)
                        for (i, path) in mesh.fills.enumerated() where i < world.factions.count {
                            let color = Theme.factionColor(world.factions[i].colorIndex)
                            ctx.fill(path, with: .color(color.opacity(0.6)))
                        }
                        _ = size
                    }
                }

                // 海岸线 + 势力边界
                Canvas { ctx, size in
                    ctx.translateBy(x: cx, y: cy)
                    ctx.scaleBy(x: s, y: s)
                    ctx.translateBy(x: -MapTransform.worldW / 2, y: -MapTransform.worldH / 2)

                    ctx.stroke(GeoWorld.shared.landPath,
                               with: .color(Color(hex: 0xE8D9B4).opacity(0.45)),
                               lineWidth: 0.26)

                    if let mesh {
                        for (i, path) in mesh.borders.enumerated() where i < world.factions.count {
                            let color = Theme.factionColor(world.factions[i].colorIndex)
                            let selected = selectedFaction == i
                            ctx.stroke(path,
                                       with: .color(color.opacity(selected ? 1.0 : 0.85)),
                                       lineWidth: selected ? 0.85 : 0.5)
                        }
                    }
                    _ = size
                }

                // 地图外框
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.6)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
            .clipped()
        }
    }
}

// MARK: - 缩略图
struct WorldThumbnail: View {
    var world: World
    var size: CGSize = CGSize(width: 104, height: 58)

    var body: some View {
        GeometryReader { g in
            let rect = g.size
            ZStack {
                Rectangle().fill(
                    LinearGradient(colors: [Color(hex: 0x15343C), Color(hex: 0x081A20)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Image("earth")
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: rect.width, height: rect.height)
                    .mask(LandShape().frame(width: rect.width, height: rect.height))
                    .saturation(0.9)
                Canvas { ctx, _ in
                    ctx.scaleBy(x: rect.width / MapTransform.worldW, y: rect.height / MapTransform.worldH)
                    let mesh = TerritoryMesh.build(world, step: 2)
                    for (i, path) in mesh.fills.enumerated() where i < world.factions.count {
                        ctx.fill(path, with: .color(Theme.factionColor(world.factions[i].colorIndex).opacity(0.62)))
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }
}

// MARK: - 行动标记
struct MapMarkerBadge: View {
    var marker: ActionMarker
    var tint: Color
    var age: Int

    @State private var appear = false
    @State private var pulse = false

    private var baseScale: CGFloat {
        marker.kind == .space ? 1.12 : (marker.kind == .battle ? 0.96 : 0.86)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.35), lineWidth: 1)
                .frame(width: pulse ? 40 : 22, height: pulse ? 40 : 22)
                .opacity(pulse ? 0 : 1)

            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 26, height: 26)
                .blur(radius: 5)

            Circle()
                .fill(Theme.ink.opacity(0.86))
                .frame(width: 21, height: 21)
                .overlay(Circle().strokeBorder(tint.opacity(0.8), lineWidth: 1))

            Image(systemName: marker.kind.symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
        }
        .scaleEffect((appear ? 1 : 0.2) * baseScale)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) { appear = true }
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}
