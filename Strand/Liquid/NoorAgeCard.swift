import SwiftUI
import StrandDesign

/// "Noor Age" — the headline healthspan number on Today (Noor's answer to WHOOP Age). Shows the
/// Vitality model's Body Age (mortality-hazard model over your habits), falling back to the Fitness Age
/// (resting HR + activity vs peers) while Body Age is still building. A wellness comparison from your own
/// data, not a clinical biological age. Taps through to the Health screen for the full breakdown.
struct NoorAgeCard: View {
    enum Style { case card, hero }
    /// `.card` on Today (links to Health); `.hero` at the top of the Health screen (big, centred).
    var style: Style = .card

    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore

    @State private var age: Double?
    @State private var source: Source = .body
    @State private var vitality: Double?
    @State private var loaded = false

    private enum Source { case body, fitness }

    private var chronological: Double? { profile.age > 0 ? Double(profile.age) : nil }
    private var delta: Double? {
        guard let age, let chronological else { return nil }
        return age - chronological
    }
    private var younger: Bool { (delta ?? 0) <= 0 }
    private var tint: Color { delta == nil ? NoopVisualStyle.neonAqua : (younger ? NoopVisualStyle.neonGreen : NoopVisualStyle.neonPink) }
    private var accent: Color { delta == nil ? NoopVisualStyle.neonBlue : (younger ? NoopVisualStyle.neonAqua : Color(hex: "#A24BFF")) }

    var body: some View {
        Group {
            if style == .hero { hero } else { card }
        }
        .task(id: repo.refreshSeq) { await load() }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            NoorScoreOrb(diameter: 240, tint: tint, accent: accent,
                         intensity: age == nil ? nil : (younger ? 0.95 : 0.7)) {
                VStack(spacing: 2) {
                    Text(age.map { String(format: "%.1f", $0) } ?? "–")
                        .font(StrandFont.rounded(64, weight: .semibold))
                        .tracking(-2)
                        .foregroundStyle(.white)
                    Text("NOOR AGE")
                        .font(StrandFont.rounded(12, weight: .semibold)).tracking(1.6)
                        .foregroundStyle(Color.white.opacity(0.65))
                    if age != nil, delta != nil {
                        Text(headline)
                            .font(StrandFont.rounded(15, weight: .semibold))
                            .foregroundStyle(tint)
                            .padding(.top, 6)
                    }
                }
            }
            .padding(.vertical, 26)
            Text(age == nil ? headline : subline)
                .font(StrandFont.rounded(14, weight: .regular))
                .foregroundStyle(StrandPalette.textSecondary)
                .multilineTextAlignment(.center)
            Text("A wellness comparison from your own data, not a clinical age.")
                .font(StrandFont.rounded(11, weight: .regular))
                .foregroundStyle(StrandPalette.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var card: some View {
        NavigationLink(value: TabRoute.health) {
            HStack(spacing: 18) {
                NoorScoreOrb(diameter: 128, tint: tint, accent: accent,
                             intensity: age == nil ? nil : (younger ? 0.95 : 0.7)) {
                    VStack(spacing: 0) {
                        Text(age.map { String(format: "%.1f", $0) } ?? "–")
                            .font(StrandFont.rounded(34, weight: .semibold))
                            .tracking(-1)
                            .foregroundStyle(.white)
                        Text("NOOR AGE")
                            .font(StrandFont.rounded(8.5, weight: .semibold)).tracking(1.3)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("HEALTHSPAN")
                        .font(StrandFont.rounded(11, weight: .semibold)).tracking(1.4)
                        .foregroundStyle(StrandPalette.textTertiary)
                    Text(headline)
                        .font(StrandFont.rounded(19, weight: .semibold))
                        .foregroundStyle(age == nil ? StrandPalette.textPrimary : tint)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subline)
                        .font(StrandFont.rounded(13, weight: .regular))
                        .foregroundStyle(StrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Text("See healthspan")
                        Image(systemName: "arrow.right")
                    }
                    .font(StrandFont.rounded(12, weight: .semibold)).tracking(0.4)
                    .foregroundStyle(NoopVisualStyle.neonAqua)
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(NoopPanelSurface(tint: tint, cornerRadius: 26, elevated: true))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        guard age != nil else { return String(localized: "Building your Noor Age") }
        guard let delta else { return String(localized: "Add your age in Settings") }
        let years = abs(delta)
        if years < 0.25 { return String(localized: "Right on your age") }
        let n = String(format: "%.1f", years)
        return younger ? String(localized: "\(n) years younger") : String(localized: "\(n) years older")
    }

    private var subline: String {
        guard age != nil else {
            return String(localized: "Wear your strap for about a week and Noor works out how old your body acts.")
        }
        var parts: [String] = []
        if let chronological { parts.append(String(localized: "You're \(Int(chronological))")) }
        if let vitality { parts.append(String(localized: "Vitality \(Int(vitality.rounded()))")) }
        if source == .fitness { parts.append(String(localized: "from fitness")) }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        let body = (await repo.exploreSeries(key: "body_age", source: "my-whoop")).last?.value
        let fitness = (await repo.exploreSeries(key: "fitness_age", source: "my-whoop")).last?.value
        vitality = (await repo.exploreSeries(key: "vitality", source: "my-whoop")).last?.value
        if let body { age = body; source = .body } else { age = fitness; source = .fitness }
        loaded = true
    }
}
