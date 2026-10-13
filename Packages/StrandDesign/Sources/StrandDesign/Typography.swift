import SwiftUI
import CoreText

// MARK: - Noor Typography
//
// One human, clean face everywhere: Inter (SIL OFL, bundled as a variable font in Resources/Fonts).
// Text styles scale with Dynamic Type. Numbers use Inter's tabular figures so live values never
// reflow; big scores are semibold with tight tracking. SF Mono stays reserved for logs.
// If the font ever fails to register, `Font.custom` falls back to the system face, so nothing breaks.

/// Registers the bundled Inter variable font for this process (app, widgets, watch). Idempotent.
public enum NoorFonts {
    public static let family = "Inter"

    private static let registered: Bool = {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "Inter", withExtension: "ttf")
                ?? bundle.url(forResource: "Inter", withExtension: "ttf", subdirectory: "Fonts") else { return false }
        var error: Unmanaged<CFError>?
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            || error.map { CFErrorGetCode($0.takeRetainedValue()) == CTFontManagerError.alreadyRegistered.rawValue } ?? false
    }()

    /// Call once early (it is also called lazily by every `StrandFont` accessor).
    public static func register() { _ = registered }
}

public enum StrandFont {

    // MARK: Family

    /// Inter at a fixed size (numbers, scores, chrome that must not reflow with Dynamic Type).
    static func inter(_ size: CGFloat, weight: Font.Weight) -> Font {
        NoorFonts.register()
        return Font.custom(NoorFonts.family, fixedSize: size).weight(weight)
    }

    /// Inter that scales with Dynamic Type relative to a system text style.
    static func inter(_ size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) -> Font {
        NoorFonts.register()
        return Font.custom(NoorFonts.family, size: size, relativeTo: style).weight(weight)
    }

    // Kept under its upstream name so every existing call site picks up Inter without edits.
    private static func roundedSystem(_ size: CGFloat, weight: Font.Weight) -> Font {
        inter(size, weight: weight)
    }

    // MARK: Scale

    /// Display 64–80 — the big score number. Semibold with tight tracking, tabular digits.
    public static func display(_ size: CGFloat = 72) -> Font {
        roundedSystem(size, weight: .semibold).monospacedDigit()
    }

    /// The tight tracking for big display numbers (≈ -0.035em). Apply alongside `display(_:)`.
    public static func displayTracking(_ size: CGFloat = 72) -> CGFloat {
        -size * 0.035
    }

    /// The house numeral at an arbitrary size/weight. Tabular so live values align.
    public static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        roundedSystem(size, weight: weight).monospacedDigit()
    }

    /// Title1 28 / Bold. Scales with Dynamic Type.
    public static let title1 = inter(28, weight: .bold, relativeTo: .title)

    /// Title2 22 / Semibold. Scales with Dynamic Type.
    public static let title2 = inter(22, weight: .semibold, relativeTo: .title2)

    /// Headline 17 / Semibold. Scales with Dynamic Type.
    public static let headline = inter(17, weight: .semibold, relativeTo: .headline)

    /// Body 16 / Regular. Scales with Dynamic Type.
    public static let body = inter(16, weight: .regular, relativeTo: .body)

    /// Subhead 14. Scales with Dynamic Type.
    public static let subhead = inter(14, weight: .regular, relativeTo: .subheadline)

    /// Caption 12. Scales with Dynamic Type.
    public static let caption = inter(12, weight: .regular, relativeTo: .caption)

    /// Footnote 13. Scales with Dynamic Type.
    public static let footnote = inter(13, weight: .regular, relativeTo: .footnote)

    /// Overline 11 / Semibold, wide tracking (`overlineTracking`). Sparing ALL-CAPS labels.
    /// Also the face for compact status copy in constrained chrome, used there without the tracking.
    public static let overline = inter(11, weight: .semibold, relativeTo: .caption2)

    /// `overline` at a custom point size (still scales with Dynamic Type relative to `.caption2`).
    public static func overlineScaled(_ size: CGFloat) -> Font {
        inter(size, weight: .semibold, relativeTo: .caption2)
    }

    /// Mono 13 (SF Mono) — raw / log views. Tabular by nature.
    public static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)

    // MARK: Numeric variants (tabular digits)

    /// A numeric style at an arbitrary size/weight, for live values. This is the tile/value numeral.
    public static func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        roundedSystem(size, weight: weight).monospacedDigit()
    }

    /// Body number — inline live values that align; scales with Dynamic Type like `body`.
    public static let bodyNumber = inter(16, weight: .medium, relativeTo: .body).monospacedDigit()

    /// Caption number — small live values (sparklines, chips). Scales with Dynamic Type.
    public static let captionNumber = inter(12, weight: .medium, relativeTo: .caption).monospacedDigit()

    /// Mono at an arbitrary size.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// The recommended tracking for overline text (ALL-CAPS labels, ≈ 0.1em).
    public static let overlineTracking: CGFloat = 1.1
}

// MARK: - Text helpers

public extension Text {
    /// Style as an overline label: ALL-CAPS, bold, +1.4 tracking, tertiary text.
    func strandOverline() -> some View {
        self.font(StrandFont.overline)
            .tracking(StrandFont.overlineTracking)
            .textCase(.uppercase)
            .foregroundStyle(StrandPalette.textSecondary)
    }
}

public extension View {
    /// Convenience: an overline-styled label string.
    static func strandOverline(_ string: String) -> some View {
        Text(string).strandOverline()
    }
}

#if DEBUG
#Preview("Typography") {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            Text("88").font(StrandFont.display(72)).tracking(StrandFont.displayTracking(72)).foregroundStyle(StrandPalette.textPrimary)
            Text("Title 1 / Bold 28").font(StrandFont.title1).foregroundStyle(StrandPalette.textPrimary)
            Text("Title 2 / Semibold 22").font(StrandFont.title2).foregroundStyle(StrandPalette.textPrimary)
            Text("Headline / Semibold 17").font(StrandFont.headline).foregroundStyle(StrandPalette.textPrimary)
            Text("Body / Regular 15 — the thread of you, read in full.")
                .font(StrandFont.body).foregroundStyle(StrandPalette.textPrimary)
            Text("Subhead 13").font(StrandFont.subhead).foregroundStyle(StrandPalette.textSecondary)
            Text("Caption 12").font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)
            Text("Footnote 11").font(StrandFont.footnote).foregroundStyle(StrandPalette.textTertiary)
            Text("Overline").strandOverline()
            Text("0xAA 41 00 1c crc32=f3a1  mono 13").font(StrandFont.mono).foregroundStyle(StrandPalette.textSecondary)
            HStack(spacing: 4) {
                Text("HRV").font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)
                Text("62").font(StrandFont.bodyNumber).foregroundStyle(StrandPalette.textPrimary)
                Text("ms").font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(width: 520, height: 620)
    .background(StrandPalette.surfaceBase)
    .preferredColorScheme(.dark)
}
#endif
