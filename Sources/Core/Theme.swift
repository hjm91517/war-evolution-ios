import SwiftUI
import UIKit

// MARK: - Design tokens
//
// 锚点：冷静的战略指挥室 / 参考 Linear 的克制 + Bloomberg 的信息密度 + 电影级地图质感
// 色温：深墨青黑 + 赤金强调，中性色带 4° 青偏；不做紫蓝渐变，不做玻璃拟态模板
// 密度：中高密度，8pt 基准；圆角仅 3 档（8 / 14 / 22）
// 动效：120 / 200 / 320 / 600 四档，只用位移与不透明度，位移 ≤ 16pt

enum Theme {
    // 背景层
    static let ink        = Color(hex: 0x05080A)
    static let inkDeep    = Color(hex: 0x030506)
    static let panel      = Color(hex: 0x0C1215)
    static let panelUp    = Color(hex: 0x111A1E)
    static let panelEdge  = Color(hex: 0x1B282D)

    // 文本层
    static let text       = Color(hex: 0xF0E8D9)
    static let textSoft   = Color(hex: 0xC6C0B4)
    static let textDim    = Color(hex: 0x8D9694)
    static let textFaint  = Color(hex: 0x5E6764)

    // 强调层
    static let gold       = Color(hex: 0xD3A75F)
    static let goldBright = Color(hex: 0xF4D99F)
    static let goldDim    = Color(hex: 0x8A6E3E)
    static let ember      = Color(hex: 0xC25B3D)
    static let emberDeep   = Color(hex: 0x8E3D27)
    static let teal       = Color(hex: 0x4F938E)
    static let sand       = Color(hex: 0xD8C9A9)
    static let ocean      = Color(hex: 0x0A1418)
    static let oceanDeep  = Color(hex: 0x060D10)
    static let danger     = Color(hex: 0xCE5B45)
    static let success    = Color(hex: 0x6FA98C)

    // 圆角：仅三档
    static let rSmall: CGFloat = 8
    static let rMid: CGFloat = 14
    static let rLarge: CGFloat = 22

    // 字体
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func title(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    // 自然系旗色：全部为低饱和中间调，能直接压在地球纹理上而不刺眼
    static let factionColors: [Color] = [
        Color(hex: 0xC0875C), // 陶金
        Color(hex: 0x93A07C), // 苔绿
        Color(hex: 0x6F8FA6), // 雾蓝
        Color(hex: 0xA47C8E), // 暮紫
        Color(hex: 0xC0A870), // 砂金
        Color(hex: 0x7FA098), // 海松
        Color(hex: 0x9E6B5A), // 赭红
        Color(hex: 0x8D88A6), // 灰紫
        Color(hex: 0xA68F6E), // 壤土
        Color(hex: 0x73899B)  // 铁蓝
    ]

    static let factionColorNames = ["陶金", "苔绿", "雾蓝", "暮紫", "砂金",
                                    "海松", "赭红", "灰紫", "壤土", "铁蓝"]

    static func factionColor(_ index: Int) -> Color {
        factionColors[((index % factionColors.count) + factionColors.count) % factionColors.count]
    }
    static func factionColorName(_ index: Int) -> String {
        factionColorNames[((index % factionColorNames.count) + factionColorNames.count) % factionColorNames.count]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

extension View {
    func hairlineBorder(_ color: Color = Color.white.opacity(0.08),
                        radius: CGFloat = Theme.rMid,
                        lineWidth: CGFloat = 1) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: lineWidth)
        )
    }
}

// MARK: - Double layer shadow helper
struct PanelShadow: ViewModifier {
    var strong: Bool = false
    func body(content: Content) -> some View {
        content
            .shadow(color: Theme.inkDeep.opacity(0.55), radius: strong ? 28 : 16, x: 0, y: strong ? 14 : 8)
            .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func panelShadow(strong: Bool = false) -> some View {
        modifier(PanelShadow(strong: strong))
    }
}

// MARK: - Number formatting
enum Fmt {
    static func compact(_ value: Double) -> String {
        let v = max(0, value)
        if v >= 100_000_000 { return String(format: "%.1f亿", v / 100_000_000) }
        if v >= 10_000 { return String(format: "%.1f万", v / 10_000) }
        if v >= 1_000 { return String(format: "%.1f千", v / 1_000) }
        if v >= 100 { return String(format: "%.0f", v) }
        return String(format: "%.1f", v)
    }
    static func int(_ value: Double) -> String {
        String(format: "%.0f", max(0, value))
    }
    static func year(_ tick: Int) -> String {
        "第 \(tick) 年"
    }
    static func percent(_ v: Double) -> String {
        String(format: "%.0f%%", min(100, max(0, v * 100)))
    }
}
