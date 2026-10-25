import SwiftUI
import UIKit

// MARK: - Motion
// 四档时长：120 / 200 / 320 / 600；只用 transform 与 opacity；位移 ≤ 16pt
enum Motion {
    static let tap      = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.12)
    static let quick    = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.20)
    static let standard = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.32)
    static let enter    = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.52)
    static let slow     = Animation.timingCurve(0.22, 1, 0.3, 1, duration: 0.60)
    static let spring   = Animation.spring(response: 0.42, dampingFraction: 0.84)
    static let softSpring = Animation.spring(response: 0.58, dampingFraction: 0.92)
    static let exit     = Animation.timingCurve(0.4, 0, 1, 1, duration: 0.18)

    static func stagger(_ index: Int, step: Double = 0.055) -> Animation {
        enter.delay(Double(index) * step)
    }
}

// MARK: - Staggered entrance
struct RiseIn: ViewModifier {
    var index: Int = 0
    var distance: CGFloat = 12
    var enabled: Bool = true
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || !enabled ? 1 : 0)
            .offset(y: shown || !enabled ? 0 : distance)
            .onAppear {
                guard enabled else { return }
                withAnimation(Motion.stagger(index)) { shown = true }
            }
    }
}

extension View {
    func riseIn(_ index: Int, distance: CGFloat = 12, enabled: Bool = true) -> some View {
        modifier(RiseIn(index: index, distance: distance, enabled: enabled))
    }
}

// MARK: - Press feedback
struct Pressable: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

// MARK: - Haptics
enum Haptics {
    static func tap() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare(); g.impactOccurred(intensity: 0.6)
    }
    static func select() {
        let g = UISelectionFeedbackGenerator()
        g.prepare(); g.selectionChanged()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func heavy() {
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.prepare(); g.impactOccurred(intensity: 0.9)
    }
}

// MARK: - Breathing glow (map markers / live badges)
struct Breathing: ViewModifier {
    var min: Double = 0.35
    var max: Double = 1.0
    var duration: Double = 2.4
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? max : min)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

extension View {
    func breathing(min: Double = 0.35, max: Double = 1.0, duration: Double = 2.4) -> some View {
        modifier(Breathing(min: min, max: max, duration: duration))
    }
}
