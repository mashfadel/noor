import SwiftUI

/// Noor's hero instrument: a dark sphere whose rim glows in the score's colour, with drifting specks of
/// light inside and the content (usually the score) centred. Breathes slowly like the Noor orb logo.
/// Pure presentation — callers supply the number/caption as content.
public struct NoorScoreOrb<Content: View>: View {
    public var diameter: CGFloat
    public var tint: Color
    /// A second hue the rim drifts toward (e.g. violet for Sleep's pink).
    public var accent: Color
    /// 0…1 — how lit the rim is (e.g. score / 100). Nil reads as a dim, unscored orb.
    public var intensity: Double?
    @ViewBuilder public var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inhale = false

    public init(diameter: CGFloat, tint: Color, accent: Color? = nil, intensity: Double?,
                @ViewBuilder content: @escaping () -> Content) {
        self.diameter = diameter
        self.tint = tint
        self.accent = accent ?? tint
        self.intensity = intensity
        self.content = content
    }

    private var lit: Double { 0.35 + 0.65 * max(0, min(1, intensity ?? 0.15)) }

    public var body: some View {
        ZStack {
            // Halo spilling into the dark.
            Circle()
                .fill(RadialGradient(colors: [tint.opacity(0.32 * lit), accent.opacity(0.12 * lit), .clear],
                                     center: .center, startRadius: diameter * 0.35, endRadius: diameter * 0.85))
                .frame(width: diameter * 1.7, height: diameter * 1.7)
                .blur(radius: 10)

            // The sphere: dark heart, light gathering at the rim.
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: Color(hex: "#030303"), location: 0.0),
                    .init(color: Color(hex: "#050505"), location: 0.55),
                    .init(color: accent.opacity(0.28 * lit), location: 0.82),
                    .init(color: tint.opacity(0.85 * lit), location: 0.98),
                    .init(color: tint.opacity(0.0), location: 1.0),
                ], center: .center, startRadius: 0, endRadius: diameter / 2))
                .overlay(
                    Circle().strokeBorder(
                        AngularGradient(colors: [tint, accent, tint.opacity(0.6), accent, tint], center: .center),
                        lineWidth: max(1.5, diameter * 0.012))
                        .opacity(0.55 + 0.45 * lit)
                        .blur(radius: 0.6)
                )
                .overlay(OrbSpecks(diameter: diameter, tint: tint, accent: accent, lit: lit, drift: inhale))
                .frame(width: diameter, height: diameter)
                .shadow(color: tint.opacity(0.45 * lit), radius: diameter * 0.08)

            content()
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(reduceMotion ? 1 : (inhale ? 1.02 : 0.99))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { inhale = true }
        }
    }
}

/// Specks of light inside the orb, denser toward the rim, drifting a touch with each breath.
private struct OrbSpecks: View {
    let diameter: CGFloat
    let tint: Color
    let accent: Color
    let lit: Double
    let drift: Bool

    /// Deterministic positions (a fixed seed), so the field never jumps between renders.
    private static let specks: [(r: Double, a: Double, s: Double, o: Double)] = {
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<70).map { _ in
            (r: 0.25 + 0.72 * pow(next(), 0.6), a: next() * 2 * .pi, s: 0.5 + next() * 1.6, o: 0.25 + next() * 0.75)
        }
    }()

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            for (i, p) in Self.specks.enumerated() {
                let a = p.a + (drift ? 0.06 : 0)
                let r = p.r * diameter / 2 * 0.95
                let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                let d = p.s * diameter / 260
                let color = i % 3 == 0 ? accent : (i % 3 == 1 ? tint : .white)
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - d, y: pt.y - d, width: d * 2, height: d * 2)),
                         with: .color(color.opacity(p.o * lit)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
