import SwiftUI

// MARK: - 主页
struct HomeView: View {
    @EnvironmentObject private var store: WorldStore
    @State private var showCreate = false
    @State private var activeWorldID: UUID? = nil
    @State private var editWorld: World? = nil
    @State private var renameWorld: World? = nil
    @State private var renameText = ""
    @State private var deleteWorld: World? = nil
    @State private var showAbout = false
    @State private var showAI = false
    @State private var appeared = false
    @State private var previewMap = false

    var body: some View {
        ZStack {
            Backdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, 10)

                    statsStrip
                        .padding(.top, 22)

                    sectionHeader
                        .padding(.top, 26)

                    if store.worlds.isEmpty {
                        emptyBlock
                            .padding(.top, 8)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(store.worlds.indices), id: \.self) { idx in
                                let world = store.worlds[idx]
                                WorldCard(
                                    world: world,
                                    onOpen: { open(world) },
                                    onToggleContinuous: {
                                        store.setContinuous(world.id, !world.continuous)
                                    },
                                    onEdit: { editWorld = world },
                                    onRename: {
                                        renameText = world.name
                                        renameWorld = world
                                    },
                                    onDelete: { deleteWorld = world }
                                )
                                .riseIn(idx, enabled: appeared)
                            }
                        }
                        .padding(.top, 4)
                    }

                    engineNote
                        .padding(.top, 24)
                        .padding(.bottom, 120)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                if !store.worlds.isEmpty {
                    bottomBar
                }
            }
        }
        .onAppear {
            withAnimation(Motion.standard.delay(0.05)) { appeared = true }
            handlePreview()
        }
        .fullScreenCover(isPresented: $previewMap) {
            CreateWorldView(initialWorld: WorldBuilder.previewDraft())
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: Binding(
            get: { activeWorldID != nil },
            set: { if !$0 { activeWorldID = nil } }
        )) {
            if let id = activeWorldID {
                EvolutionView(worldID: id)
                    .environmentObject(store)
            }
        }
        .fullScreenCover(isPresented: $showCreate) {
            CreateWorldView(initialWorld: nil)
                .environmentObject(store)
        }
        .fullScreenCover(item: $editWorld) { world in
            CreateWorldView(initialWorld: world)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showAI) {
            AISettingsView()
        }
        .alert("重命名世界", isPresented: Binding(
            get: { renameWorld != nil },
            set: { if !$0 { renameWorld = nil } }
        )) {
            TextField("世界名称", text: $renameText)
            Button("取消", role: .cancel) { renameWorld = nil }
            Button("保存") {
                if let w = renameWorld, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    store.rename(w.id, to: renameText)
                    store.flash("已重命名")
                }
                renameWorld = nil
            }
        }
        .confirmationDialog("删除这个世界？",
                            isPresented: Binding(get: { deleteWorld != nil },
                                                 set: { if !$0 { deleteWorld = nil } }),
                            presenting: deleteWorld) { world in
            Button("删除「\(world.name)」", role: .destructive) {
                withAnimation(Motion.standard) { store.delete(world.id) }
                store.flash("世界已删除")
                deleteWorld = nil
            }
            Button("取消", role: .cancel) { deleteWorld = nil }
        } message: { _ in
            Text("疆域、势力与全部推演记录都会被清除，无法恢复。")
        }
    }

    // MARK: 头部
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("WAR EVOLUTION ENGINE")
                            .font(Theme.mono(8.5, weight: .medium))
                            .tracking(2.4)
                            .foregroundStyle(Theme.gold.opacity(0.85))
                        Rectangle()
                            .fill(Theme.gold.opacity(0.35))
                            .frame(width: 26, height: 0.7)
                    }
                    Text("名将")
                        .font(Theme.display(40, weight: .semibold))
                        .tracking(6)
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.text, Theme.sand],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    Text("战争演变模拟器")
                        .font(Theme.body(12.5, weight: .medium))
                        .tracking(3)
                        .foregroundStyle(Theme.textDim)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        Haptics.tap()
                        showAI = true
                    } label: {
                        ZStack {
                            Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
                            Circle().fill(Theme.teal.opacity(0.08))
                            Image(systemName: "bolt.horizontal.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.teal)
                        }
                        .frame(width: 34, height: 34)
                    }
                    .buttonStyle(Pressable())
                    .padding(.top, 6)

                    Button {
                        Haptics.tap()
                        showAbout = true
                    } label: {
                    ZStack {
                        Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
                        Circle().fill(Theme.gold.opacity(0.06))
                        Image(systemName: "info")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                    }
                    .frame(width: 34, height: 34)
                }
                    .buttonStyle(Pressable())
                    .padding(.top, 6)
                }
            }
        }
    }

    // MARK: 统计
    private var statsStrip: some View {
        Panel(padding: 0, radius: Theme.rMid) {
            HStack(spacing: 0) {
                miniStat(value: "\(store.worlds.count)", label: "世界", symbol: "globe.asia.australia")
                divider
                miniStat(value: "\(store.worlds.reduce(0) { $0 + $1.livingFactions.count })", label: "势力", symbol: "shield.lefthalf.filled")
                divider
                miniStat(value: "\(store.worlds.filter(\.continuous).count)", label: "持续演变", symbol: "clock.arrow.circlepath", live: store.worlds.contains { $0.continuous })
            }
            .padding(.vertical, 14)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(width: 0.6, height: 26)
    }

    private func miniStat(value: String, label: String, symbol: String, live: Bool = false) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.gold.opacity(0.75))
                Text(value)
                    .font(Theme.mono(17, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            Text(label)
                .font(Theme.label(9))
                .tracking(1.2)
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if live {
                Circle().fill(Theme.gold)
                    .frame(width: 4, height: 4)
                    .breathing(min: 0.2, max: 1.0, duration: 1.8)
                    .offset(x: -22, y: 2)
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(text: "我的世界", english: "WORLDS")
            Spacer()
            Text(store.worlds.isEmpty ? "尚无记录" : "\(store.worlds.count) 个")
                .font(Theme.mono(9.5))
                .foregroundStyle(Theme.textFaint)
        }
    }

    // MARK: 空态
    private var emptyBlock: some View {
        VStack(spacing: 16) {
            Panel(padding: 20) {
                VStack(spacing: 16) {
                    EmptyState(
                        symbol: "map",
                        title: "还没有世界",
                        message: "创建一个战场：在地球平面图上划定疆域，给每个势力写下出身与野心，剩下的交给时间。"
                    )
                    GoldButton(title: "创建第一个战争", symbol: "plus") {
                        showCreate = true
                    }
                    Button {
                        Haptics.success()
                        let w = WorldBuilder.sampleWorld()
                        store.add(w)
                        store.flash("已载入示例战场")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles").font(.system(size: 10, weight: .semibold))
                            Text("先看一个示例战场").font(Theme.body(12, weight: .medium))
                        }
                        .foregroundStyle(Theme.textDim)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(Pressable())
                }
            }
        }
    }

    // MARK: 说明
    private var engineNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Theme.gold.opacity(0.5))
                .frame(width: 1, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text("推演在设备本地完成")
                    .font(Theme.label(10))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textDim)
                Text("每个势力的抉择来自你写下的背景与它脚下的土地：粮食、矿脉、海岸、邻国的强弱。关闭 App 后，开启「持续演变」的世界会按真实时间继续走下去。")
                    .font(Theme.body(11))
                    .lineSpacing(3.5)
                    .foregroundStyle(Theme.textFaint)
            }
        }
    }

    // MARK: 底栏
    private var bottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Theme.ink.opacity(0), Theme.ink.opacity(0.92), Theme.ink],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 26)
            VStack(spacing: 9) {
                GoldButton(title: "创建战争",
                           subtitle: "划定疆域 · 配置势力 · 让世界自己走",
                           symbol: "plus") {
                    showCreate = true
                }
                Text("所有推演均在本地运行 · 无需联网")
                    .font(Theme.label(8.5))
                    .tracking(1.8)
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 6)
            .background(Theme.ink.opacity(0.96))
        }
    }

    private func handlePreview() {
        guard PreviewMode.skipLaunch else { return }
        if store.worlds.isEmpty {
            store.add(WorldBuilder.sampleWorld())
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if PreviewMode.wantsEvolution, let w = store.worlds.first {
                store.enter(w.id)
                activeWorldID = w.id
            } else if PreviewMode.wantsCreate {
                showCreate = true
            } else if PreviewMode.wantsMap {
                previewMap = true
            } else if PreviewMode.wantsAI {
                showAI = true
            }
        }
    }

    private func open(_ world: World) {
        Haptics.select()
        activeWorldID = world.id
        store.enter(world.id)
    }
}

// MARK: - 世界卡片
struct WorldCard: View {
    let world: World
    var onOpen: () -> Void
    var onToggleContinuous: () -> Void
    var onEdit: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void

    private var claim: Double {
        Double(world.claimedLand) / Double(max(1, GeoWorld.shared.landCount))
    }

    private var topFaction: Faction? {
        world.livingFactions.max { $0.territory < $1.territory }
    }

    var body: some View {
        HStack(spacing: 13) {
                ZStack(alignment: .bottomLeading) {
                    WorldThumbnail(world: world, size: CGSize(width: 96, height: 54))
                    if world.continuous {
                        Text("LIVE")
                            .font(Theme.mono(7, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Theme.gold))
                            .padding(4)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(world.name)
                            .font(Theme.title(15.5, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        if world.phase == .draft {
                            Pill(text: "草稿", tint: Theme.textDim, mono: true)
                        }
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 5) {
                        Text(world.eraName)
                            .font(Theme.body(10.5, weight: .medium))
                            .foregroundStyle(Theme.gold.opacity(0.9))
                        Text("·")
                            .foregroundStyle(Theme.textFaint)
                        Text(world.currentYear)
                            .font(Theme.mono(9.5))
                            .foregroundStyle(Theme.textDim)
                        Text("·")
                            .foregroundStyle(Theme.textFaint)
                        Text("\(world.livingFactions.count) 势力")
                            .font(Theme.body(10))
                            .foregroundStyle(Theme.textDim)
                    }

                    HStack(spacing: 4) {
                        ForEach(world.livingFactions.prefix(7)) { f in
                            Circle()
                                .fill(f.color)
                                .frame(width: 5, height: 5)
                        }
                        if let top = topFaction {
                            Text("\(top.name) 领先")
                                .font(Theme.label(9))
                                .tracking(0.6)
                                .foregroundStyle(Theme.textFaint)
                                .padding(.leading, 2)
                        }
                    }
                }

                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Theme.gold.opacity(0.10))
                            .frame(width: 34, height: 34)
                        Circle()
                            .strokeBorder(Theme.gold.opacity(0.45), lineWidth: 0.9)
                            .frame(width: 34, height: 34)
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .offset(x: 1)
                    }
                    Button(action: onToggleContinuous) {
                        Image(systemName: world.continuous ? "clock.arrow.circlepath" : "clock")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(world.continuous ? Theme.gold : Theme.textFaint)
                            .frame(width: 24, height: 18)
                    }
                    .buttonStyle(.plain)
                }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                .fill(Theme.panel)
        )
        .hairlineBorder(Color.white.opacity(0.07), radius: Theme.rMid)
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.03))
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.goldDim, Theme.gold.opacity(0.7)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * min(1, claim * 3.2)))
                }
            }
            .frame(height: 1.2)
            .padding(.horizontal, 12)
            .padding(.bottom, 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous))
        .onTapGesture { Haptics.select(); onOpen() }
        .contextMenu {
            Button { onOpen() } label: { Label("进入推演", systemImage: "play.fill") }
            Button { onToggleContinuous() } label: {
                Label(world.continuous ? "停止持续演变" : "开启持续演变",
                      systemImage: "clock.arrow.circlepath")
            }
            Button { onEdit() } label: { Label("编辑战争", systemImage: "slider.horizontal.3") }
            Button { onRename() } label: { Label("重命名", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("删除", systemImage: "trash") }
        }
    }
}

// MARK: - 关于
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Backdrop(showGrid: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("推演说明").font(Theme.display(24)).tracking(3)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.textDim)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                    }
                    .padding(.top, 26)

                    Panel(padding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "引擎", english: "ENGINE")
                            bullet("地球被切成 5 万多个 1° 格子，每个格子有地形、粮食、矿脉与贸易权重。")
                            bullet("势力每年做一次决策：拓殖、备战、开战、议和、营造、科研、外交。")
                            bullet("性格来自你写的背景文本——「铁血」会被读成尚武，「商路」会被读成重商。")
                            bullet("地形决定攻防：山地、雨林、苔原给守方加成，荒漠几乎养不活人。")
                        }
                    }

                    Panel(padding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "时间", english: "TIME")
                            bullet("1 次推演 = 1 年。速度档位决定每秒推进多少年。")
                            bullet("开启「持续演变」后，退出 App 的世界会在下次打开时按真实流逝时间补算。")
                            bullet("情报分为公开、机密、绝密三级；绝密条目在解密前只显示为截获信号。")
                        }
                    }

                    Panel(padding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "关于", english: "ABOUT")
                            HStack {
                                Text("版本").font(Theme.body(12)).foregroundStyle(Theme.textDim)
                                Spacer()
                                Text("1.0.0").font(Theme.mono(11)).foregroundStyle(Theme.textSoft)
                            }
                            HStack {
                                Text("包名").font(Theme.body(12)).foregroundStyle(Theme.textDim)
                                Spacer()
                                Text("com.hjm91517.warforge").font(Theme.mono(10)).foregroundStyle(Theme.textSoft)
                            }
                            HStack {
                                Text("核心").font(Theme.body(12)).foregroundStyle(Theme.textDim)
                                Spacer()
                                Text("本地推演 · 离线运行").font(Theme.body(11)).foregroundStyle(Theme.textSoft)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Rectangle()
                .fill(Theme.gold.opacity(0.6))
                .frame(width: 3, height: 3)
                .rotationEffect(.degrees(45))
                .padding(.top, 6)
            Text(text)
                .font(Theme.body(12))
                .lineSpacing(4)
                .foregroundStyle(Theme.textSoft)
        }
    }
}
