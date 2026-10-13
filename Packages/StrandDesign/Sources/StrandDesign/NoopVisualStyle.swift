import SwiftUI

// MARK: - NOOP visual foundation
//
// These tokens describe the visual treatment used by NOOP's existing views. They deliberately
// contain no navigation, state, or domain semantics: screens keep their current hierarchy and data
// bindings, while cards, gauges, typography, and chrome share one maintainable source of truth.

public enum NoopVisualStyle {
    // Noor: pure-neutral monochrome surfaces; the "mint" tokens carry the single neon-volt accent.
    public static let canvas = Color(light: "#F4F4F4", dark: "#0B0B0B")
    public static let surface = Color(light: "#FFFFFF", dark: "#161616")
    public static let surfaceTop = Color(light: "#FFFFFF", dark: "#1B1B1B")
    public static let surfaceBottom = Color(light: "#F6F6F6", dark: "#131313")
    public static let inset = Color(light: "#EBEBEB", dark: "#101010")

    public static let border = Color(light: "#DCDCDC", dark: "#2A2A2A")
    public static let borderHighlight = Color(light: "#FFFFFF", dark: "#383838")
    public static let divider = Color(light: "#E6E6E6", dark: "#262626")

    public static let primaryText = Color(light: "#0F0F0F", dark: "#F5F5F5")
    public static let secondaryText = Color(light: "#555555", dark: "#BDBDBD")
    public static let tertiaryText = Color(light: "#808080", dark: "#7A7A7A")

    public static let mint = Color(light: "#008C7A", dark: "#1AF5D0")
    public static let mintDeep = Color(light: "#006B5E", dark: "#00C2A8")
    public static let mintGlow = Color(light: "#00A894", dark: "#7DFFE6")

    // Noor brand neons: the accent (aqua) sits between green and blue; pink is the counter-accent.
    public static let neonGreen = Color(hex: "#3DFF8F")
    public static let neonAqua = Color(hex: "#1AF5D0")
    public static let neonBlue = Color(hex: "#2E8BFF")
    public static let neonPink = Color(hex: "#FF3EA5")
    /// The Noor signature sweep (logo, hero accents): green → aqua → blue.
    public static let brandGradient = Gradient(colors: [neonGreen, neonAqua, neonBlue])

    public static let cardRadius: CGFloat = 22
    public static let compactRadius: CGFloat = 16
    public static let pillRadius: CGFloat = 999
    public static let pagePadding: CGFloat = 16
    public static let cardPadding: CGFloat = 16
    public static let itemGap: CGFloat = 12
    public static let sectionGap: CGFloat = 26
}

/// Noor card tokens (graphite body + light-catching edge).
enum NoorCard {
    static let top = Color(light: "#FFFFFF", dark: "#171717")
    static let bottom = Color(light: "#FAFAFA", dark: "#0F0F0F")
    static let edgeLight = Color(light: "#00000014", dark: "#FFFFFF1F")
    static let edgeFade = Color(light: "#0000000A", dark: "#FFFFFF05")
}

/// Shared card/panel treatment: a solid surface on iOS, gradient and soft elevation elsewhere.
/// `tint` is intentionally faint so metric identity never turns the whole card into a coloured tile.
public struct NoopPanelSurface: View {
    public var tint: Color?
    public var cornerRadius: CGFloat
    public var elevated: Bool
    public var surfaceOpacity: Double
    #if !os(iOS)
    @Environment(\.colorScheme) private var scheme
    #endif

    public init(
        tint: Color? = nil,
        cornerRadius: CGFloat = NoopVisualStyle.cardRadius,
        elevated: Bool = false,
        surfaceOpacity: Double = 1
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.elevated = elevated
        self.surfaceOpacity = surfaceOpacity
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if os(iOS)
        // Noor card: a deep graphite body, a hairline that catches light along the top edge and fades
        // out, and — instead of a coloured rim — the metric's colour as a faint glow in one corner.
        // Kept to two fills + one stroke so long scrolling stacks stay cheap to composite.
        shape
            .fill(LinearGradient(colors: [NoorCard.top, NoorCard.bottom], startPoint: .top, endPoint: .bottom))
            .overlay {
                if let tint {
                    shape.fill(RadialGradient(colors: [tint.opacity(0.13), .clear],
                                              center: .topLeading, startRadius: 0, endRadius: 190))
                }
            }
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [NoorCard.edgeLight.opacity(elevated ? 1 : 0.85), NoorCard.edgeFade],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 0.75
            ))
            .opacity(surfaceOpacity)
        #else
        shape
            .fill(
                LinearGradient(
                    colors: [NoopVisualStyle.surfaceTop, NoopVisualStyle.surfaceBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                if let tint {
                    shape.fill(
                        LinearGradient(
                            colors: [tint.opacity(0.055), tint.opacity(0.012), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [NoopVisualStyle.borderHighlight.opacity(0.72), NoopVisualStyle.border.opacity(0.52)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            )
            .shadow(
                color: scheme == .dark ? .black.opacity(elevated ? 0.34 : 0.18) : .black.opacity(0.10),
                radius: elevated ? 18 : 9,
                x: 0,
                y: elevated ? 10 : 5
            )
            .opacity(surfaceOpacity)
        #endif
    }
}

/// Shared edge-to-edge chrome for sheet and split-view headers. Unlike a card it has no
/// rounded outline or elevation, but it uses the same top-lit surface ramp and divider token.
public struct NoopChromeSurface: View {
    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [NoopVisualStyle.surfaceTop, NoopVisualStyle.surfaceBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NoopVisualStyle.divider)
                .frame(height: 0.5)
        }
    }
}

public extension View {
    func noopPanel(
        tint: Color? = nil,
        cornerRadius: CGFloat = NoopVisualStyle.cardRadius,
        elevated: Bool = false,
        surfaceOpacity: Double = 1
    ) -> some View {
        background {
            NoopPanelSurface(
                tint: tint,
                cornerRadius: cornerRadius,
                elevated: elevated,
                surfaceOpacity: surfaceOpacity
            )
        }
    }
}
