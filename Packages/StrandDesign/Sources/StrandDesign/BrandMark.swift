import SwiftUI

// MARK: - BrandMark — the Noor logo mark (interlocking neon rings)
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

    // Noor mark: the "oo" of noor as two interlocking neon rings (green → aqua → blue, and
    // violet → pink) on a black disc. Mirrors the app icon (Tools/noor/make_icon.swift).
    private var ringRadius: CGFloat { size * 0.205 }
    private var ringWidth: CGFloat { size * 0.075 }
    private var offset: CGFloat { size * 0.13 }
    private var rimWidth: CGFloat { max(1, size * 0.008) }

    private static let leftStops = Gradient(colors: [NoopVisualStyle.neonGreen, NoopVisualStyle.neonAqua, NoopVisualStyle.neonBlue])
    private static let rightStops = Gradient(colors: [Color(hex: "#A24BFF"), NoopVisualStyle.neonPink])

    public var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "#161616"), Color(hex: "#000000")],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(StrandPalette.hairline, lineWidth: rimWidth))
            ring(Self.rightStops, glow: NoopVisualStyle.neonPink).offset(x: offset)
            ring(Self.leftStops, glow: NoopVisualStyle.neonAqua).offset(x: -offset)
            // Lower crossing: the pink ring passes over the green one so the rings read as linked.
            ring(Self.rightStops, glow: .clear)
                .offset(x: offset)
                .mask(Circle().frame(width: ringWidth * 2.2, height: ringWidth * 2.2)
                        .offset(y: (ringRadius * ringRadius - offset * offset).squareRoot()))
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Noor"))
        .accessibilityAddTraits(.isImage)
    }

    private func ring(_ gradient: Gradient, glow: Color) -> some View {
        Circle()
            .stroke(LinearGradient(gradient: gradient, startPoint: .bottomLeading, endPoint: .topTrailing),
                    lineWidth: ringWidth)
            .frame(width: ringRadius * 2, height: ringRadius * 2)
            .shadow(color: glow.opacity(0.7), radius: size * 0.04)
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
