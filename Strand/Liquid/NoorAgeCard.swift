import SwiftUI
import StrandDesign

/// "Noor Age" — the headline healthspan number (Noor's answer to WHOOP Age): Body Age from the Vitality
/// model, falling back to Fitness Age while it builds. A wellness comparison from your own data, not a
/// clinical biological age.
///   `.card` — Today, under the dials; opens Healthspan.
///   `.hero` — top of the Health screen: the living orb, pace of aging, and the way into Healthspan.
struct NoorAgeCard: View {
    enum Style { case card, hero }
    var style: Style = .card

    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @State private var snap = HealthspanSnapshot()

    private var tint: Color { NoorAgeStyle.tint(snap.delta) }

    var body: some View {
        Group {
            if style == .hero { hero } else { card }
        }
        .task(id: repo.refreshSeq) { snap = await HealthspanSnapshot.load(repo: repo, profile: profile) }
    }

    private var headline: String {
        guard snap.age != nil else { return String(localized: "Building your Noor Age") }
        guard let delta = snap.delta else { return String(localized: "Add your age in Settings") }
        let years = abs(delta)
        if years < 0.25 { return String(localized: "Right on your age") }
        let n = String(format: "%.1f", years)
        return delta < 0 ? String(localized: "\(n) years younger") : String(localized: "\(n) years older")
    }

    private var subline: String {
        guard snap.age != nil else {
            return String(localized: "Wear your strap for about a week and Noor works out how old your body acts.")
        }
        var parts: [String] = []
        if let pace = snap.pace { parts.append(String(localized: "Pace \(String(format: "%.1f", pace))x")) }
        if let v = snap.vitality { parts.append(String(localized: "Vitality \(Int(v.rounded()))")) }
        return parts.joined(separator: " · ")
    }

    // MARK: Health hero

    private var hero: some View {
        VStack(spacing: 18) {
            NoorAgeOrb(snapshot: snap, diameter: 220)
                .padding(.top, 36)
                .padding(.bottom, 22)
            Text(headline)
                .font(StrandFont.rounded(17, weight: .semibold))
                .foregroundStyle(snap.delta == nil ? StrandPalette.textPrimary : tint)
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: "PACE OF AGING")
                    .font(StrandFont.rounded(12, weight: .semibold)).tracking(1.4)
                    .foregroundStyle(StrandPalette.textPrimary)
                PaceOfAgingScale(pace: snap.pace)
                if snap.pace == nil {
                    Text("Pace appears after about ten weeks of Noor Age history, so a noisy week can't swing it.")
                        .font(StrandFont.rounded(12, weight: .regular))
                        .foregroundStyle(StrandPalette.textTertiary)
                }
                NavigationLink {
                    NoorHealthspanView()
                } label: {
                    Text(verbatim: "GO TO HEALTHSPAN")
                        .font(StrandFont.rounded(13, weight: .semibold)).tracking(1.4)
                        .foregroundStyle(StrandPalette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(NoopPanelSurface(cornerRadius: 24))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Today card

    private var card: some View {
        NavigationLink {
            NoorHealthspanView()
        } label: {
            HStack(spacing: 16) {
                NoorAgeOrb(snapshot: snap, diameter: 112)
                    .frame(width: 128, height: 128)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "HEALTHSPAN")
                        .font(StrandFont.rounded(11, weight: .semibold)).tracking(1.4)
                        .foregroundStyle(StrandPalette.textTertiary)
                    Text(headline)
                        .font(StrandFont.rounded(19, weight: .semibold))
                        .foregroundStyle(snap.age == nil ? StrandPalette.textPrimary : tint)
                        .fixedSize(horizontal: false, vertical: true)
                    if !subline.isEmpty {
                        Text(subline)
                            .font(StrandFont.rounded(13, weight: .regular))
                            .foregroundStyle(StrandPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 4) {
                        Text("See healthspan")
                        Image(systemName: "arrow.right")
                    }
                    .font(StrandFont.rounded(12, weight: .semibold))
                    .foregroundStyle(NoopVisualStyle.neonAqua)
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(NoopPanelSurface(tint: tint, cornerRadius: 26, elevated: true))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
