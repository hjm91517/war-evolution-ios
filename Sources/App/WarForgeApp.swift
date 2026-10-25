import SwiftUI

@main
struct WarForgeApp: App {
    @StateObject private var store = WorldStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase != .active {
                        store.save()
                    }
                }
        }
    }
}

enum PreviewMode {
    static var args: [String] { ProcessInfo.processInfo.arguments }
    static var skipLaunch: Bool {
        args.contains { $0.hasPrefix("-preview") }
    }
    static var wantsEvolution: Bool { args.contains("-previewEvolve") }
    static var wantsCreate: Bool { args.contains("-previewCreate") }
    static var wantsMap: Bool { args.contains("-previewMap") }
}

struct RootView: View {
    @EnvironmentObject private var store: WorldStore
    @State private var launched = PreviewMode.skipLaunch

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            if launched {
                HomeView()
                    .transition(.opacity)
            } else {
                LaunchView {
                    launched = true
                }
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }

            if let report = store.catchUp {
                CatchUpOverlay(report: report)
                    .transition(.opacity)
                    .zIndex(10)
            }

            if let toast = store.toast {
                VStack {
                    ToastView(text: toast)
                        .padding(.top, 12)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .onAppear {
            if PreviewMode.skipLaunch { launched = true }
        }
        .animation(Motion.standard, value: store.toast)
        .animation(Motion.quick, value: store.catchUp)
        .tint(Theme.gold)
    }
}

// MARK: - 补算遮罩
struct CatchUpOverlay: View {
    var report: CatchUpReport

    var body: some View {
        ZStack {
            Theme.inkDeep.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        .frame(width: 76, height: 76)
                    Circle()
                        .trim(from: 0, to: max(0.02, report.progress))
                        .stroke(Theme.gold, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Theme.gold)
                }
                .animation(.linear(duration: 0.2), value: report.progress)

                VStack(spacing: 8) {
                    Text("时间在流逝")
                        .font(Theme.display(22))
                        .tracking(4)
                        .foregroundStyle(Theme.text)
                    Text("\(report.worldName) · 补算 \(Fmt.int(Double(report.ticks))) 年")
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.textDim)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07))
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.goldDim, Theme.goldBright],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * min(1, report.progress))
                    }
                }
                .frame(width: 220, height: 2)

                Text("App 关闭期间，世界仍按真实时间自行演进")
                    .font(Theme.label(9))
                    .tracking(1.6)
                    .foregroundStyle(Theme.textFaint)
            }
        }
    }
}
