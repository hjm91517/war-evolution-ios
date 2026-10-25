import SwiftUI

enum MapTool {
    case brush, hand
}

// MARK: - 绘制 / 编辑地图
struct MapPainterView: View {
    @Binding var world: World
    let terrain: TerrainMap
    var owner: Int
    var radius: Int
    @Binding var tool: MapTool

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseZoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var dragStartOffset: CGSize? = nil
    @State private var hoverCell: Int? = nil
    @State private var lastCell: Int? = nil
    @State private var mesh: TerritoryMesh?
    @State private var lastRebuild = Date.distantPast
    @State private var size: CGSize = .zero

    private var transform: MapTransform {
        MapTransform(zoom: zoom * pinch, offset: offset)
    }

    var body: some View {
        GeometryReader { geo in
            let sz = geo.size
            ZStack {
                WorldMapCanvas(world: world, mesh: mesh, zoom: zoom * pinch, offset: offset)

                // 笔刷预览
                if let cell = hoverCell, tool == .brush {
                    let p = transform.viewPoint(fromMap: GeoWorld.shared.center(of: cell), in: sz)
                    let s = transform.scale(for: sz)
                    Circle()
                        .strokeBorder(Theme.goldBright.opacity(0.7), lineWidth: 1)
                        .background(
                            Circle().fill(Theme.factionColor(owner - 1).opacity(0.18))
                        )
                        .frame(width: CGFloat(radius) * 2 * s, height: CGFloat(radius) * 2 * s)
                        .position(p)
                        .allowsHitTesting(false)
                }

                // 首都
                ForEach(world.factions) { f in
                    if f.capital >= 0 {
                        let p = transform.viewPoint(fromMap: GeoWorld.shared.center(of: f.capital), in: sz)
                        Circle()
                            .fill(f.color)
                            .frame(width: 5, height: 5)
                            .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 1))
                            .position(p)
                            .allowsHitTesting(false)
                    }
                }

                mapControls
            }
            .onAppear {
                size = sz
                if mesh == nil { mesh = TerritoryMesh.build(world, step: 2) }
            }
            .onChange(of: sz) { newValue in size = newValue }
            .contentShape(Rectangle())
            .gesture(dragGesture(size: sz))
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { v in
                        zoom = min(14, max(1, baseZoom * v))
                    }
                    .onEnded { _ in
                        baseZoom = zoom
                        offset = MapTransform(zoom: zoom, offset: offset).clampedOffset(offset, size: sz)
                    }
            )
        }
    }

    private var mapControls: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                HStack(spacing: 2) {
                    toolButton(.brush, symbol: "paintbrush.pointed.fill", label: "划界")
                    toolButton(.hand, symbol: "hand.draw.fill", label: "查看")
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.panel.opacity(0.94)))
                .hairlineBorder(Color.white.opacity(0.08), radius: 9)
                .panelShadow()

                Spacer()

                VStack(spacing: 6) {
                    zoomButton("plus")
                    zoomButton("minus")
                    zoomButton("scope")
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    private func toolButton(_ t: MapTool, symbol: String, label: String) -> some View {
        Button {
            Haptics.select()
            withAnimation(Motion.quick) { tool = t }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                Text(label).font(Theme.body(11, weight: .medium))
            }
            .foregroundStyle(tool == t ? Theme.ink : Theme.textSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tool == t ? Theme.gold : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func zoomButton(_ symbol: String) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.quick) {
                switch symbol {
                case "plus": zoom = min(14, zoom * 1.5); baseZoom = zoom
                case "minus": zoom = max(1, zoom / 1.5); baseZoom = zoom
                default:
                    zoom = 1; baseZoom = 1; offset = .zero
                }
            }
        } label: {
            Image(systemName: symbol == "scope" ? "arrow.up.left.and.arrow.down.right" : symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textSoft)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.panel.opacity(0.94)))
                .hairlineBorder(Color.white.opacity(0.08), radius: 8)
        }
        .buttonStyle(.plain)
    }

    private func dragGesture(size sz: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if tool == .brush {
                    paint(at: value.location, size: sz)
                } else {
                    if dragStartOffset == nil { dragStartOffset = offset }
                    let base = dragStartOffset ?? .zero
                    let proposed = CGSize(width: base.width + value.translation.width,
                                          height: base.height + value.translation.height)
                    offset = MapTransform(zoom: zoom, offset: offset).clampedOffset(proposed, size: sz)
                }
            }
            .onEnded { _ in
                dragStartOffset = nil
                lastCell = nil
                if mesh == nil || Date().timeIntervalSince(lastRebuild) > 0.05 {
                    mesh = TerritoryMesh.build(world, step: 2)
                    lastRebuild = Date()
                }
            }
    }

    private func paint(at point: CGPoint, size sz: CGSize) {
        let mp = transform.mapPoint(fromView: point, in: sz)
        guard let cell = GeoWorld.shared.cellIndex(mapPoint: mp) else { return }
        hoverCell = cell
        if cell == lastCell { return }
        lastCell = cell
        let geo = GeoWorld.shared
        guard geo.land[cell] else { return }
        var w = world
        let painted = WorldBuilder.paint(&w, center: cell, radius: radius, owner: owner, terrain: terrain)
        if painted > 0 {
            world = w
            Haptics.tap()
            if Date().timeIntervalSince(lastRebuild) > 0.10 {
                mesh = TerritoryMesh.build(world, step: 2)
                lastRebuild = Date()
            }
        }
    }
}

// MARK: - 演变地图
struct EvolutionMapView: View {
    let world: World
    let mesh: TerritoryMesh?
    var selectedFaction: Int? = nil
    var onSelectCell: ((Int) -> Void)? = nil

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseZoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var dragStartOffset: CGSize? = nil
    @State private var didMove = false

    private var transform: MapTransform {
        MapTransform(zoom: zoom * pinch, offset: offset)
    }

    var body: some View {
        GeometryReader { geo in
            let sz = geo.size
            ZStack {
                WorldMapCanvas(world: world, mesh: mesh, selectedFaction: selectedFaction,
                               zoom: zoom * pinch, offset: offset)

                // 行动标记
                ForEach(world.markers) { m in
                    if let fIdx = world.factionIndex(id: m.factionID) {
                        let p = transform.viewPoint(fromMap: GeoWorld.shared.center(of: m.cell), in: sz)
                        MapMarkerBadge(marker: m,
                                       tint: Theme.factionColor(world.factions[fIdx].colorIndex),
                                       age: world.tick - m.bornTick)
                            .position(p)
                            .allowsHitTesting(false)
                    }
                }

                // 首都与国名
                ForEach(world.factions) { f in
                    if f.isAlive && f.capital >= 0 {
                        let p = transform.viewPoint(fromMap: GeoWorld.shared.center(of: f.capital), in: sz)
                        VStack(spacing: 3) {
                            Rectangle()
                                .fill(f.color)
                                .frame(width: 5, height: 5)
                                .rotationEffect(.degrees(45))
                                .overlay(
                                    Rectangle().strokeBorder(Theme.ink, lineWidth: 1)
                                        .frame(width: 5, height: 5)
                                        .rotationEffect(.degrees(45))
                                )
                            if zoom > 1.9 || world.factions.count <= 6 {
                                Text(f.name)
                                    .font(Theme.label(8.5))
                                    .tracking(1)
                                    .foregroundStyle(Theme.text)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(Theme.ink.opacity(0.62))
                                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            }
                        }
                        .position(p)
                        .allowsHitTesting(false)
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        HStack(spacing: 4) {
                            Text("\(Int(zoom * 100))%")
                                .font(Theme.mono(9))
                                .foregroundStyle(Theme.textFaint)
                            Spacer()
                            zoomControl("minus")
                            zoomControl("plus")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.panel.opacity(0.9)))
                        .hairlineBorder(Color.white.opacity(0.07), radius: 8)
                        .frame(width: 116)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartOffset == nil { dragStartOffset = offset }
                        let base = dragStartOffset ?? .zero
                        let proposed = CGSize(width: base.width + value.translation.width,
                                              height: base.height + value.translation.height)
                        offset = MapTransform(zoom: zoom, offset: offset).clampedOffset(proposed, size: sz)
                        didMove = abs(value.translation.width) + abs(value.translation.height) > 4
                    }
                    .onEnded { value in
                        dragStartOffset = nil
                        if !didMove {
                            let mp = transform.mapPoint(fromView: value.location, in: sz)
                            if let cell = GeoWorld.shared.cellIndex(mapPoint: mp) {
                                onSelectCell?(cell)
                                Haptics.select()
                            }
                        }
                        didMove = false
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { v in zoom = min(16, max(1, baseZoom * v)) }
                    .onEnded { _ in
                        baseZoom = zoom
                        offset = MapTransform(zoom: zoom, offset: offset).clampedOffset(offset, size: sz)
                    }
            )
        }
    }

    private func zoomControl(_ symbol: String) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.quick) {
                if symbol == "plus" {
                    zoom = min(16, zoom * 1.6); baseZoom = zoom
                } else {
                    zoom = max(1, zoom / 1.6); baseZoom = zoom
                    if zoom <= 1.001 { offset = .zero }
                }
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.textSoft)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
