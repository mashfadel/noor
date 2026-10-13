import SwiftUI

/// Noor's healthspan orb: an organic, never-quite-round shape whose outline slowly morphs, a dark heart
/// with light gathering at the rim, a soft bloom, and specks of light streaming from the centre out to
/// the edge. Content (the age) is centred on top. Static under Reduce Motion.
public struct NoorBlobOrb<Content: View>: View {
    public var diameter: CGFloat
    public var tint: Color
    public var accent: Color
    @ViewBuilder public var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(diameter: CGFloat, tint: Color, accent: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.diameter = diameter
        self.tint = tint
        self.accent = accent ?? tint
        self.content = content
    }

    public var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
                let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                Canvas { gc, size in
                    BlobRenderer.draw(gc, size: size, t: t, tint: tint, accent: accent)
                }
            }
            .frame(width: diameter * 1.35, height: diameter * 1.35)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            content()
        }
        .frame(width: diameter, height: diameter)
    }
}

enum BlobRenderer {
    /// Outline radius at angle θ and time t: a base circle wobbled by three slow, out-of-phase harmonics.
    static func radius(_ theta: Double, t: Double, base: Double) -> Double {
        let w = 0.042 * sin(2 * theta + t * 0.55 + 0.4)
            + 0.030 * sin(3 * theta - t * 0.42 + 1.7)
            + 0.018 * sin(5 * theta + t * 0.73 + 2.9)
            + 0.010 * sin(7 * theta - t * 0.9 + 0.8)
        return base * (1 + w)
    }

    static func blobPath(center: CGPoint, base: Double, t: Double) -> Path {
        var p = Path()
        let n = 96
        for i in 0...n {
            let th = Double(i) / Double(n) * 2 * .pi
            let r = radius(th, t: t, base: base)
            let pt = CGPoint(x: center.x + cos(th) * r, y: center.y + sin(th) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// Deterministic particles: angle, speed (cycles/s), phase, size, colour pick.
    static let particles: [(a: Double, s: Double, p: Double, z: Double, c: Int)] = {
        var seed: UInt64 = 0xC0FFEE1234567
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<110).map { _ in (a: next() * 2 * .pi, s: 0.05 + next() * 0.12, p: next(), z: 0.6 + next() * 1.4,
                                     c: Int(next() * 3)) }
    }()

    static func draw(_ gc: GraphicsContext, size: CGSize, t: Double, tint: Color, accent: Color) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let base = Double(min(size.width, size.height)) / 1.35 / 2
        let blob = blobPath(center: center, base: base, t: t)

        // Bloom behind the shape.
        var glow = gc
        glow.addFilter(.blur(radius: base * 0.16))
        glow.fill(blob, with: .color(tint.opacity(0.45)))

        // Body: a dark heart with light gathering toward the rim.
        gc.fill(blob, with: .radialGradient(Gradient(stops: [
            .init(color: Color(red: 0.012, green: 0.012, blue: 0.012), location: 0),
            .init(color: Color(red: 0.02, green: 0.02, blue: 0.02), location: 0.5),
            .init(color: accent.opacity(0.35), location: 0.8),
            .init(color: tint.opacity(0.95), location: 1.0),
        ]), center: center, startRadius: 0, endRadius: base * 1.04))

        // Particles streaming outward, clipped to the shape, brightest mid-flight.
        var inner = gc
        inner.clip(to: blob)
        for (i, pt) in particles.enumerated() {
            let u = (pt.p + t * pt.s).truncatingRemainder(dividingBy: 1)
            let r = base * (0.12 + 0.92 * pow(u, 0.75))
            let a = pt.a + 0.15 * sin(t * 0.3 + Double(i))
            let x = center.x + cos(a) * r, y = center.y + sin(a) * r
            let d = pt.z * base / 120 * (0.6 + 0.8 * u)   // specks swell as they reach the rim
            let alpha = sin(.pi * u) * 0.9
            let color: Color = pt.c == 0 ? .white : (pt.c == 1 ? tint : accent)
            inner.fill(Path(ellipseIn: CGRect(x: x - d, y: y - d, width: d * 2, height: d * 2)),
                       with: .color(color.opacity(alpha)))
        }

        // Rim light.
        gc.stroke(blob, with: .color(tint.opacity(0.9)), lineWidth: max(1, base * 0.012))
    }
}
