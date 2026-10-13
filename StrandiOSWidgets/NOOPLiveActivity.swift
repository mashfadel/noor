import WidgetKit
import SwiftUI
import ActivityKit
import StrandDesign

/// Live Activity for an active live-HR session — shown on the Lock Screen and in the Dynamic Island.
struct NOOPLiveActivity: Widget {
    /// The heart rate to draw: none once iOS has marked the banner stale. Each push is fresh for 30 s
    /// (`LiveActivityController.staleAfter`) and NOOP re-pushes a steady number well inside that, so a stale banner
    /// means the readings stopped — the strap off the wrist, or out of reach — even while NOOP itself is asleep and
    /// cannot say so: iOS redraws the banner at the stale date on its own.
    static func shownBpm(_ context: ActivityViewContext<NOOPActivityAttributes>) -> Int? {
        context.isStale ? nil : context.state.bpm
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NOOPActivityAttributes.self) { context in
            // Lock Screen / banner — Noor: glowing heart + big BPM, mini neon rings for the day's scores.
            let bpm = Self.shownBpm(context)
            HStack(alignment: .center, spacing: 14) {
                NoorPulseHeart(live: bpm != nil, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "NOOR · LIVE")
                        .font(StrandFont.rounded(10, weight: .semibold)).tracking(1.4)
                        .foregroundStyle(Color.white.opacity(0.5))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(bpm.map(String.init) ?? "–")
                            .font(StrandFont.rounded(40, weight: .semibold))
                            .contentTransition(.numericText())
                        Text("BPM").font(StrandFont.rounded(12, weight: .semibold)).tracking(1.2)
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                HStack(spacing: 12) {
                    if let r = context.state.recovery {
                        NoorMiniRing(value: "\(r)", unit: "%", fraction: Double(r) / 100,
                                     color: StrandPalette.recoveryColor(Double(r)), label: "REC")
                    }
                    if let e = context.state.effort {
                        NoorMiniRing(value: Self.strain(e), unit: nil, fraction: Double(e) / 100,
                                     color: NoopVisualStyle.neonBlue, label: "STRAIN")
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .activityBackgroundTint(Color.black.opacity(0.92))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let bpm = Self.shownBpm(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        NoorPulseHeart(live: bpm != nil, size: 20)
                        Text(bpm.map(String.init) ?? "–")
                            .font(StrandFont.rounded(34, weight: .semibold))
                            .contentTransition(.numericText())
                        Text("BPM").font(StrandFont.rounded(11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 10) {
                        if let r = context.state.recovery {
                            NoorMiniRing(value: "\(r)", unit: "%", fraction: Double(r) / 100,
                                         color: StrandPalette.recoveryColor(Double(r)), label: "REC", diameter: 38)
                        }
                        if let e = context.state.effort {
                            NoorMiniRing(value: Self.strain(e), unit: nil, fraction: Double(e) / 100,
                                         color: NoopVisualStyle.neonBlue, label: "STRAIN", diameter: 38)
                        }
                    }
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.title)
                        .font(StrandFont.rounded(11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                NoorPulseHeart(live: bpm != nil, size: 14)
            } compactTrailing: {
                Text(bpm.map(String.init) ?? "–")
                    .font(StrandFont.rounded(15, weight: .semibold))
                    .foregroundStyle(NoopVisualStyle.neonPink)
                    .contentTransition(.numericText())
            } minimal: {
                NoorPulseHeart(live: bpm != nil, size: 14)
            }
            .keylineTint(NoopVisualStyle.neonPink)
        }
    }

    /// Strain on WHOOP's 0–21 axis (the banner carries the 0–100 value).
    static func strain(_ effort: Int) -> String {
        String(format: "%.1f", Double(effort) * 0.21)
    }
}

/// A neon heart that pulses while readings arrive and dims when they stop.
struct NoorPulseHeart: View {
    let live: Bool
    let size: CGFloat
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(live ? NoopVisualStyle.neonPink : Color.white.opacity(0.3))
            .shadow(color: live ? NoopVisualStyle.neonPink.opacity(0.8) : .clear, radius: size * 0.3)
            .symbolEffect(.pulse, options: .repeating, isActive: live)
    }
}

/// A small neon progress ring with the value inside and a tracked caption under it.
struct NoorMiniRing: View {
    let value: String
    let unit: String?
    let fraction: Double
    let color: Color
    let label: String
    var diameter: CGFloat = 44
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: diameter * 0.1)
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, fraction)))
                    .stroke(color, style: StrokeStyle(lineWidth: diameter * 0.1, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.7), radius: 3)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(value).font(StrandFont.rounded(diameter * 0.3, weight: .semibold))
                    if let unit { Text(unit).font(StrandFont.rounded(diameter * 0.17, weight: .semibold)).opacity(0.6) }
                }
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(diameter * 0.14)
            }
            .frame(width: diameter, height: diameter)
            Text(label).font(StrandFont.rounded(8, weight: .semibold)).tracking(1)
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .fixedSize()
    }
}

/// Lock-Screen banner stat column (label over value). File-scope because the `ActivityConfiguration`
/// content closure isn't a method of `NOOPLiveActivity`.
///
/// #759 - the label and value are CENTRE-aligned so each value sits directly under its own label. The
/// old `.trailing` alignment right-pinned both to the column's edge: when the value was narrower than
/// the label (e.g. "12" under "Effort") it drifted to the label's right edge instead of under it, which
/// read as "the number doesn't line up with its label". `fixedSize` stops either line truncating so the
/// pairing is never clipped at narrow widths.
@ViewBuilder
private func bannerStat(label: String, value: String) -> some View {
    VStack(alignment: .center, spacing: 2) {
        Text(label).font(.caption2).foregroundStyle(StrandPalette.textSecondary)
        Text(value).font(.headline).foregroundStyle(StrandPalette.textPrimary)
    }
    .multilineTextAlignment(.center)
    .fixedSize()
}

/// Dynamic Island expanded-region stat column (label over value). File-scope for the same reason as
/// `bannerStat`. #759 - centre-aligned + `fixedSize` for the same value-under-its-label fix as the banner.
@ViewBuilder
private func statColumn(label: String, value: String) -> some View {
    VStack(alignment: .center, spacing: 1) {
        Text(label).font(.caption2).foregroundStyle(.secondary)
        Text(value).font(.headline)
    }
    .multilineTextAlignment(.center)
    .fixedSize()
}
