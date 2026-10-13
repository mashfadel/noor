import StrandDesign
import SwiftUI
import WidgetKit

/// Noor Lock Screen heart rate: the latest BPM the app published, with how long ago it was read.
/// iOS rations widget redraws, so this is "latest reading", not a live stream (that is the Live
/// Activity's job); the "ago" label keeps ticking on its own so the age is always honest.
struct HeartRateLockWidget: Widget {
    let kind = "NoorHeartRateLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeartRateProvider()) { entry in
            HeartRateLockView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Heart rate")
        .description("Your latest heart rate from the strap, with how long ago it was read.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct HeartRateLockView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HeartRateEntry

    /// Readings older than this are hidden rather than passed off as current.
    private static let maxAge: TimeInterval = 60 * 60

    /// The newest reading and when it was taken (trace point if present, else the snapshot time).
    private var reading: (bpm: Int, at: Date)? {
        guard let snap = entry.snap, let bpm = snap.bpm, bpm > 0 else { return nil }
        let at = snap.hrSeries?.last.map { Date(timeIntervalSince1970: TimeInterval($0.ts)) } ?? snap.updated
        guard entry.date.timeIntervalSince(at) < Self.maxAge else { return nil }
        return (bpm, at)
    }

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: circular
        }
    }

    private var circular: some View {
        Gauge(value: Double(min(max(reading?.bpm ?? 40, 40), 190)), in: 40...190) {
            Image(systemName: "heart.fill")
        } currentValueLabel: {
            Text(reading.map { "\($0.bpm)" } ?? "–")
                .font(StrandFont.rounded(17, weight: .semibold))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .accessibilityLabel(Text(reading.map { "Heart rate \($0.bpm) beats per minute" } ?? "Heart rate, no recent reading"))
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").font(.system(size: 11, weight: .semibold))
                Text(verbatim: "HEART RATE").font(StrandFont.rounded(10, weight: .semibold)).tracking(1)
            }
            .widgetAccentable()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(reading.map { "\($0.bpm)" } ?? "–")
                    .font(StrandFont.rounded(26, weight: .semibold))
                Text("BPM").font(StrandFont.rounded(10, weight: .semibold))
            }
            if let reading {
                Text(reading.at, style: .relative)
                    .font(StrandFont.rounded(11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("Open Noor to sync").font(StrandFont.rounded(11, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Text(reading.map { "♥ \($0.bpm) bpm" } ?? "♥ –")
    }
}
