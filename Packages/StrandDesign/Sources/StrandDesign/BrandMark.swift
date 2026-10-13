import SwiftUI

// MARK: - BrandMark — the Noor logo mark (light rising: three score arcs)
//
// (Upstream NOOP notes below describe the original Titanium & Gold mark this replaced.)
//
// The app's identity glyph, rendered natively for use as a hero on onboarding,
// "about", and empty states. Per the design handoff ("Engraved" app-icon
// direction + the brand glyph spec):
//
//   • a circular DEEP-NAVY tile (Circle filled with the navy ramp, a faint top
//     sheen, and a 1px hairline rim), over which sits
//   • an OPEN GOLD recovery ring — an ~80% arc starting at 12 o'clock (-90°) and
//     sweeping clockwise, stroked with the gold ramp and round-capped (a THICK
//     stroke to match the app icon), and
//   • a solid GOLD CORE DOT centred ("on-device core").
//
// Gold-on-navy, matching the app icon (the maintainer's brand direction, 2026-06-15).
//
// It reads as the "O" in NOOP and as a small echo of the hero recovery ring.
// CLEAN and flat by design: no bloom, no shadow, no glow — the titanium does the
// depth via its gradient + sheen, the gold ring does the accent. Everything is
// driven off a single `size`, so the mark stays crisp from a 28pt list avatar up
// to a 120pt onboarding hero.

public struct BrandMark: View {

    /// Edge length of the square mark; everything scales from this.
    public var size: CGFloat

    public init(size: CGFloat = 120) {
        self.size = size
    }

    // Noor mark: light rising over a horizon — three concentric arcs filling like dials (Sleep
    // violet→pink, Recovery green, Strain blue→cyan) around a white-hot point of light. Mirrors the
    // app icon (Tools/noor/make_icon.swift).
    private struct Arc { let radius: CGFloat; let fill: CGFloat; let colors: [Color]; let glow: Color }
    private var arcs: [Arc] {[
        Arc(radius: 0.344, fill: 1.00, colors: [Color(hex: "#A24BFF"), NoopVisualStyle.neonPink], glow: NoopVisualStyle.neonPink),
        Arc(radius: 0.256, fill: 0.78, colors: [Color(hex: "#00C46A"), NoopVisualStyle.neonGreen], glow: NoopVisualStyle.neonGreen),
        Arc(radius: 0.168, fill: 0.56, colors: [Color(hex: "#2E6BFF"), Color(hex: "#33E1FF")], glow: Color(hex: "#33E1FF")),
    ]}
    private var lineWidth: CGFloat { size * 0.053 }
    private var rimWidth: CGFloat { max(1, size * 0.008) }

    public var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "#161616"), Color(hex: "#000000")],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(StrandPalette.hairline, lineWidth: rimWidth))
            Canvas { ctx, sz in
                let center = CGPoint(x: sz.width / 2, y: sz.height * 0.62)
                for arc in arcs {
                    var path = Path()
                    path.addArc(center: center, radius: arc.radius * sz.width, startAngle: .degrees(180),
                                endAngle: .degrees(180 + 180 * arc.fill), clockwise: false)
                    let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    var glow = ctx
                    glow.addFilter(.blur(radius: lineWidth * 0.8))
                    glow.stroke(path, with: .color(arc.glow.opacity(0.6)), style: style)
                    ctx.stroke(path, with: .linearGradient(Gradient(colors: arc.colors),
                        startPoint: CGPoint(x: center.x - arc.radius * sz.width, y: center.y),
                        endPoint: CGPoint(x: center.x + arc.radius * sz.width, y: center.y)), style: style)
                }
                let core = size * 0.066
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - core * 2.2, y: center.y - core * 2.2,
                                               width: core * 4.4, height: core * 4.4)),
                         with: .radialGradient(Gradient(colors: [.white.opacity(0.55), NoopVisualStyle.neonAqua.opacity(0)]),
                                               center: center, startRadius: 0, endRadius: core * 2.2))
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - core / 2, y: center.y - core / 2, width: core, height: core)),
                         with: .color(.white))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Noor"))
        .accessibilityAddTraits(.isImage)
    }
}

#if DEBUG
#Preview("BrandMark — sizes") {
    VStack(spacing: 40) {
        BrandMark(size: 120)
        HStack(spacing: 28) {
            BrandMark(size: 72)
            BrandMark(size: 44)
            BrandMark(size: 28)
        }
    }
    .padding(48)
    .frame(width: 420, height: 460)
    .background(StrandPalette.surfaceBase)
    .preferredColorScheme(.dark)
}
#endif
