import SwiftUI

// MARK: - 创建 / 编辑战争
struct CreateWorldView: View {
    @EnvironmentObject private var store: WorldStore
    @Environment(\.dismiss) private var dismiss

    var initialWorld: World?
    var onFinish: ((UUID) -> Void)? = nil

    @State private var draft: World
    @State private var isEditing: Bool
    @State private var step: Int = 0
    @State private var terrain: TerrainMap? = nil
    @State private var tool: MapTool = .brush
    @State private var brushOwner: Int = 1
    @State private var undoStack: [[UInt8]] = []
    @State private var editing: Faction? = nil
    @State private var editingIsNew = false
    @State private var pageIn = false

    private let stepTitles = ["命名与纪元", "创建势力", "划定疆域", "检视开局"]

    init(initialWorld: World?, onFinish: ((UUID) -> Void)? = nil) {
        self.initialWorld = initialWorld
        self.onFinish = onFinish
        if let w = initialWorld {
            _draft = State(initialValue: w)
            _isEditing = State(initialValue: true)
            let forceMap = ProcessInfo.processInfo.arguments.contains("-previewMap")
            _step = State(initialValue: (w.phase == .draft && !forceMap) ? 0 : (forceMap ? 2 : 0))
        } else {
            let seed = UInt64.random(in: 1...99_999_999)
            var w = WorldBuilder.blankWorld(name: NameForge.worldName(seed: seed),
                                            seed: seed, level: .nation)
            w.factions = []
            _draft = State(initialValue: w)
            _isEditing = State(initialValue: false)
        }
    }

    var body: some View {
        ZStack {
            Backdrop(showGrid: step != 2)

            Group {
                switch step {
                case 0: nameStep
                case 1: factionStep
                case 2: territoryStep
                default: reviewStep
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 14)),
                removal: .opacity.combined(with: .offset(y: -10))
            ))

            VStack(spacing: 0) {
                topBar
                Spacer()
            }
        }
        .onAppear {
            if terrain == nil { terrain = store.terrain(for: draft) }
            withAnimation(Motion.enter) { pageIn = true }
        }
        .sheet(item: $editing) { f in
            FactionEditorView(
                initial: f,
                isNew: editingIsNew,
                worldSeed: draft.seed,
                usedColors: usedColors(excluding: f.id),
                onSave: { updated in
                    if let idx = draft.factions.firstIndex(where: { $0.id == updated.id }) {
                        draft.factions[idx] = updated
                    } else {
                        draft.factions.append(updated)
                        brushOwner = draft.factions.count
                    }
                    Haptics.success()
                }
            )
        }
        .interactiveDismissDisabled(!isEditing)
    }

    // MARK: - 顶栏
    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                if step > 0 {
                    withAnimation(Motion.standard) { step -= 1 }
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: step > 0 ? "chevron.left" : "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSoft)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .hairlineBorder(Color.white.opacity(0.09), radius: 999)
            }
            .buttonStyle(Pressable())

            VStack(alignment: .leading, spacing: 3) {
                Text(isEditing ? "编辑战争" : "创建战争")
                    .font(Theme.label(9))
                    .tracking(2)
                    .foregroundStyle(Theme.gold.opacity(0.85))
                Text(stepTitles[min(step, stepTitles.count - 1)])
                    .font(Theme.title(14, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.gold : Color.white.opacity(0.12))
                        .frame(width: i == step ? 16 : 6, height: 3)
                        .animation(Motion.quick, value: step)
                }
            }

            if step < 3 {
                Button {
                    Haptics.select()
                    withAnimation(Motion.standard) { step += 1 }
                } label: {
                    HStack(spacing: 4) {
                        Text("下一步").font(Theme.body(12, weight: .semibold))
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.gold))
                }
                .buttonStyle(Pressable())
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return draft.factions.count >= 2 && draft.factions.allSatisfy { $0.isAIConfigured }
        case 2: return draft.claimedLand > 0
        default: return true
        }
    }

    // MARK: - 步骤 0
    private var nameStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Spacer().frame(height: 62)

                Text("给你的世界一个名字")
                    .font(Theme.display(28, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(LinearGradient(colors: [Theme.text, Theme.sand],
                                                   startPoint: .top, endPoint: .bottom))

                Text("它会被刻在时间线的起点。此后每一次兴亡，都记在这个名字下面。")
                    .font(Theme.body(12))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.textDim)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("世界名称", text: $draft.name)
                        .font(Theme.display(24, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .padding(.vertical, 10)
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.gold, Theme.gold.opacity(0.08)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                    HStack {
                        Text("SEED \(String(format: "%08X", UInt32(truncatingIfNeeded: draft.seed)))")
                            .font(Theme.mono(9)).tracking(1)
                            .foregroundStyle(Theme.textFaint)
                        Spacer()
                        Button {
                            Haptics.select()
                            draft.seed = UInt64.random(in: 1...99_999_999)
                            draft.name = NameForge.worldName(seed: draft.seed)
                            terrain = store.terrain(for: draft)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "dice").font(.system(size: 10, weight: .semibold))
                                Text("换一个").font(Theme.body(11, weight: .medium))
                            }
                            .foregroundStyle(Theme.gold)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "初始范围级别", english: "SCALE")
                    ForEach(RegionLevel.allCases) { level in
                        Button {
                            Haptics.select()
                            withAnimation(Motion.quick) { draft.level = level }
                        } label: {
                            HStack(spacing: 12) {
                                IconBadge(symbol: level.symbol,
                                          tint: draft.level == level ? Theme.gold : Theme.textDim,
                                          size: 34)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(level.title)
                                        .font(Theme.title(14, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                    Text(level.caption)
                                        .font(Theme.body(10.5))
                                        .foregroundStyle(Theme.textDim)
                                }
                                Spacer()
                                Circle()
                                    .strokeBorder(draft.level == level ? Theme.gold : Color.white.opacity(0.18),
                                                  lineWidth: draft.level == level ? 4 : 1)
                                    .frame(width: 14, height: 14)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                                .fill(draft.level == level ? Theme.gold.opacity(0.06) : Color.clear))
                            .hairlineBorder(draft.level == level ? Theme.gold.opacity(0.35) : Color.white.opacity(0.06),
                                            radius: Theme.rMid)
                        }
                        .buttonStyle(Pressable(scale: 0.99))
                    }
                }

                Panel(padding: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "leaf")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.teal)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("初始纪元 · 原始时代")
                                .font(Theme.title(12.5, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text("没有道路、没有铁、没有常备军。势力从石器聚落开始，用几百年学会冶炼，再学会航海与飞行。")
                                .font(Theme.body(11))
                                .lineSpacing(4)
                                .foregroundStyle(Theme.textDim)
                        }
                    }
                }

                Spacer().frame(height: 130)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - 步骤 1：势力
    private var factionStep: some View {
        let counts = ownerCounts()
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Spacer().frame(height: 62)

                HStack(alignment: .firstTextBaseline) {
                    Text("创建势力")
                        .font(Theme.display(26, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(draft.factions.count) / 8")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.textFaint)
                }

                Text("每个势力都需要一个 AI 核心。你只写下名字与出身，AI 会据此生成口号、旗色与执政路线，然后全权接管它。")
                    .font(Theme.body(11.5))
                    .lineSpacing(4.5)
                    .foregroundStyle(Theme.textDim)

                if draft.factions.isEmpty {
                    emptyFactionCard
                } else {
                    ForEach(Array(draft.factions.indices), id: \.self) { idx in
                        let f = draft.factions[idx]
                        Button {
                            Haptics.select()
                            editing = f
                            editingIsNew = false
                        } label: {
                            factionCard(f, count: idx < counts.count ? counts[idx] : 0)
                        }
                        .buttonStyle(Pressable(scale: 0.99))
                        .contextMenu {
                            Button(role: .destructive) {
                                removeFaction(idx)
                            } label: { Label("移除此势力", systemImage: "trash") }
                        }
                    }
                }

                if draft.factions.count < 8 {
                    Button {
                        Haptics.tap()
                        var f = Faction()
                        f.name = ""
                        f.background = ""
                        f.colorIndex = 0
                        editingIsNew = true
                        editing = f
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                            Text(draft.factions.isEmpty ? "创建第一个势力" : "创建势力")
                                .font(Theme.body(12.5, weight: .medium))
                        }
                        .foregroundStyle(Theme.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                            .fill(Theme.gold.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                            .strokeBorder(Theme.gold.opacity(0.25),
                                          style: StrokeStyle(lineWidth: 0.9, dash: [4, 3])))
                    }
                    .buttonStyle(Pressable())
                }

                if draft.factions.count < 2 {
                    Text("至少需要 2 个配置了 AI 的势力才能开始推演")
                        .font(Theme.label(9))
                        .tracking(1)
                        .foregroundStyle(Theme.textFaint)
                        .padding(.top, 2)
                }

                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private var emptyFactionCard: some View {
        Panel(padding: 22) {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Theme.gold.opacity(0.06)).frame(width: 64, height: 64)
                    Circle().strokeBorder(Theme.gold.opacity(0.22), lineWidth: 0.8).frame(width: 64, height: 64)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Theme.gold)
                }
                Text("还没有势力")
                    .font(Theme.title(15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("创建势力 → 写下出身 → AI 接管。\n没有 AI 的势力无法进入推演。")
                    .font(Theme.body(11.5))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func factionCard(_ f: Faction, count: Int) -> some View {
        Panel(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(f.color.opacity(0.16))
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(f.color.opacity(0.4), lineWidth: 0.9)
                    Image(systemName: f.ai == nil ? "questionmark" : f.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(f.ai == nil ? Theme.textFaint : f.color)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(f.name.isEmpty ? "未命名势力" : f.name)
                            .font(Theme.title(15, weight: .semibold))
                            .foregroundStyle(f.name.isEmpty ? Theme.textFaint : Theme.text)
                        if f.isAIConfigured {
                            Pill(text: "AI 已接管", tint: Theme.teal, fill: Theme.teal.opacity(0.10))
                        } else {
                            Pill(text: "待配置 AI", tint: Theme.ember, fill: Theme.ember.opacity(0.10))
                        }
                        Spacer()
                        Text("\(count) 格")
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.textFaint)
                    }

                    if let ai = f.ai {
                        Text("「\(ai.slogan)」")
                            .font(Theme.display(13, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(Theme.gold.opacity(0.92))
                            .lineLimit(1)
                        Text(ai.name)
                            .font(Theme.mono(8.5))
                            .tracking(1)
                            .foregroundStyle(Theme.textFaint)
                    } else {
                        Text(f.background.isEmpty ? "点按补全出身，并让 AI 接管。" : "背景已写好，等待生成 AI 核心。")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.textFaint)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - 步骤 2：划界
    private var territoryStep: some View {
        GeometryReader { geo in
            let counts = ownerCounts()
            ZStack(alignment: .bottom) {
                if let t = terrain {
                    MapPainterView(world: $draft, terrain: t, owner: brushOwner,
                                   radius: draft.level.brush, tool: $tool)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView().tint(Theme.gold)
                }

                VStack(spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(draft.factions.indices), id: \.self) { idx in
                                let f = draft.factions[idx]
                                Button {
                                    Haptics.select()
                                    brushOwner = idx + 1
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle().fill(f.color).frame(width: 8, height: 8)
                                        Text(f.name)
                                            .font(Theme.body(11, weight: .medium))
                                            .foregroundStyle(brushOwner == idx + 1 ? Theme.text : Theme.textDim)
                                        Text("\(idx < counts.count ? counts[idx] : 0)")
                                            .font(Theme.mono(9))
                                            .foregroundStyle(Theme.textFaint)
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 7)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(brushOwner == idx + 1
                                              ? Theme.factionColor(f.colorIndex).opacity(0.22)
                                              : Theme.panel.opacity(0.92)))
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(brushOwner == idx + 1
                                                      ? f.color.opacity(0.65)
                                                      : Color.white.opacity(0.07),
                                                      lineWidth: 0.9))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    HStack(spacing: 8) {
                        Text(tool == .brush ? "笔刷 \(Int(draft.level.brush))°" : "浏览模式")
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.textFaint)
                        Spacer()
                        smallAction("arrow.uturn.backward", "撤销", enabled: !undoStack.isEmpty) { undo() }
                        smallAction("wand.and.stars", "自动划界") { autoDistribute() }
                        smallAction(tool == .brush ? "hand.draw.fill" : "paintbrush.pointed.fill",
                                    tool == .brush ? "查看" : "划界") {
                            tool = tool == .brush ? .hand : .brush
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous)
                    .fill(Theme.panel.opacity(0.97)))
                .hairlineBorder(Color.white.opacity(0.08), radius: Theme.rLarge)
                .panelShadow(strong: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func smallAction(_ symbol: String, _ title: String, enabled: Bool = true,
                             action: @escaping () -> Void) -> some View {
        Button {
            guard enabled else { return }
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
                Text(title).font(Theme.body(10.5, weight: .medium))
            }
            .foregroundStyle(enabled ? Theme.textSoft : Theme.textFaint.opacity(0.5))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 步骤 3：检视
    private var reviewStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Spacer().frame(height: 62)

                Text("开局检视")
                    .font(Theme.display(26, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.text)

                Panel(padding: 12) {
                    VStack(spacing: 10) {
                        WorldThumbnail(world: draft, size: CGSize(width: 320, height: 126))
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(draft.name)
                                    .font(Theme.title(15, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                Text("\(draft.level.title) · 原始时代 · \(draft.factions.count) 个 AI 势力")
                                    .font(Theme.body(10))
                                    .foregroundStyle(Theme.textDim)
                            }
                            Spacer()
                            Text("已划界 \(Int(claimRatio * 100))%")
                                .font(Theme.mono(10))
                                .foregroundStyle(Theme.gold)
                        }
                    }
                }

                HStack(spacing: 10) {
                    summaryTile("势力", "\(draft.factions.count)", "brain.head.profile")
                    summaryTile("疆域格", "\(draft.claimedLand)", "square.grid.3x3")
                    summaryTile("起始年", "0", "calendar")
                }

                if !missingAI.isEmpty {
                    Panel(padding: 14) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ember)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("还有势力没有 AI")
                                    .font(Theme.title(12, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                Text("\(missingAI.map(\.name).joined(separator: "、")) 需要配置 AI 核心后才能进入推演。")
                                    .font(Theme.body(10.5))
                                    .lineSpacing(3.5)
                                    .foregroundStyle(Theme.textDim)
                            }
                        }
                    }
                }

                if emptyFactions.count > 0 {
                    Panel(padding: 14) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.gold)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("有势力还没有疆域")
                                    .font(Theme.title(12, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                Text("\(emptyFactions.map(\.name).joined(separator: "、")) 会在第一年就消失。返回上一步给它们划一块地。")
                                    .font(Theme.body(10.5))
                                    .lineSpacing(3.5)
                                    .foregroundStyle(Theme.textDim)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "AI 势力", english: "AUTONOMOUS")
                    ForEach(Array(draft.factions.indices), id: \.self) { idx in
                        let f = draft.factions[idx]
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Circle().fill(f.color).frame(width: 7, height: 7)
                                Text(f.name)
                                    .font(Theme.body(12.5, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                Text(f.aiName)
                                    .font(Theme.mono(8))
                                    .foregroundStyle(Theme.textFaint)
                                Spacer()
                                Text("\(cellCount(idx + 1)) 格")
                                    .font(Theme.mono(9))
                                    .foregroundStyle(Theme.textFaint)
                            }
                            if !f.slogan.isEmpty {
                                Text("「\(f.slogan)」")
                                    .font(Theme.display(12))
                                    .tracking(0.8)
                                    .foregroundStyle(Theme.gold.opacity(0.8))
                                    .padding(.leading, 15)
                            }
                        }
                        .padding(.vertical, 7)
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.6)
                    }
                }

                GoldButton(title: isEditing ? "保存并继续演变" : "开始演变",
                           subtitle: "\(draft.factions.count) 个 AI 将自行决定接下来几百年",
                           symbol: "play.fill",
                           enabled: missingAI.isEmpty && !draft.factions.isEmpty) {
                    finish()
                }
                .padding(.top, 4)

                Text("开局后仍可进入编辑，修改 AI 的背景设定与疆域。")
                    .font(Theme.label(9))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textFaint)
                    .frame(maxWidth: .infinity)

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryTile(_ title: String, _ value: String, _ symbol: String) -> some View {
        Panel(padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.gold.opacity(0.8))
                Text(value)
                    .font(Theme.mono(18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(title)
                    .font(Theme.label(9)).tracking(1)
                    .foregroundStyle(Theme.textFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 数据
    private var claimRatio: Double {
        Double(draft.claimedLand) / Double(max(1, GeoWorld.shared.landCount))
    }

    private var missingAI: [Faction] {
        draft.factions.filter { !$0.isAIConfigured }
    }

    private var emptyFactions: [Faction] {
        var out: [Faction] = []
        for idx in draft.factions.indices where cellCount(idx + 1) == 0 {
            out.append(draft.factions[idx])
        }
        return out
    }

    private func usedColors(excluding id: UUID) -> [Int] {
        draft.factions.filter { $0.id != id }.map(\.colorIndex)
    }

    private func ownerCounts() -> [Int] {
        var counts = [Int](repeating: 0, count: max(1, draft.factions.count))
        for c in draft.territory.cells where c != 0 {
            let i = Int(c) - 1
            if i >= 0 && i < counts.count { counts[i] += 1 }
        }
        return counts
    }

    private func cellCount(_ owner: Int) -> Int {
        var n = 0
        for c in draft.territory.cells where Int(c) == owner { n += 1 }
        return n
    }

    private func removeFaction(_ index: Int) {
        guard index < draft.factions.count else { return }
        var cells = draft.territory.cells
        for i in cells.indices {
            let o = Int(cells[i])
            if o == 0 { continue }
            if o == index + 1 { cells[i] = 0 }
            else if o > index + 1 { cells[i] = UInt8(o - 1) }
        }
        draft.territory = TerritoryData(cells: cells)
        draft.factions.remove(at: index)
        brushOwner = min(max(1, brushOwner), max(1, draft.factions.count))
        Haptics.warning()
    }

    private func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        draft.territory = TerritoryData(cells: snapshot)
        Haptics.select()
    }

    private func autoDistribute() {
        guard let t = terrain, !draft.factions.isEmpty else { return }
        if undoStack.count >= 6 { undoStack.removeFirst() }
        undoStack.append(draft.territory.cells)
        draft.territory = TerritoryData(cells: [UInt8](repeating: 0,
                                                       count: GeoWorld.shared.gridW * GeoWorld.shared.gridH))
        var w = draft
        WorldBuilder.autoDistribute(&w, terrain: t)
        draft = w
        brushOwner = 1
        Haptics.success()
        store.flash("已按最远点分布 \(draft.factions.count) 个势力")
    }

    private func finish() {
        guard let t = terrain else { return }
        var w = draft
        w.phase = .evolving
        w.lastActiveAt = Date()
        if isEditing {
            for i in w.factions.indices {
                if let ai = w.factions[i].ai {
                    BackgroundInterpreter.apply(to: &w.factions[i])
                    w.factions[i].doctrine = ai.doctrine
                    w.factions[i].aggression = ai.aggression
                    w.factions[i].industry = ai.industry
                    w.factions[i].science = ai.science
                    w.factions[i].expansion = ai.expansion
                }
            }
            store.update(w)
            store.flash("已保存")
        } else {
            w.continuous = true
            WorldBuilder.finish(&w, terrain: t)
            store.add(w)
        }
        Haptics.success()
        let id = w.id
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onFinish?(id) }
    }
}

// MARK: - 势力编辑器（名字 + 背景 → AI 接管）
struct FactionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var initial: Faction
    var isNew: Bool
    var worldSeed: UInt64
    var usedColors: [Int]
    var onSave: (Faction) -> Void

    @State private var draft: Faction
    @State private var generating = false
    @State private var phase = 0
    @State private var scan: CGFloat = -1
    @State private var aiReveal = false

    private let phases = ["读取背景语义", "推导执政路线", "生成旗色与口号", "AI 接管完成"]

    init(initial: Faction, isNew: Bool, worldSeed: UInt64,
         usedColors: [Int], onSave: @escaping (Faction) -> Void) {
        self.initial = initial
        self.isNew = isNew
        self.worldSeed = worldSeed
        self.usedColors = usedColors
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && draft.ai != nil
    }

    var body: some View {
        ZStack {
            Backdrop(showGrid: false)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(isNew ? "创建势力" : "编辑势力")
                            .font(Theme.display(22, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.textDim)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 22)

                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "名号", english: "NAME")
                        TextField("势力名称", text: $draft.name)
                            .font(Theme.title(22, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .padding(.vertical, 8)
                        Rectangle()
                            .fill(LinearGradient(colors: [Theme.gold, Theme.gold.opacity(0.08)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(height: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SectionLabel(text: "初始背景", english: "ORIGIN")
                            Spacer()
                            Text("\(draft.background.count) 字")
                                .font(Theme.mono(8.5))
                                .foregroundStyle(Theme.textFaint)
                        }
                        ZStack(alignment: .topLeading) {
                            if draft.background.isEmpty {
                                Text("写下它从哪里来：地理、物产、信仰、恐惧、仇恨。\nAI 会从这段文字里读出它的一切。")
                                    .font(Theme.body(11.5))
                                    .lineSpacing(4.5)
                                    .foregroundStyle(Theme.textFaint)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 13)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $draft.background)
                                .font(Theme.body(12))
                                .lineSpacing(5)
                                .foregroundStyle(Theme.textSoft)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(minHeight: 148)
                        }
                        .background(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous)
                            .fill(Color.white.opacity(0.035)))
                        .hairlineBorder(Color.white.opacity(0.08), radius: Theme.rSmall)
                    }

                    aiSection

                    GoldButton(title: isNew ? "让 AI 接管并保存" : "保存",
                               subtitle: canSave ? "AI 将全权决定这个势力的一切" : "先写好名字并生成 AI",
                               symbol: "checkmark.seal.fill",
                               enabled: canSave) {
                        onSave(draft)
                        dismiss()
                    }
                    .padding(.top, 2)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            if draft.ai != nil { aiReveal = true }
        }
    }

    // MARK: AI 区块
    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "AI 核心", english: "CORE")
                Spacer()
                if let ai = draft.ai, !generating {
                    Button {
                        Haptics.tap()
                        withAnimation(Motion.quick) {
                            draft.ai = FactionAIForge.recolor(ai, background: draft.background,
                                                              usedColors: usedColors)
                            draft.colorIndex = draft.ai?.colorIndex ?? draft.colorIndex
                        }
                    } label: {
                        Text("换配色").font(Theme.label(9)).tracking(1)
                            .foregroundStyle(Theme.textDim)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                }
            }

            if generating {
                generatingCard
            } else if let ai = draft.ai {
                aiCard(ai)
                    .opacity(aiReveal ? 1 : 0)
                    .offset(y: aiReveal ? 0 : 10)
                HStack(spacing: 8) {
                    GhostButton(title: "重新生成", symbol: "arrow.triangle.2.circlepath") {
                        generate()
                    }
                    Text(ai.model)
                        .font(Theme.mono(8))
                        .tracking(1)
                        .foregroundStyle(Theme.textFaint)
                    Spacer()
                }
            } else {
                Button {
                    generate()
                } label: {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                            Text("为此势力生成 AI 核心")
                                .font(Theme.body(13, weight: .semibold))
                        }
                        .foregroundStyle(Theme.gold)
                        Text("依据背景推导口号、旗色与执政路线")
                            .font(Theme.body(10))
                            .foregroundStyle(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                        .fill(Theme.gold.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(0.3),
                                      style: StrokeStyle(lineWidth: 0.9, dash: [5, 4])))
                }
                .buttonStyle(Pressable())
            }
        }
    }

    private var generatingCard: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ProgressView().tint(Theme.gold).scaleEffect(0.7)
                    Text(phases[min(phase, phases.count - 1)])
                        .font(Theme.body(12, weight: .medium))
                        .foregroundStyle(Theme.textSoft)
                    Spacer()
                    Text("LOCAL CORE 2")
                        .font(Theme.mono(7.5))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textFaint)
                }
                Text("▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.gold.opacity(0.35))
                Text("▓▓▓▓▓▓▓▓▓▓▓▓")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.gold.opacity(0.2))
            }
            .padding(16)

            LinearGradient(colors: [.clear, Theme.gold.opacity(0.55), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1.2)
                .padding(.horizontal, 6)
                .offset(y: scan)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
            .fill(Theme.panel))
        .hairlineBorder(Theme.gold.opacity(0.22), radius: Theme.rMid)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous))
        .onAppear {
            scan = -4
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                scan = 124
            }
        }
    }

    private func aiCard(_ ai: FactionAI) -> some View {
        Panel(padding: 16, radius: Theme.rMid, raised: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Theme.factionColor(ai.colorIndex).opacity(0.22))
                        Circle().strokeBorder(Theme.factionColor(ai.colorIndex).opacity(0.7), lineWidth: 1)
                        Circle().fill(Theme.factionColor(ai.colorIndex)).frame(width: 10, height: 10)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ai.name)
                            .font(Theme.title(13, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text("AI 已接管 · \(Theme.factionColorName(ai.colorIndex))")
                            .font(Theme.label(8.5))
                            .tracking(1)
                            .foregroundStyle(Theme.teal)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.teal)
                }

                Text("「\(ai.slogan)」")
                    .font(Theme.display(18, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(LinearGradient(colors: [Theme.text, Theme.gold],
                                                   startPoint: .top, endPoint: .bottom))
                    .fixedSize(horizontal: false, vertical: true)

                Text(ai.brief)
                    .font(Theme.body(11.5))
                    .lineSpacing(4.5)
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: 生成
    private func generate() {
        guard !generating else { return }
        Haptics.tap()
        generating = true
        phase = 0
        aiReveal = false
        Task { @MainActor in
            for i in 0..<phases.count {
                phase = i
                try? await Task.sleep(nanoseconds: 240_000_000)
            }
            let seed = worldSeed
                &+ UInt64(abs((draft.name + draft.background).hashValue % 999_983))
            let ai = FactionAIForge.generate(name: draft.name.isEmpty ? "无名势力" : draft.name,
                                             background: draft.background,
                                             seed: seed,
                                             usedColors: usedColors)
            draft.ai = ai
            draft.colorIndex = ai.colorIndex
            draft.doctrine = ai.doctrine
            draft.symbol = ai.doctrine.symbol
            draft.aggression = ai.aggression
            draft.industry = ai.industry
            draft.science = ai.science
            draft.expansion = ai.expansion
            generating = false
            withAnimation(Motion.spring) { aiReveal = true }
            Haptics.success()
        }
    }
}

struct IndexBox: Identifiable {
    var index: Int
    var id: Int { index }
}
