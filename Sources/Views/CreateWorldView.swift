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
    @State private var editingFaction: Int? = nil
    @State private var appeared = false

    private let stepTitles = ["命名与纪元", "划定疆域", "配置势力", "检视开局"]

    init(initialWorld: World?, onFinish: ((UUID) -> Void)? = nil) {
        self.initialWorld = initialWorld
        self.onFinish = onFinish
        if let w = initialWorld {
            _draft = State(initialValue: w)
            _isEditing = State(initialValue: true)
            let forceMap = ProcessInfo.processInfo.arguments.contains("-previewMap")
            _step = State(initialValue: (w.phase == .draft && !forceMap) ? 0 : 1)
        } else {
            let seed = UInt64.random(in: 1...99_999_999)
            var w = WorldBuilder.blankWorld(name: NameForge.worldName(seed: seed),
                                            seed: seed, level: .nation)
            w.factions = (0..<4).map { WorldBuilder.newFaction(index: $0, seed: seed) }
            _draft = State(initialValue: w)
            _isEditing = State(initialValue: false)
        }
    }

    var body: some View {
        ZStack {
            Backdrop(showGrid: step != 1)

            switch step {
            case 0: nameStep
            case 1: territoryStep
            case 2: factionStep
            default: reviewStep
            }

            VStack(spacing: 0) {
                topBar
                Spacer()
            }
        }
        .onAppear {
            if terrain == nil { terrain = store.terrain(for: draft) }
            withAnimation(Motion.standard) { appeared = true }
        }
        .sheet(item: Binding(
            get: { editingFaction.map { IndexBox(index: $0) } },
            set: { editingFaction = $0?.index }
        )) { box in
            if let t = terrain, box.index < draft.factions.count {
                FactionEditorView(
                    faction: $draft.factions[box.index],
                    terrain: t,
                    worldSeed: draft.seed,
                    canDelete: draft.factions.count > 1,
                    onDelete: {
                        removeFaction(box.index)
                        editingFaction = nil
                    }
                )
                .presentationDetents([.large])
            }
        }
        .interactiveDismissDisabled(hasProgress)
    }

    private var hasProgress: Bool { !isEditing }

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
                    .background(Circle().fill(Color.white.opacity(0.05)))
                    .hairlineBorder(Color.white.opacity(0.08), radius: 999)
            }
            .buttonStyle(Pressable())

            VStack(alignment: .leading, spacing: 3) {
                Text(isEditing ? "编辑战争" : "创建战争")
                    .font(Theme.label(9))
                    .tracking(2)
                    .foregroundStyle(Theme.gold.opacity(0.8))
                Text(stepTitles[min(step, stepTitles.count - 1)])
                    .font(Theme.title(14, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }

            Spacer()

            // 步骤进度
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.gold : Color.white.opacity(0.12))
                        .frame(width: i == step ? 16 : 6, height: 3)
                        .animation(Motion.quick, value: step)
                }
            }
            .padding(.trailing, 4)

            if step < 3 {
                Button {
                    Haptics.select()
                    if step == 1 { commitPaint() }
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
                .opacity(canAdvance ? 1 : 0.4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return draft.claimedLand > 0
        case 2: return draft.factions.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        default: return true
        }
    }

    // MARK: - 步骤 0：命名
    private var nameStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Spacer().frame(height: 58)

                Text("给你的世界一个名字")
                    .font(Theme.display(28, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.text, Theme.sand],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .padding(.top, 12)

                Text("它会被刻在时间线的起点，此后每一次兴亡都记在这个名字下面。")
                    .font(Theme.body(12))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.textDim)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("世界名称", text: $draft.name)
                        .font(Theme.display(24, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .padding(.vertical, 10)
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.gold, Theme.gold.opacity(0.1)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                    HStack {
                        Text("SEED \(String(format: "%08X", UInt32(truncatingIfNeeded: draft.seed)))")
                            .font(Theme.mono(9))
                            .tracking(1)
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
                .padding(.top, 4)

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
                                Text("笔刷 \(level.brush)°")
                                    .font(Theme.mono(9))
                                    .foregroundStyle(Theme.textFaint)
                                Circle()
                                    .strokeBorder(draft.level == level ? Theme.gold : Color.white.opacity(0.18),
                                                  lineWidth: draft.level == level ? 4 : 1)
                                    .frame(width: 14, height: 14)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                                    .fill(draft.level == level ? Theme.gold.opacity(0.06) : Color.clear)
                            )
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

    // MARK: - 步骤 1：划界
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
                    // 势力笔刷
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
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(brushOwner == idx + 1 ? Theme.factionColor(f.colorIndex).opacity(0.18) : Theme.panel.opacity(0.9))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(brushOwner == idx + 1 ? f.color.opacity(0.6) : Color.white.opacity(0.07),
                                                          lineWidth: 0.9)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                addFaction()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                                    Text("势力").font(Theme.body(11, weight: .medium))
                                }
                                .foregroundStyle(Theme.gold)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Theme.gold.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Theme.gold.opacity(0.25), lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 2)
                    }

                    HStack(spacing: 8) {
                        Text(tool == .brush ? "\(draft.level.brush * 2)° 笔刷" : "浏览模式")
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.textFaint)
                        Spacer()
                        smallAction("arrow.uturn.backward", "撤销", enabled: !undoStack.isEmpty) {
                            undo()
                        }
                        smallAction("wand.and.stars", "智能分布") {
                            autoDistribute()
                        }
                        smallAction(tool == .brush ? "hand.draw.fill" : "paintbrush.pointed.fill",
                                    tool == .brush ? "查看" : "划界") {
                            tool = tool == .brush ? .hand : .brush
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous)
                        .fill(Theme.panel.opacity(0.97))
                )
                .hairlineBorder(Color.white.opacity(0.08), radius: Theme.rLarge)
                .panelShadow(strong: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func smallAction(_ symbol: String, _ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
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

    // MARK: - 步骤 2：势力
    private var factionStep: some View {
        let counts = ownerCounts()
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Spacer().frame(height: 56)

                HStack(alignment: .firstTextBaseline) {
                    Text("配置势力")
                        .font(Theme.display(24, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(draft.factions.count) / 12")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.textFaint)
                }

                Text("写下每个势力的出身、资源与野心。系统会从文字里读出它的路线，再让它按这条路线活几百年。")
                    .font(Theme.body(11.5))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.textDim)
                    .padding(.bottom, 2)

                ForEach(Array(draft.factions.indices), id: \.self) { idx in
                    let f = draft.factions[idx]
                    Button {
                        Haptics.select()
                        editingFaction = idx
                    } label: {
                        factionCard(idx: idx, faction: f, count: idx < counts.count ? counts[idx] : 0)
                    }
                    .buttonStyle(Pressable(scale: 0.99))
                }

                if draft.factions.count < 12 {
                    Button {
                        addFaction()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                            Text("添加势力").font(Theme.body(12.5, weight: .medium))
                        }
                        .foregroundStyle(Theme.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                                .fill(Theme.gold.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                                .strokeBorder(Theme.gold.opacity(0.25),
                                              style: StrokeStyle(lineWidth: 0.9, dash: [4, 3]))
                        )
                    }
                    .buttonStyle(Pressable())
                }

                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func factionCard(idx: Int, faction f: Faction, count: Int) -> some View {
        Panel(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(f.color.opacity(0.14))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(f.color.opacity(0.35), lineWidth: 0.9)
                    Image(systemName: f.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(f.color)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(f.name)
                            .font(Theme.title(15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Pill(text: f.doctrine.title, tint: f.color.opacity(0.9),
                             fill: f.color.opacity(0.10))
                        Spacer()
                        Text("\(count) 格")
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.textFaint)
                    }
                    Text(f.background.isEmpty ? "尚未写下背景 —— 点按补全出身与野心。" : f.background)
                        .font(Theme.body(11))
                        .lineSpacing(3.5)
                        .foregroundStyle(f.background.isEmpty ? Theme.textFaint : Theme.textDim)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 10) {
                        trait("尚武", f.aggression)
                        trait("工造", f.industry)
                        trait("崇文", f.science)
                        trait("扩张", f.expansion)
                    }
                    .padding(.top, 2)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
                    .padding(.top, 4)
            }
        }
    }

    private func trait(_ name: String, _ v: Double) -> some View {
        HStack(spacing: 3) {
            Text(name).font(Theme.label(8.5)).foregroundStyle(Theme.textFaint)
            Text(String(format: "%.0f", v * 100))
                .font(Theme.mono(9))
                .foregroundStyle(Theme.textSoft)
        }
    }

    // MARK: - 步骤 3：检视
    private var reviewStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Spacer().frame(height: 56)

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
                                Text("\(draft.level.title) · 原始时代 · \(draft.factions.count) 势力")
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
                    summaryTile("势力", "\(draft.factions.count)", "shield.lefthalf.filled")
                    summaryTile("疆域格", "\(draft.claimedLand)", "square.grid.3x3")
                    summaryTile("起始年", "0", "calendar")
                }

                if emptyFactions.count > 0 {
                    Panel(padding: 14) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ember)
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

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "参战势力", english: "FACTIONS")
                    ForEach(Array(draft.factions.indices), id: \.self) { idx in
                        let f = draft.factions[idx]
                        HStack(spacing: 9) {
                            Circle().fill(f.color).frame(width: 7, height: 7)
                            Text(f.name).font(Theme.body(12.5, weight: .medium)).foregroundStyle(Theme.text)
                            Pill(text: f.doctrine.title, tint: Theme.textDim, mono: true)
                            Spacer()
                            Text("\(cellCount(idx + 1)) 格")
                                .font(Theme.mono(9.5))
                                .foregroundStyle(Theme.textFaint)
                        }
                        .padding(.vertical, 6)
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.6)
                    }
                }

                GoldButton(title: isEditing ? "保存并继续演变" : "开始演变",
                           subtitle: "让 \(draft.factions.count) 个势力自己走完接下来的几百年",
                           symbol: "play.fill") {
                    finish()
                }
                .padding(.top, 6)

                Text("开局后仍可随时进入编辑，修改势力背景与疆域。")
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
                    .font(Theme.label(9))
                    .tracking(1)
                    .foregroundStyle(Theme.textFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 动作
    private var claimRatio: Double {
        Double(draft.claimedLand) / Double(max(1, GeoWorld.shared.landCount))
    }

    private var emptyFactions: [Faction] {
        var out: [Faction] = []
        for idx in draft.factions.indices where cellCount(idx + 1) == 0 {
            out.append(draft.factions[idx])
        }
        return out
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

    private func addFaction() {
        guard draft.factions.count < 12 else { return }
        let idx = draft.factions.count
        var f = WorldBuilder.newFaction(index: idx, seed: draft.seed &+ UInt64(idx &* 31))
        f.name = NameForge.factionName(seed: draft.seed, index: idx)
        f.background = ""
        draft.factions.append(f)
        brushOwner = idx + 1
        withAnimation(Motion.spring) {}
        Haptics.success()
    }

    private func removeFaction(_ index: Int) {
        guard draft.factions.count > 1, index < draft.factions.count else { return }
        // 清除该势力疆域并重建 owner 索引
        var cells = draft.territory.cells
        for i in cells.indices {
            let o = Int(cells[i])
            if o == 0 { continue }
            if o == index + 1 { cells[i] = 0 }
            else if o > index + 1 { cells[i] = UInt8(o - 1) }
        }
        draft.territory = TerritoryData(cells: cells)
        draft.factions.remove(at: index)
        brushOwner = min(brushOwner, draft.factions.count)
        if brushOwner < 1 { brushOwner = 1 }
        Haptics.warning()
    }

    private func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        draft.territory = TerritoryData(cells: snapshot)
        Haptics.select()
    }

    private func commitPaint() {
        // 记录一次快照用于撤销
        if undoStack.count >= 8 { undoStack.removeFirst() }
        undoStack.append(draft.territory.cells)
    }

    private func autoDistribute() {
        guard let t = terrain else { return }
        commitPaint()
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
                BackgroundInterpreter.apply(to: &w.factions[i])
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onFinish?(id)
        }
    }
}

struct IndexBox: Identifiable {
    var index: Int
    var id: Int { index }
}

// MARK: - 势力编辑
struct FactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var faction: Faction
    var terrain: TerrainMap
    var worldSeed: UInt64
    var canDelete: Bool
    var onDelete: () -> Void

    @State private var read: BackgroundRead = BackgroundRead()

    private let symbols = ["shield.lefthalf.filled", "crown.fill", "flame.fill", "bolt.fill",
                           "leaf.fill", "mountain.2.fill", "sailboat.fill", "building.columns.fill",
                           "figure.walk", "cart.fill", "book.closed.fill", "hammer.fill"]

    var body: some View {
        ZStack {
            Backdrop(showGrid: false)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("势力设定")
                            .font(Theme.display(22, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Button { dismiss() } label: {
                            Text("完成")
                                .font(Theme.body(12, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Theme.gold))
                        }
                    }
                    .padding(.top, 22)

                    // 名称
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "名号", english: "NAME")
                        TextField("势力名称", text: $faction.name)
                            .font(Theme.title(20, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .padding(.vertical, 8)
                        Rectangle()
                            .fill(LinearGradient(colors: [Theme.gold, Theme.gold.opacity(0.1)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(height: 1)
                    }

                    // 徽记
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "徽记", english: "SIGIL")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(symbols, id: \.self) { s in
                                Button {
                                    Haptics.select()
                                    faction.symbol = s
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(faction.symbol == s ? faction.color.opacity(0.20) : Color.white.opacity(0.04))
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .strokeBorder(faction.symbol == s ? faction.color.opacity(0.75) : Color.white.opacity(0.07),
                                                          lineWidth: 0.9)
                                        Image(systemName: s)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(faction.symbol == s ? faction.color : Theme.textDim)
                                    }
                                    .frame(height: 44)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 颜色
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "旗色", english: "COLOR")
                        HStack(spacing: 8) {
                            ForEach(Array(Theme.factionColors.indices), id: \.self) { idx in
                                let c = Theme.factionColors[idx]
                                Button {
                                    Haptics.select()
                                    faction.colorIndex = idx
                                } label: {
                                    Circle()
                                        .fill(c)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle().strokeBorder(Theme.text.opacity(faction.colorIndex == idx ? 0.9 : 0),
                                                                  lineWidth: 1.6)
                                                .padding(-3)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text(Theme.factionColorName(faction.colorIndex))
                            .font(Theme.label(9))
                            .tracking(1.4)
                            .foregroundStyle(Theme.textFaint)
                    }

                    // 路线
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "立国路线", english: "DOCTRINE")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                            ForEach(Doctrine.allCases) { d in
                                Button {
                                    Haptics.select()
                                    faction.doctrine = d
                                    faction.aggression = d.aggression
                                    faction.science = d.science
                                    faction.expansion = d.expansion
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: d.symbol)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(faction.doctrine == d ? Theme.gold : Theme.textDim)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(d.title)
                                                .font(Theme.body(12, weight: .semibold))
                                                .foregroundStyle(Theme.text)
                                            Text(d.detail)
                                                .font(Theme.label(8))
                                                .foregroundStyle(Theme.textFaint)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(faction.doctrine == d ? Theme.gold.opacity(0.08) : Color.white.opacity(0.03))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .strokeBorder(faction.doctrine == d ? Theme.gold.opacity(0.4) : Color.white.opacity(0.06),
                                                          lineWidth: 0.9)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 背景
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SectionLabel(text: "初始背景", english: "ORIGIN")
                            Spacer()
                            Button {
                                Haptics.select()
                                BackgroundInterpreter.apply(to: &faction)
                                read = BackgroundInterpreter.read(faction.background)
                                storeRead()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles").font(.system(size: 9, weight: .semibold))
                                    Text("解析").font(Theme.body(10, weight: .medium))
                                }
                                .foregroundStyle(Theme.gold)
                            }
                            .buttonStyle(.plain)
                        }

                        ZStack(alignment: .topLeading) {
                            if faction.background.isEmpty {
                                Text("例：起于北方苦寒之地的骑射部族，以军功授爵，视边界为暂借。铁器稀缺，但马匹充足……")
                                    .font(Theme.body(11.5))
                                    .lineSpacing(4)
                                    .foregroundStyle(Theme.textFaint)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $faction.background)
                                .font(Theme.body(12))
                                .lineSpacing(4)
                                .foregroundStyle(Theme.textSoft)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(minHeight: 132)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous)
                                .fill(Color.white.opacity(0.035))
                        )
                        .hairlineBorder(Color.white.opacity(0.08), radius: Theme.rSmall)

                        // 解析结果
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.teal)
                            Text(read.summary.isEmpty ? "写入背景后点「解析」" : read.summary)
                                .font(Theme.body(10.5))
                                .foregroundStyle(Theme.textDim)
                            Spacer()
                        }
                        if !read.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(read.tags, id: \.self) { tag in
                                        Pill(text: tag, tint: Theme.teal, fill: Theme.teal.opacity(0.10), mono: true)
                                    }
                                }
                            }
                        }
                    }

                    // 性格
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "性格权重", english: "TRAITS")
                        traitSlider("尚武", $faction.aggression)
                        traitSlider("工造", $faction.industry)
                        traitSlider("崇文", $faction.science)
                        traitSlider("扩张", $faction.expansion)
                    }

                    if canDelete {
                        Button {
                            Haptics.warning()
                            onDelete()
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash").font(.system(size: 10, weight: .semibold))
                                Text("移除此势力").font(Theme.body(12, weight: .medium))
                            }
                            .foregroundStyle(Theme.ember)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous)
                                .fill(Theme.ember.opacity(0.07)))
                            .overlay(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous)
                                .strokeBorder(Theme.ember.opacity(0.25), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            read = BackgroundInterpreter.read(faction.background)
        }
        .onChange(of: faction.background) { _ in
            read = BackgroundInterpreter.read(faction.background)
        }
    }

    private func storeRead() {
        // 触发一次重绘
        read = BackgroundInterpreter.read(faction.background)
    }

    private func traitSlider(_ name: String, _ value: Binding<Double>) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(name).font(Theme.label(10)).tracking(1).foregroundStyle(Theme.textDim)
                Spacer()
                Text(String(format: "%.0f", value.wrappedValue * 100))
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.textSoft)
            }
            Slider(value: value, in: 0.05...0.95)
                .tint(Theme.gold)
        }
    }
}
