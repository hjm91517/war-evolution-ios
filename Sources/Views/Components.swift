import SwiftUI

// MARK: - 背景
struct Backdrop: View {
    var showGrid: Bool = true

    var body: some View {
        ZStack {
            Theme.ink
            LinearGradient(
                colors: [Color(hex: 0x0A1114), Color(hex: 0x06090B), Color(hex: 0x040607)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Theme.gold.opacity(0.11), .clear],
                center: UnitPoint(x: 0.08, y: 0.0), startRadius: 0, endRadius: 520
            )
            RadialGradient(
                colors: [Theme.teal.opacity(0.09), .clear],
                center: UnitPoint(x: 1.0, y: 0.92), startRadius: 0, endRadius: 460
            )
            if showGrid {
                Canvas { ctx, size in
                    var p = Path()
                    let step: CGFloat = 48
                    var x: CGFloat = 0
                    while x <= size.width {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        y += step
                    }
                    ctx.stroke(p, with: .color(Color.white.opacity(0.02)), lineWidth: 0.5)
                }
                .mask(LinearGradient(colors: [.white.opacity(0.9), .clear],
                                     startPoint: .top, endPoint: .bottom))
            }
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.5)],
                center: .center, startRadius: 140, endRadius: 560
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - 面板
struct Panel<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = Theme.rMid
    var raised: Bool = false
    var borderOpacity: Double = 0.07
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(raised ? Theme.panelUp : Theme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.045), .clear],
                                                 startPoint: .top, endPoint: .center))
                    )
            )
            .hairlineBorder(Color.white.opacity(borderOpacity), radius: radius)
            .panelShadow()
    }
}

// MARK: - 主按钮
struct GoldButton: View {
    var title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    var enabled: Bool = true
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: {
            guard enabled else { return }
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 10) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: compact ? 14 : 16, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.title(compact ? 14 : 16, weight: .semibold))
                        .tracking(1.2)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.body(11))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .opacity(0.65)
            }
            .foregroundStyle(Color(hex: 0x161005))
            .padding(.horizontal, compact ? 14 : 18)
            .padding(.vertical, compact ? 11 : 15)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.goldBright, Theme.gold, Color(hex: 0xB98B45)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                    )
            )
            .shadow(color: Theme.gold.opacity(enabled ? 0.28 : 0), radius: 18, x: 0, y: 8)
            .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(Pressable())
        .disabled(!enabled)
    }
}

// MARK: - 次级按钮
struct GhostButton: View {
    var title: String
    var symbol: String? = nil
    var tint: Color = Theme.textSoft
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 7) {
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .semibold)) }
                Text(title).font(Theme.body(13, weight: .medium)).tracking(0.4)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .hairlineBorder(Color.white.opacity(0.09), radius: Theme.rSmall)
        }
        .buttonStyle(Pressable())
    }
}

// MARK: - 小标签
struct Pill: View {
    var text: String
    var tint: Color = Theme.textDim
    var fill: Color = Color.white.opacity(0.06)
    var mono: Bool = false

    var body: some View {
        Text(text)
            .font(mono ? Theme.mono(10) : Theme.label(10))
            .tracking(mono ? 0.5 : 0.8)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous).fill(fill)
            )
            .overlay(
                Capsule(style: .continuous).strokeBorder(tint.opacity(0.22), lineWidth: 0.8)
            )
    }
}

// MARK: - 分区标题
struct SectionLabel: View {
    var text: String
    var english: String? = nil
    var tint: Color = Theme.textDim

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Theme.gold.opacity(0.8))
                .frame(width: 3, height: 10)
                .rotationEffect(.degrees(45))
            Text(text)
                .font(Theme.label(10))
                .tracking(1.6)
                .foregroundStyle(tint)
            if let english {
                Text(english)
                    .font(Theme.mono(9, weight: .regular))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textFaint)
            }
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.6)
        }
    }
}

// MARK: - 数据条
struct StatBar: View {
    var label: String
    var value: Double
    var maxValue: Double
    var tint: Color
    var display: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(Theme.label(10))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Text(display)
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundStyle(Theme.textSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.85), tint],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * min(1, max(0, value / max(1, maxValue)))))
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - 空态
struct EmptyState: View {
    var symbol: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.06))
                    .frame(width: 66, height: 66)
                Circle()
                    .strokeBorder(Theme.gold.opacity(0.22), lineWidth: 0.8)
                    .frame(width: 66, height: 66)
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Theme.gold)
            }
            Text(title)
                .font(Theme.title(16, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(Theme.body(12.5))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}

// MARK: - Toast
struct ToastView: View {
    var text: String
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Theme.gold)
                .frame(width: 2, height: 12)
            Text(text)
                .font(Theme.body(12.5, weight: .medium))
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous).fill(Theme.panelUp.opacity(0.96))
        )
        .hairlineBorder(Theme.gold.opacity(0.25), radius: 999)
        .panelShadow()
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - 顶部浮动栏（毛玻璃不做厚玻璃，只做半透明底色 + 发丝线）
struct FloatingBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                    .fill(Theme.panel.opacity(0.92))
            )
            .hairlineBorder(Color.white.opacity(0.08), radius: Theme.rMid)
            .panelShadow()
    }
}

// MARK: - 图标徽章
struct IconBadge: View {
    var symbol: String
    var tint: Color
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(tint.opacity(0.13))
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .strokeBorder(tint.opacity(0.30), lineWidth: 0.8)
            Image(systemName: symbol)
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 分段控制器
struct SegmentedInline: View {
    var items: [String]
    var selection: Int
    var onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(items.indices), id: \.self) { idx in
                let item = items[idx]
                Button {
                    Haptics.select()
                    withAnimation(Motion.quick) { onSelect(idx) }
                } label: {
                    Text(item)
                        .font(Theme.body(11.5, weight: selection == idx ? .semibold : .regular))
                        .tracking(0.5)
                        .foregroundStyle(selection == idx ? Theme.ink : Theme.textDim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == idx ? Theme.gold : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .hairlineBorder(Color.white.opacity(0.07), radius: 8)
    }
}
