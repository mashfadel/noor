#if os(iOS)
import SwiftUI
import StrandDesign

/// Noor's live strip, riding above the Liquid Glass tab bar (`tabViewBottomAccessory`). Always-on proof
/// that the strap is talking and Apple Health is receiving: a beating heart with the live BPM, the strap
/// link + battery, and the Health sync state. Collapses to heart + BPM when the bar minimises on scroll.
struct NoorLiveAccessory: View {
    var onTap: () -> Void = {}

    @EnvironmentObject private var live: LiveState
    @EnvironmentObject private var health: HealthKitBridge
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var bpm: Int? { live.connected ? live.heartRate : nil }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                heart
                if placement == .inline {
                    bpmText
                } else {
                    bpmText
                    Spacer(minLength: 6)
                    strapStatus
                    divider
                    healthStatus
                }
            }
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens live heart rate"))
    }

    private var heart: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(bpm == nil ? Color.white.opacity(0.35) : NoopVisualStyle.neonPink)
            .shadow(color: bpm == nil ? .clear : NoopVisualStyle.neonPink.opacity(0.8), radius: 6)
            .symbolEffect(.pulse, options: .repeating, isActive: bpm != nil)
    }

    private var bpmText: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(bpm.map(String.init) ?? "–")
                .font(StrandFont.rounded(17, weight: .semibold))
                .contentTransition(.numericText())
                .animation(.snappy, value: bpm)
            Text("bpm")
                .font(StrandFont.rounded(11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var strapStatus: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(live.connected ? NoopVisualStyle.neonGreen : Color.white.opacity(0.3))
                .frame(width: 6, height: 6)
                .shadow(color: live.connected ? NoopVisualStyle.neonGreen : .clear, radius: 3)
            Text(live.connected ? strapLabel : String(localized: "Strap offline"))
                .font(StrandFont.rounded(12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var strapLabel: String {
        if let pct = live.batteryPct { return "\(Int(pct.rounded()))%" }
        return String(localized: "Live")
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 14)
    }

    @ViewBuilder private var healthStatus: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 12))
                .foregroundStyle(health.auth == .authorized ? NoopVisualStyle.neonAqua : Color.white.opacity(0.35))
            Group {
                if health.syncing {
                    Text("Syncing")
                } else if health.auth != .authorized {
                    Text("Health off")
                } else if let last = health.lastSync {
                    Text(last, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                } else {
                    Text("Health on")
                }
            }
            .font(StrandFont.rounded(12, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}
#endif
