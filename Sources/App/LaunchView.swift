import SwiftUI

// MARK: - 启动符号动画
struct LaunchView: View {
    var onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ringTrim: CGFloat = 0
    @State private var emblemIn = false
    @State private var graticuleIn = false
    @State private var titleIn = false
    @State private var subtitleIn = false
    @State private var glowIn = false
    @State private var progress: CGFloat = 0
    @State private var spin: Double = 0
    @State private var leaving = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Backdrop(showGrid: true)
                .opacity(leaving ? 0 : 1)

            RadialGradient(
                colors: [Theme.gold.opacity(glowIn ? 0.20 : 0.02), .clear],
                center: .center, startRadius: 10, endRadius: 360
            )
            .opacity(leaving ? 0 : 1)
            .animation(.easeOut(duration: 1.6), value: glowIn)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                emblem
                    .frame(width: 188, height: 188)
                    .scaleEffect(emblemIn ? 1 : 0.86)
                    .opacity(emblemIn ? 1 : 0)

                Spacer().frame(height: 46)

                titleBlock

                Spacer()

                progressBlock
                    .padding(.bottom, 54)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("轻触跳过")
                        .font(Theme.label(10))
                        .tracking(2)
                        .foregroundStyle(Theme.textFaint)
                        .opacity(subtitleIn ? 1 : 0)
                        .padding(.trailing, 22)
                        .padding(.bottom, 18)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finishNow() }
        .opacity(leaving ? 0 : 1)
        .scaleEffect(leaving ? 1.05 : 1)
        .onAppear { runSequence() }
    }

    // MARK: 徽记
    private var emblem: some View {
        ZStack {
            // 外环刻度
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = min(size.width, size.height) / 2 - 2
                for i in 0..<72 {
                    let a = Double(i) / 72.0 * Double.pi * 2
                    let long = i % 6 == 0
                    let inner = r - (long ? 9 : 5)
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
                    p.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                    ctx.stroke(p, with: .color(Theme.gold.opacity(long ? 0.55 : 0.22)), lineWidth: 0.8)
                }
                // 四个方向的加长刻度
                for i in 0..<4 {
                    let a = Double(i) / 4.0 * Double.pi * 2
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + cos(a) * (r - 16), y: c.y + sin(a) * (r - 16)))
                    p.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                    ctx.stroke(p, with: .color(Theme.gold.opacity(0.8)), lineWidth: 1.2)
                }
            }
            .rotationEffect(.degrees(spin))

            // 主环
            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(
                    AngularGradient(
                        colors: [Theme.gold, Theme.goldBright, Theme.goldDim, Theme.gold],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(22)

            Circle()
                .strokeBorder(Theme.gold.opacity(0.12), lineWidth: 0.8)
                .padding(34)

            // 地球经纬
            graticule
                .opacity(graticuleIn ? 1 : 0)
                .scaleEffect(graticuleIn ? 1 : 0.94)
                .rotationEffect(.degrees(spin * 0.35))

            // 中心核
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(pulse ? 0.30 : 0.10))
                    .frame(width: pulse ? 16 : 8, height: pulse ? 16 : 8)
                    .blur(radius: 6)
                Circle()
                    .fill(Theme.goldBright)
                    .frame(width: 4, height: 4)
                    .shadow(color: Theme.gold.opacity(0.9), radius: 8)
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LinearGradient(colors: [Theme.gold.opacity(0), Theme.gold.opacity(0.9), Theme.gold.opacity(0)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 84, height: 0.8)
                .offset(y: 14)
                .opacity(ringTrim > 0.95 ? 1 : 0)
        }
    }

    private var graticule: some View {
        Canvas { ctx, size in
            let rect = CGRect(x: 22, y: 22, width: size.width - 44, height: size.height - 44)
            let geo = GeoWorld.shared
            ctx.clip(to: Path(ellipseIn: rect))
            // 纬线
            for lat in stride(from: -60.0, through: 60.0, by: 30.0) {
                let y = rect.minY + (geo.latTop - lat) / (geo.latTop - geo.latBottom) * rect.height
                let inset = (1 - cos(lat * .pi / 180)) * rect.width * 0.5
                var p = Path()
                p.move(to: CGPoint(x: rect.minX + inset, y: y))
                p.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
                ctx.stroke(p, with: .color(Theme.gold.opacity(0.20)), lineWidth: 0.7)
            }
            // 经线（椭圆）
            let center = CGPoint(x: rect.midX, y: rect.midY)
            for k in stride(from: -2, through: 2, by: 1) {
                let rx = rect.width * 0.5 * abs(cos(Double(k) * .pi / 5.5))
                let ellipse = CGRect(x: center.x - rx, y: rect.minY, width: rx * 2, height: rect.height)
                ctx.stroke(Path(ellipseIn: ellipse), with: .color(Theme.gold.opacity(0.16)), lineWidth: 0.7)
            }
            ctx.stroke(Path(ellipseIn: rect), with: .color(Theme.gold.opacity(0.30)), lineWidth: 0.8)
        }
    }

    // MARK: 标题
    private var titleBlock: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Theme.gold.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 34, height: 0.7)
                Text("名将")
                    .font(Theme.display(46, weight: .semibold))
                    .tracking(14)
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.text, Theme.sand, Theme.gold],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .padding(.leading, 14)
                Rectangle()
                    .fill(LinearGradient(colors: [Theme.gold.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 34, height: 0.7)
            }
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 10)

            HStack(spacing: 10) {
                Text("战 争 演 变")
                    .font(Theme.title(13, weight: .medium))
                    .tracking(6)
                    .foregroundStyle(Theme.textSoft)
                Text("SIMULATOR")
                    .font(Theme.mono(8, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(Theme.gold.opacity(0.75))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        Rectangle().strokeBorder(Theme.gold.opacity(0.30), lineWidth: 0.7)
                    )
            }
            .opacity(subtitleIn ? 1 : 0)
            .offset(y: subtitleIn ? 0 : 8)

            Text("从原始聚落到轨道文明 · 让世界自己打下去")
                .font(Theme.body(10.5))
                .tracking(1.2)
                .foregroundStyle(Theme.textFaint)
                .opacity(subtitleIn ? 1 : 0)
        }
    }

    // MARK: 进度
    private var progressBlock: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.07))
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.goldDim, Theme.gold, Theme.goldBright],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(width: 148, height: 0.9)

            Text("正在载入世界图景")
                .font(Theme.label(9))
                .tracking(3)
                .foregroundStyle(Theme.textFaint)
        }
        .opacity(subtitleIn ? 1 : 0)
    }

    // MARK: 时序
    private func runSequence() {
        if reduceMotion {
            emblemIn = true; graticuleIn = true; titleIn = true; subtitleIn = true
            ringTrim = 1; progress = 1; glowIn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { finishNow() }
            return
        }

        withAnimation(Motion.slow) { emblemIn = true }
        withAnimation(.easeOut(duration: 1.4)) { glowIn = true }
        withAnimation(.linear(duration: 26).repeatForever(autoreverses: false)) { spin = 360 }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulse = true }

        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.15).delay(0.10)) { ringTrim = 1 }
        withAnimation(.easeOut(duration: 0.9).delay(0.45)) { graticuleIn = true }
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.7).delay(0.62)) { titleIn = true }
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.7).delay(0.78)) { subtitleIn = true }
        withAnimation(.easeInOut(duration: 2.05).delay(0.35)) { progress = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) {
            guard !leaving else { return }
            finishNow()
        }
    }

    private func finishNow() {
        guard !leaving else { return }
        leaving = true
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.55)) {
            onFinish()
        }
    }
}
