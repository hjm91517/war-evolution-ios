import SwiftUI

// MARK: - 推演界面
struct EvolutionView: View {
    @EnvironmentObject private var store: WorldStore
    @Environment(\.dismiss) private var dismiss
    let worldID: UUID

    @State private var mesh: TerritoryMesh?
    @State private var territoryImage: UIImage?
    @State private var lastMeshBuild = Date.distantPast
    @State private var selectedFaction: Int? = nil
    @State private var showFactionDetail = false
    @State private var feedOpen = true
    @State private var feedFilter = 0
    @State private var showExit = false
    @State private var showEdit = false
    @State private var detailScroll = false

    private var world: World? { store.world(worldID) }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 700
            ZStack(alignment: .topTrailing) {
                if let world {
                    EvolutionMapView(world: world, mesh: mesh, territoryImage: territoryImage,
                                     selectedFaction: selectedFaction) { cell in
                        let owner = Int(world.territory.owner(at: cell))
                        if owner > 0 {
                            selectedFaction = owner - 1
                            showFactionDetail = true
                        }
                    }
                    .ignoresSafeArea()

                    mapVignette

                    if feedOpen {
                        Color.black.opacity(0.26)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(Motion.standard) { feedOpen = false }
                            }
                            .transition(.opacity)
                    }

                    VStack(spacing: 0) {
                        topBar(world: world, wide: wide)
                            .padding(.horizontal, wide ? 20 : 14)
                            .padding(.top, 6)
                        Spacer()
                        bottomCluster(world: world, wide: wide)
                            .padding(.bottom, wide ? 14 : 6)
                    }

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        if feedOpen {
                            FeedPanel(world: world,
                                      filter: $feedFilter,
                                      onClose: {
                                          withAnimation(Motion.standard) { feedOpen = false }
                                      },
                                      onSelectFaction: { id in
                                          if let idx = world.factionIndex(id: id) {
                                              selectedFaction = idx
                                              showFactionDetail = true
                                          }
                                      })
                                .frame(width: min(wide ? 340 : 320, geo.size.width * 0.86))
                                .padding(.top, wide ? 74 : 62)
                                .padding(.bottom, wide ? 96 : 86)
                                .padding(.trailing, wide ? 18 : 10)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            feedTab(world: world)
                                .padding(.trailing, 0)
                                .padding(.top, 180)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    missingState
                }
            }
        }
        .background(Theme.ink)
        .onAppear {
            rebuildMesh(force: true)
            if let w = world, w.events.isEmpty {
                store.stepOnce(worldID, years: 1)
            }
        }
        .onChange(of: world?.tick ?? 0) { _ in
            rebuildMesh(force: false)
        }
        .sheet(isPresented: $showFactionDetail) {
            if let w = world {
                FactionDetailSheet(world: w, index: selectedFaction)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showEdit) {
            if let w = world {
                CreateWorldView(initialWorld: w)
                    .environmentObject(store)
            }
        }
        .confirmationDialog("退出推演", isPresented: $showExit, titleVisibility: .visible) {
            Button("退出并保持持续演变") {
                if let id = store.runningWorldID {
                    store.setContinuous(id, true)
                }
                store.exit()
                dismiss()
            }
            Button("退出（停止演变）", role: .destructive) {
                if let id = store.runningWorldID {
                    store.setContinuous(id, false)
                }
                store.exit()
                dismiss()
            }
            Button("继续观战", role: .cancel) {}
        } message: {
            Text("持续演变会让世界在 App 关闭后按真实时间继续推进。")
        }
    }

    // MARK: 地图压边
    private var mapVignette: some View {
        ZStack {
            LinearGradient(colors: [Theme.ink.opacity(0.92), Theme.ink.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .frame(maxHeight: .infinity, alignment: .top)
            LinearGradient(colors: [Theme.inkDeep.opacity(0.9), Theme.ink.opacity(0)],
                           startPoint: .bottom, endPoint: .top)
                .frame(height: 190)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: 顶栏
    private func topBar(world: World, wide: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                Haptics.tap()
                showExit = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("退出").font(Theme.body(11, weight: .medium))
                }
                .foregroundStyle(Theme.textSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(Theme.panel.opacity(0.9)))
                .hairlineBorder(Color.white.opacity(0.08), radius: 999)
            }
            .buttonStyle(Pressable())

            VStack(alignment: .leading, spacing: 5) {
                Text(world.name)
                    .font(Theme.title(15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(world.eraName)
                        .font(Theme.label(9))
                        .tracking(1)
                        .foregroundStyle(Theme.gold)
                    Text("·").foregroundStyle(Theme.textFaint).font(Theme.label(9))
                    Text(Fmt.year(world.tick))
                        .font(Theme.mono(9.5))
                        .foregroundStyle(Theme.textDim)
                    if world.continuous {
                        HStack(spacing: 3) {
                            Circle().fill(Theme.gold).frame(width: 3.5, height: 3.5)
                                .breathing(min: 0.2, max: 1, duration: 1.6)
                            Text("持续").font(Theme.label(8)).tracking(0.6)
                        }
                        .foregroundStyle(Theme.gold.opacity(0.85))
                    }
                }
            }
            .padding(.top, 2)

            Spacer()

            HStack(spacing: 6) {
                Button {
                    Haptics.tap()
                    showEdit = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSoft)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.panel.opacity(0.9)))
                        .hairlineBorder(Color.white.opacity(0.08), radius: 999)
                }
                .buttonStyle(Pressable())

                Button {
                    Haptics.tap()
                    withAnimation(Motion.standard) { feedOpen.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("动态").font(Theme.body(10.5, weight: .medium))
                    }
                    .foregroundStyle(feedOpen ? Theme.ink : Theme.textSoft)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(feedOpen ? Theme.gold : Theme.panel.opacity(0.9)))
                    .hairlineBorder(Color.white.opacity(feedOpen ? 0.2 : 0.08), radius: 999)
                }
                .buttonStyle(Pressable())
            }
        }
    }

    // MARK: 底部：势力条 + 速度
    private func bottomCluster(world: World, wide: Bool) -> some View {
        VStack(spacing: 8) {
            // 势力排行
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(sortedFactions(world).indices), id: \.self) { rank in
                        let f = sortedFactions(world)[rank]
                        factionChip(f, rank: rank, total: world.livingFactions.count) {
                            if let idx = world.factionIndex(id: f.id) {
                                selectedFaction = idx
                                showFactionDetail = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 34)

            // 时间控制
            HStack(spacing: 10) {
                Button {
                    store.togglePause()
                } label: {
                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.gold))
                }
                .buttonStyle(Pressable())

                HStack(spacing: 2) {
                    ForEach(SimSpeed.options, id: \.self) { s in
                        Button {
                            Haptics.select()
                            store.setSpeed(world.id, s)
                        } label: {
                            Text(SimSpeed.label(s))
                                .font(Theme.mono(10, weight: world.speed == s ? .bold : .regular))
                                .foregroundStyle(world.speed == s ? Theme.text : Theme.textDim)
                                .frame(width: 34, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(world.speed == s ? Theme.gold.opacity(0.18) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.28)))

                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 0.6, height: 16)

                Text(Fmt.year(world.tick))
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundStyle(Theme.textSoft)
                    .contentTransition(.numericText())
                    .animation(Motion.quick, value: world.tick)

                Spacer(minLength: 0)

                Text("\(world.livingFactions.count) 势力")
                    .font(Theme.label(9))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous).fill(Theme.panel.opacity(0.94))
            )
            .hairlineBorder(Color.white.opacity(0.08), radius: 999)
            .panelShadow()
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: wide ? 560 : .infinity)
    }

    private func factionChip(_ f: Faction, rank: Int, total: Int, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("\(rank + 1)")
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
                Circle().fill(f.color).frame(width: 7, height: 7)
                Text(f.name)
                    .font(Theme.body(10.5, weight: .medium))
                    .foregroundStyle(Theme.textSoft)
                    .lineLimit(1)
                Text("\(f.territory)")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.panel.opacity(0.9)))
            .overlay(
                Capsule().strokeBorder(f.color.opacity(rank == 0 ? 0.65 : 0.25), lineWidth: 0.9)
            )
        }
        .buttonStyle(Pressable())
    }

    private func sortedFactions(_ world: World) -> [Faction] {
        world.livingFactions.sorted { $0.territory > $1.territory }
    }

    // MARK: 收起态标签
    private func feedTab(world: World) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.standard) { feedOpen = true }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .semibold))
                Text("全球动态")
                    .font(Theme.label(9))
                    .tracking(2)
                    .rotationEffect(.degrees(90))
                    .frame(width: 16, height: 70)
                    .offset(y: 4)
                let latest = world.events.last
                if let latest, latest.importance >= 3 {
                    Circle().fill(Theme.ember).frame(width: 5, height: 5)
                        .breathing()
                }
            }
            .foregroundStyle(Theme.gold)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.panel.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private var missingState: some View {
        VStack(spacing: 14) {
            EmptyState(symbol: "exclamationmark.triangle",
                       title: "世界不存在",
                       message: "它可能已被删除。")
            GhostButton(title: "返回主页", symbol: "chevron.left") { dismiss() }
        }
    }

    // MARK: 网格节流
    private func rebuildMesh(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastMeshBuild) > 0.14 else { return }
        guard let w = world else { return }
        lastMeshBuild = now
        mesh = TerritoryMesh.build(w)
        territoryImage = TerritoryRaster.make(world: w)
    }
}

// MARK: - 实时动态面板
struct FeedPanel: View {
    let world: World
    @Binding var filter: Int
    var onClose: () -> Void
    var onSelectFaction: (UUID) -> Void

    private var events: [SimEvent] {
        var list = Array(world.events.reversed())
        switch filter {
        case 1: list = list.filter { $0.kind == .battle || $0.kind == .war || $0.kind == .peace }
        case 2: list = list.filter { $0.kind == .intel || $0.kind == .space || $0.intel != .open }
        default: break
        }
        return Array(list.prefix(80))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.6)
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if events.isEmpty {
                        VStack(spacing: 8) {
                            Text("暂无动态")
                                .font(Theme.body(12))
                                .foregroundStyle(Theme.textDim)
                            Text("推进时间，情报会出现在这里")
                                .font(Theme.label(9))
                                .foregroundStyle(Theme.textFaint)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    ForEach(events) { e in
                        FeedRow(event: e, world: world)
                            .onTapGesture {
                                if let fid = e.factionID { onSelectFaction(fid) }
                            }
                        Rectangle().fill(Color.white.opacity(0.045)).frame(height: 0.5)
                            .padding(.leading, 36)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous)
                .fill(Theme.panel.opacity(0.97))
        )
        .hairlineBorder(Color.white.opacity(0.09), radius: Theme.rLarge)
        .panelShadow(strong: true)
    }

    private var header: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Theme.ember.opacity(0.15)).frame(width: 20, height: 20)
                    Circle().fill(Theme.ember).frame(width: 4, height: 4)
                        .breathing(min: 0.3, max: 1, duration: 1.8)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("全球实时动态")
                        .font(Theme.title(12.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("LIVE INTELLIGENCE")
                        .font(Theme.mono(7.5))
                        .tracking(1.6)
                        .foregroundStyle(Theme.textFaint)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            HStack(spacing: 6) {
                filterChip("全部", 0)
                filterChip("战报", 1)
                filterChip("情报", 2)
                Spacer()
                Text(Fmt.year(world.tick))
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 9)
        }
    }

    private func filterChip(_ title: String, _ idx: Int) -> some View {
        Button {
            Haptics.select()
            withAnimation(Motion.quick) { filter = idx }
        } label: {
            Text(title)
                .font(Theme.body(9.5, weight: filter == idx ? .semibold : .regular))
                .foregroundStyle(filter == idx ? Theme.ink : Theme.textDim)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    Capsule().fill(filter == idx ? Theme.gold : Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 动态条目
struct FeedRow: View {
    let event: SimEvent
    let world: World

    private var faction: Faction? { world.faction(id: event.factionID) }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            VStack(spacing: 3) {
                Text("\(event.tick)")
                    .font(Theme.mono(9, weight: .medium))
                    .foregroundStyle(Theme.textFaint)
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 0.6, height: 14)
            }
            .frame(width: 26)
            .padding(.top, 2)

            ZStack {
                Circle()
                    .fill(event.kind.tint.opacity(event.isRedacted ? 0.08 : 0.14))
                    .frame(width: 22, height: 22)
                Image(systemName: event.isRedacted ? "lock.fill" : event.kind.symbol)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(event.isRedacted ? Theme.textDim : event.kind.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    if let f = faction {
                        Circle().fill(f.color).frame(width: 4, height: 4)
                    }
                    Text(event.isRedacted ? "加密信号 · 来源不明" : event.headline)
                        .font(Theme.body(11.5, weight: .medium))
                        .foregroundStyle(event.isRedacted ? Theme.textDim : Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if event.intel != .open {
                        Text(event.isRedacted ? event.intel.tag : "已解密")
                            .font(Theme.mono(7.5, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(event.isRedacted ? event.intel.tint : Theme.success)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill((event.isRedacted ? event.intel.tint : Theme.success).opacity(0.10))
                            )
                    }
                }

                if event.isRedacted {
                    Text("▓▓▓▓▓▓  ▓▓▓▓  ▓▓▓▓▓▓▓▓")
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.textFaint)
                        .lineLimit(1)
                    Text("解密倒计时 \(max(0, event.revealTick - event.tick)) 年")
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.gold.opacity(0.65))
                } else {
                    Text(event.detail)
                        .font(Theme.body(10.5))
                        .lineSpacing(3)
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    if let geoCell = Optional(event.cell), geoCell >= 0, event.importance >= 2 {
                        Text(GeoWorld.shared.regionName(of: geoCell))
                            .font(Theme.label(8))
                            .tracking(0.8)
                            .foregroundStyle(Theme.textFaint)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

// MARK: - 势力详情
struct FactionDetailSheet: View {
    let world: World
    var index: Int?
    @Environment(\.dismiss) private var dismiss

    private var faction: Faction? {
        guard let index, index < world.factions.count else { return nil }
        return world.factions[index]
    }

    var body: some View {
        ZStack {
            Backdrop(showGrid: false)
            if let f = faction {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(f.color.opacity(0.14))
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(f.color.opacity(0.4), lineWidth: 1)
                                Image(systemName: f.symbol)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(f.color)
                            }
                            .frame(width: 54, height: 54)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(f.name)
                                    .font(Theme.display(22, weight: .semibold))
                                    .tracking(1.5)
                                    .foregroundStyle(Theme.text)
                                HStack(spacing: 6) {
                                    Pill(text: f.aiName, tint: f.color, fill: f.color.opacity(0.10))
                                    Pill(text: world.eraName, tint: Theme.gold, mono: true)
                                    if !f.isAlive {
                                        Pill(text: "已灭亡", tint: Theme.ember, mono: true)
                                    }
                                }
                            }
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.textDim)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.white.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 22)

                        if !f.slogan.isEmpty {
                            Text("「\(f.slogan)」")
                                .font(Theme.display(16, weight: .medium))
                                .tracking(1.4)
                                .foregroundStyle(Theme.gold.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // 数据
                        Panel(padding: 16) {
                            VStack(spacing: 12) {
                                StatBar(label: "人口", value: f.population, maxValue: 6000, tint: f.color,
                                        display: Fmt.compact(f.population))
                                StatBar(label: "军力", value: f.military, maxValue: 400, tint: Theme.ember,
                                        display: Fmt.compact(f.military))
                                StatBar(label: "科技", value: f.tech, maxValue: 200, tint: Theme.teal,
                                        display: String(format: "%.0f", f.tech))
                                StatBar(label: "财富", value: f.wealth, maxValue: 5000, tint: Theme.gold,
                                        display: Fmt.compact(f.wealth))
                                StatBar(label: "稳定", value: f.stability, maxValue: 100, tint: Theme.success,
                                        display: String(format: "%.0f", f.stability))
                            }
                        }

                        HStack(spacing: 10) {
                            tile("疆域", "\(f.territory)", "square.grid.3x3")
                            tile("奇观", "\(f.wonders)", "building.columns")
                            tile("胜仗", "\(f.battlesWon)", "flag.fill")
                        }

                        if !f.background.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(text: "出身", english: "ORIGIN")
                                Text(f.background)
                                    .font(Theme.body(12))
                                    .lineSpacing(5)
                                    .foregroundStyle(Theme.textSoft)
                            }
                        }

                        // 关系
                        let relations = relationRows(f)
                        if !relations.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(text: "外交关系", english: "DIPLOMACY")
                                ForEach(relations) { row in
                                    HStack(spacing: 8) {
                                        Circle().fill(row.color).frame(width: 6, height: 6)
                                        Text(row.name)
                                            .font(Theme.body(11.5))
                                            .foregroundStyle(Theme.textSoft)
                                        Spacer()
                                        Text(row.value <= -60 ? "交战" : (row.value < -15 ? "敌对" : (row.value > 25 ? "友好" : "中立")))
                                            .font(Theme.label(9))
                                            .foregroundStyle(row.value <= -60 ? Theme.ember : Theme.textDim)
                                        Text("\(row.value)")
                                            .font(Theme.mono(9))
                                            .foregroundStyle(Theme.textFaint)
                                            .frame(width: 32, alignment: .trailing)
                                    }
                                }
                            }
                        }

                        // 最近事件
                        let events = world.events.filter { $0.factionID == f.id && !$0.isRedacted }.suffix(4)
                        if !events.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(text: "大事记", english: "CHRONICLE")
                                ForEach(Array(events.reversed())) { e in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(e.tick)").font(Theme.mono(8)).foregroundStyle(Theme.textFaint)
                                        Text(e.headline)
                                            .font(Theme.body(11))
                                            .foregroundStyle(Theme.textSoft)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    private func tile(_ title: String, _ value: String, _ symbol: String) -> some View {
        Panel(padding: 11) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.gold.opacity(0.8))
                Text(value)
                    .font(Theme.mono(16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(title)
                    .font(Theme.label(8.5))
                    .tracking(1)
                    .foregroundStyle(Theme.textFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func relationRows(_ f: Faction) -> [RelationRow] {
        var rows: [RelationRow] = []
        for other in world.factions where other.id != f.id && other.isAlive {
            rows.append(RelationRow(name: other.name,
                                    value: world.relation(f.id, other.id),
                                    color: other.color))
        }
        return rows.sorted { $0.value < $1.value }
    }
}

struct RelationRow: Identifiable {
    var name: String
    var value: Int
    var color: Color
    var id: String { name }
}
