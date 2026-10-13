import SwiftUI

// MARK: - BrandMark — the Noor logo mark (the living orb of light)
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

    /// Breathe slowly (a living light). Off for tiny or static uses.
    public var breathing: Bool = true

    public init(size: CGFloat = 120, breathing: Bool) {
        self.size = size
        self.breathing = breathing
    }

    public var body: some View {
        NoorOrb(size: size, breathing: breathing)
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Noor"))
            .accessibilityAddTraits(.isImage)
    }
}

/// The Noor orb: a living sphere of light with the brand aurora (green, aqua, blue, pink, violet) inside,
/// a soft halo, a glint and a rim light. Mirrors the app icon (Tools/noor/make_icon.swift orb).
public struct NoorOrb: View {
    public var size: CGFloat
    public var breathing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inhale = false

    public init(size: CGFloat, breathing: Bool = true) {
        self.size = size
        self.breathing = breathing
    }

    private func blob(_ color: Color, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ a: Double) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(a), color.opacity(a * 0.45), color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: size * r))
            .frame(width: size * r * 2, height: size * r * 2)
            .offset(x: size * x, y: size * y)
            .blendMode(.screen)
    }

    public var body: some View {
        let d = size * 0.62   // sphere diameter inside the tile
        ZStack {
            // Halo spilling into the dark.
            blob(NoopVisualStyle.neonGreen, -0.10, -0.07, 0.52, 0.30)
            blob(NoopVisualStyle.neonBlue, 0.13, 0.04, 0.50, 0.30)
            blob(NoopVisualStyle.neonPink, -0.06, 0.15, 0.48, 0.28)
            // The aurora, clipped to the sphere.
            ZStack {
                Color(hex: "#05060A")
                blob(NoopVisualStyle.neonGreen, -0.16, -0.14, 0.35, 1.0)
                blob(NoopVisualStyle.neonAqua, 0.02, -0.22, 0.25, 0.75)
                blob(NoopVisualStyle.neonBlue, 0.20, 0.03, 0.33, 1.0)
                blob(NoopVisualStyle.neonPink, -0.11, 0.20, 0.32, 1.0)
                blob(Color(hex: "#8A4BFF"), 0.15, 0.24, 0.23, 0.85)
                blob(NoopVisualStyle.neonAqua, 0.01, -0.02, 0.22, 0.8)
                blob(.white, -0.01, -0.03, 0.12, 0.35)
                // Depth toward the rim, then a glint.
                Circle().fill(RadialGradient(colors: [.clear, .black.opacity(0.55)], center: UnitPoint(x: 0.44, y: 0.42),
                                             startRadius: d * 0.25, endRadius: d * 0.62))
                Circle().fill(RadialGradient(colors: [.white.opacity(0.7), .white.opacity(0)], center: .center,
                                             startRadius: 0, endRadius: size * 0.062))
                    .frame(width: size * 0.13, height: size * 0.13)
                    .offset(x: -size * 0.127, y: -size * 0.176)
            }
            .frame(width: d, height: d)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: max(0.5, size * 0.003)))
        }
        .frame(width: size, height: size)
        .scaleEffect(breathing && !reduceMotion ? (inhale ? 1.035 : 0.985) : 1)
        .brightness(breathing && !reduceMotion ? (inhale ? 0.04 : 0) : 0)
        .onAppear {
            guard breathing, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { inhale = true }
        }
        .drawingGroup()
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
