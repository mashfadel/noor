import SwiftUI
import StrandDesign
import StrandAnalytics
import WhoopStore

// MARK: - Model

/// Everything the Noor Age / Healthspan surfaces show, computed from the same inputs and formula the
/// IntelligenceEngine uses for Body Age (VitalityEngine), so the breakdown always adds up to the headline.
/// A wellness comparison from the wearer's own data, not a clinical age.
struct HealthspanSnapshot: Equatable {
    var age: Double?
    var chronological: Double?
    var vitality: Double?
    /// Years per calendar year (1.0 = ageing at the normal rate). Nil until enough weekly history.
    var pace: Double?
    var factors: [Factor] = []

    var delta: Double? { age.flatMap { a in chronological.map { a - $0 } } }

    struct Factor: Equatable, Identifiable {
        enum Group: String { case sleep = "Sleep", activity = "Activity", fitness = "Fitness" }
        let id: String
        let group: Group
        let title: String
        let unit: String
        let low: Double, high: Double
        let higherIsBetter: Bool
        let value30: Double?
        let value180: Double?
        /// Years this factor adds (+) or takes off (−) on the last 30 days.
        let years: Double?
        let format: (Double) -> String

        static func == (a: Factor, b: Factor) -> Bool {
            a.id == b.id && a.value30 == b.value30 && a.value180 == b.value180 && a.years == b.years
        }
    }

    static let paceRange: ClosedRange<Double> = -1.0...3.0

    @MainActor
    static func load(repo: Repository, profile: ProfileStore) async -> HealthspanSnapshot {
        var snap = HealthspanSnapshot()
        let bodyAge = await repo.exploreSeries(key: "body_age", source: "my-whoop")
        let fitnessAge = await repo.exploreSeries(key: "fitness_age", source: "my-whoop")
        snap.vitality = (await repo.exploreSeries(key: "vitality", source: "my-whoop")).last?.value
        snap.age = bodyAge.last?.value ?? fitnessAge.last?.value
        snap.chronological = profile.age > 0 ? Double(profile.age) : nil
        snap.pace = pace(from: bodyAge)
        snap.factors = buildFactors(days: repo.days, chronoAge: Double(profile.age))
        return snap
    }

    /// Pace of aging in years per calendar year: 1.0 means ageing at the normal rate. Body Age is stored as
    /// (whole-number age + the habits-driven gap), so its slope over time is how fast that GAP moves; a
    /// steady gap is the normal 1.0x, a widening one faster, a narrowing one slower. Fit over up to six
    /// months of weekly points so one noisy week cannot swing it.
    static func pace(from series: [(day: String, value: Double)]) -> Double? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let pts = series.suffix(26).compactMap { p in f.date(from: p.day).map { ($0.timeIntervalSince1970 / 86_400 / 365.25, p.value) } }
        guard pts.count >= 10, let first = pts.first?.0, let last = pts.last?.0, last - first >= 63.0 / 365.25 else { return nil }
        let n = Double(pts.count)
        let mx = pts.reduce(0) { $0 + $1.0 } / n, my = pts.reduce(0) { $0 + $1.1 } / n
        let sxx = pts.reduce(0) { $0 + ($1.0 - mx) * ($1.0 - mx) }
        guard sxx > 0 else { return nil }
        let slope = pts.reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) } / sxx
        return min(max(1 + slope, paceRange.lowerBound), paceRange.upperBound)
    }

    private static func median(_ a: [Double]) -> Double? {
        guard !a.isEmpty else { return nil }
        let s = a.sorted(); let m = s.count / 2
        return s.count % 2 == 0 ? (s[m - 1] + s[m]) / 2 : s[m]
    }
    private static func mean(_ a: [Double]) -> Double? { a.isEmpty ? nil : a.reduce(0, +) / Double(a.count) }

    private struct Window {
        let rhr, hrv, sleepHours, consistency, steps: Double?
        init(_ days: ArraySlice<DailyMetric>) {
            let nights = days.compactMap { $0.totalSleepMin }.map { Double($0) / 60 }.filter { $0 > 0 }
            rhr = HealthspanSnapshot.median(days.compactMap { $0.restingHr }.map(Double.init))
            hrv = HealthspanSnapshot.median(days.compactMap { $0.avgHrv })
            sleepHours = HealthspanSnapshot.mean(nights)
            consistency = VitalityEngine.sleepConsistency(nightlyHours: nights)
            steps = HealthspanSnapshot.mean(days.compactMap { $0.steps }.map(Double.init))
        }
    }

    static func buildFactors(days: [DailyMetric], chronoAge: Double) -> [Factor] {
        let sorted = days.sorted { $0.day < $1.day }
        let w30 = Window(sorted.suffix(30)), w180 = Window(sorted.suffix(180))
        // Per-factor years on the last 30 days: the same log-hazard × overlap shrink ÷ ln-hazard-per-year
        // the engine sums for Body Age.
        let inputs = VitalityEngine.Inputs(chronoAge: chronoAge, restingHR: w30.rhr, sleepHours: w30.sleepHours,
                                           sleepConsistency: w30.consistency, rmssd: w30.hrv,
                                           rmssdNorm: VitalityEngine.rmssdNorm(forAge: chronoAge), steps: w30.steps)
        let perYear = log(2.0) / 8.0
        var years: [String: Double] = [:]
        for c in VitalityEngine.contributions(inputs) { years[c.key] = c.lnHazard * 0.75 / perYear }
        let pct: (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }
        let hm: (Double) -> String = { v in let m = Int((v * 60).rounded()); return "\(m / 60):" + String(format: "%02d", m % 60) }
        let int: (Double) -> String = { NumberFormatter.localizedString(from: NSNumber(value: Int($0.rounded())), number: .decimal) }
        return [
            Factor(id: "consistency", group: .sleep, title: "Sleep consistency", unit: "", low: 0.3, high: 1.0,
                   higherIsBetter: true, value30: w30.consistency, value180: w180.consistency,
                   years: years["consistency"], format: pct),
            Factor(id: "sleep", group: .sleep, title: "Hours of sleep", unit: "h", low: 5, high: 8,
                   higherIsBetter: true, value30: w30.sleepHours, value180: w180.sleepHours,
                   years: years["sleep"], format: hm),
            Factor(id: "steps", group: .activity, title: "Steps", unit: "steps", low: 0, high: 16_000,
                   higherIsBetter: true, value30: w30.steps, value180: w180.steps,
                   years: years["steps"], format: int),
            Factor(id: "rhr", group: .fitness, title: "Resting heart rate", unit: "bpm", low: 40, high: 80,
                   higherIsBetter: false, value30: w30.rhr, value180: w180.rhr,
                   years: years["rhr"], format: int),
            Factor(id: "hrv", group: .fitness, title: "Heart-rate variability", unit: "ms", low: 20, high: 120,
                   higherIsBetter: true, value30: w30.hrv, value180: w180.hrv,
                   years: years["hrv"], format: int),
        ]
    }
}

// MARK: - Shared pieces

enum NoorAgeStyle {
    static func tint(_ delta: Double?) -> Color {
        guard let delta else { return NoopVisualStyle.neonAqua }
        return delta <= 0 ? NoopVisualStyle.neonGreen : NoopVisualStyle.neonPink
    }
    static func accent(_ delta: Double?) -> Color {
        guard let delta else { return NoopVisualStyle.neonBlue }
        return delta <= 0 ? NoopVisualStyle.neonAqua : Color(hex: "#A24BFF")
    }
    static let worse = Color(hex: "#FF9F2E")
    static let better = NoopVisualStyle.neonGreen

    static func yearsText(_ y: Double) -> String {
        let s = String(format: "%.1f", abs(y))
        return y > 0.05 ? "+\(s)" : (y < -0.05 ? "−\(s)" : "0.0")
    }
}

/// The age orb with its number, used by the Health hero and the Healthspan header.
struct NoorAgeOrb: View {
    let snapshot: HealthspanSnapshot
    let diameter: CGFloat

    var body: some View {
        NoorBlobOrb(diameter: diameter, tint: NoorAgeStyle.tint(snapshot.delta), accent: NoorAgeStyle.accent(snapshot.delta)) {
            VStack(spacing: diameter * 0.015) {
                Text(snapshot.age.map { String(format: "%.1f", $0) } ?? "–")
                    .font(StrandFont.rounded(diameter * 0.2, weight: .semibold))
                    .tracking(-diameter * 0.004)
                    .foregroundStyle(.white)
                Text(verbatim: "NOOR AGE")
                    .font(StrandFont.rounded(max(8, diameter * 0.048), weight: .semibold)).tracking(1.4)
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
    }
}

/// Pace-of-aging slider: −1.0x … 3.0x on a fine tick scale, a marker at the current pace.
struct PaceOfAgingScale: View {
    let pace: Double?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Slow", systemImage: "tortoise.fill").font(StrandFont.rounded(13, weight: .medium))
                    .foregroundStyle(NoorAgeStyle.better)
                Spacer()
                Text(pace.map { String(format: "%.1fx", $0) } ?? "–")
                    .font(StrandFont.rounded(28, weight: .semibold))
                    .foregroundStyle(StrandPalette.textPrimary)
                Spacer()
                Label("Fast", systemImage: "hare.fill").labelStyle(TrailingIconLabelStyle())
                    .font(StrandFont.rounded(13, weight: .medium))
                    .foregroundStyle(NoorAgeStyle.worse)
            }
            GeometryReader { g in
                let range = HealthspanSnapshot.paceRange
                let frac = pace.map { ($0 - range.lowerBound) / (range.upperBound - range.lowerBound) }
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<81, id: \.self) { i in
                            Rectangle()
                                .fill(tickColor(Double(i) / 80))
                                .frame(width: 1.5, height: i % 10 == 0 ? 26 : 18)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    if let frac {
                        Capsule().fill(Color.white)
                            .frame(width: 3, height: 36)
                            .shadow(color: .white.opacity(0.6), radius: 4)
                            .offset(x: g.size.width * frac - 1.5)
                    }
                }
                .frame(height: 36)
            }
            .frame(height: 36)
            HStack {
                Text("-1.0x"); Spacer(); Text("1.0x"); Spacer(); Text("3.0x")
            }
            .font(StrandFont.rounded(12, weight: .medium))
            .foregroundStyle(StrandPalette.textTertiary)
        }
    }

    private func tickColor(_ x: Double) -> Color {
        // 1.0x sits at 0.5 of the scale; slower is green, faster amber.
        x < 0.5 ? NoorAgeStyle.better.opacity(0.35 + 0.4 * (0.5 - x) * 2)
                : NoorAgeStyle.worse.opacity(0.35 + 0.4 * (x - 0.5) * 2)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.title; configuration.icon }
    }
}

// MARK: - Healthspan screen

/// The full Healthspan view (Noor's take on WHOOP's): a pinned header — years older/younger, the living
/// orb, pace of aging — over the factors driving it, each with its 6-month and 30-day averages on a
/// range bar and the years it adds or takes off.
struct NoorHealthspanView: View {
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @State private var snap = HealthspanSnapshot()
    /// True once the big orb has scrolled away: the compact header (years · orb · pace) slides in.
    @State private var compact = false

    private var yearsLabel: String {
        guard let d = snap.delta else { return "" }
        if abs(d) < 0.25 { return String(localized: "right on your age") }
        let n = String(format: "%.1f", abs(d))
        return d > 0 ? String(localized: "\(n) years older") : String(localized: "\(n) years younger")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // 1. The big living orb, with the age and the years delta inside it.
                NoorBlobOrb(diameter: 290, tint: NoorAgeStyle.tint(snap.delta), accent: NoorAgeStyle.accent(snap.delta)) {
                    VStack(spacing: 6) {
                        Text(snap.age.map { String(format: "%.1f", $0) } ?? "–")
                            .font(StrandFont.rounded(60, weight: .semibold))
                            .tracking(-1.5)
                            .foregroundStyle(.white)
                        Text(verbatim: "NOOR AGE")
                            .font(StrandFont.rounded(14, weight: .semibold)).tracking(1.6)
                            .foregroundStyle(Color.white.opacity(0.6))
                        if !yearsLabel.isEmpty {
                            Text(yearsLabel)
                                .font(StrandFont.rounded(17, weight: .semibold))
                                .foregroundStyle(NoorAgeStyle.tint(snap.delta))
                                .padding(.top, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.bottom, 30)

                // 2. Pace of aging.
                VStack(alignment: .leading, spacing: 16) {
                    Text(verbatim: "PACE OF AGING")
                        .font(StrandFont.rounded(13, weight: .semibold)).tracking(1.5)
                        .foregroundStyle(StrandPalette.textPrimary)
                    PaceOfAgingScale(pace: snap.pace)
                    if snap.pace == nil {
                        Text("Pace appears after about ten weeks of Noor Age history, so a noisy week can't swing it.")
                            .font(StrandFont.rounded(12, weight: .regular))
                            .foregroundStyle(StrandPalette.textTertiary)
                    }
                }

                // 3. What drives it.
                ForEach([HealthspanSnapshot.Factor.Group.sleep, .activity, .fitness], id: \.self) { group in
                    let items = snap.factors.filter { $0.group == group }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(group.rawValue)
                                    .font(StrandFont.rounded(26, weight: .semibold))
                                    .foregroundStyle(StrandPalette.textPrimary)
                                Spacer()
                                legend
                            }
                            VStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { i, f in
                                    FactorRow(factor: f)
                                    if i < items.count - 1 {
                                        Rectangle().fill(StrandPalette.hairline).frame(height: 0.5).padding(.horizontal, 18)
                                    }
                                }
                            }
                            .background(NoopPanelSurface(cornerRadius: 24))
                        }
                    }
                }
                Text("Noor Age is a wellness comparison from your own data using published health-risk research, not a clinical or biological age.")
                    .font(StrandFont.rounded(12, weight: .regular))
                    .foregroundStyle(StrandPalette.textTertiary)
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 16)
        }
        #if os(iOS)
        .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 330 } action: { _, past in
            withAnimation(.snappy(duration: 0.3)) { compact = past }
        }
        #endif
        .overlay(alignment: .top) {
            if compact {
                compactHeader.transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(StrandPalette.surfaceBase.ignoresSafeArea())
        .navigationTitle("Healthspan")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: repo.refreshSeq) { snap = await HealthspanSnapshot.load(repo: repo, profile: profile) }
    }

    /// The pinned header once scrolled: years older/younger · the orb · pace of aging.
    private var compactHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            stat(value: snap.delta.map { String(format: "%.1f", abs($0)) } ?? "–",
                 label: (snap.delta ?? 0) > 0 ? "YEARS OLDER" : "YEARS YOUNGER",
                 color: snap.delta == nil ? StrandPalette.textPrimary : NoorAgeStyle.tint(snap.delta))
            NoorAgeOrb(snapshot: snap, diameter: 112)
                .padding(.vertical, 18)
            stat(value: snap.pace.map { String(format: "%.1fx", $0) } ?? "–", label: "PACE OF AGING",
                 color: StrandPalette.textPrimary)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(StrandPalette.surfaceBase)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [StrandPalette.surfaceBase, StrandPalette.surfaceBase.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 18).offset(y: 18).allowsHitTesting(false)
        }
    }

    private func stat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(StrandFont.rounded(24, weight: .semibold)).foregroundStyle(color)
            Text(verbatim: label).font(StrandFont.rounded(10, weight: .semibold)).tracking(1.2)
                .foregroundStyle(StrandPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            Label("6-month avg", systemImage: "arrowtriangle.down.fill")
            Label("30-day avg", systemImage: "arrowtriangle.up.fill")
        }
        .labelStyle(CompactLabelStyle())
        .font(StrandFont.rounded(11, weight: .medium))
        .foregroundStyle(StrandPalette.textSecondary)
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.icon.font(.system(size: 8)); configuration.title }
    }
}

/// One factor: value over a gradient range bar, ▼ 6-month and ▲ 30-day markers, years impact at right.
private struct FactorRow: View {
    let factor: HealthspanSnapshot.Factor

    private func fraction(_ v: Double) -> Double {
        min(1, max(0, (v - factor.low) / (factor.high - factor.low)))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(factor.title).textCase(.uppercase)
                    .font(StrandFont.rounded(12, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(StrandPalette.textPrimary)
                GeometryReader { g in
                    let w = g.size.width
                    ZStack(alignment: .topLeading) {
                        if let v = factor.value180 {
                            VStack(spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(factor.format(v)).font(StrandFont.rounded(17, weight: .semibold))
                                    if !factor.unit.isEmpty {
                                        Text(factor.unit).font(StrandFont.rounded(12, weight: .medium))
                                            .foregroundStyle(StrandPalette.textSecondary)
                                    }
                                }
                                .fixedSize()
                                Image(systemName: "arrowtriangle.down.fill").font(.system(size: 10))
                            }
                            .foregroundStyle(StrandPalette.textPrimary)
                            .position(x: min(max(w * fraction(v), 30), w - 30), y: 14)
                        }
                        bar.frame(height: 5).offset(y: 34)
                        if let v = factor.value30 {
                            Image(systemName: "arrowtriangle.up.fill").font(.system(size: 9))
                                .foregroundStyle(StrandPalette.textSecondary)
                                .position(x: w * fraction(v), y: 46)
                        }
                        HStack {
                            Text(factor.format(factor.low)); Spacer(); Text(factor.format(factor.high))
                        }
                        .font(StrandFont.rounded(11, weight: .semibold))
                        .foregroundStyle(StrandPalette.textTertiary)
                        .offset(y: 54)
                    }
                }
                .frame(height: 70)
            }
            VStack(spacing: 0) {
                Text(factor.years.map(NoorAgeStyle.yearsText) ?? "–")
                    .font(StrandFont.rounded(20, weight: .semibold))
                    .foregroundStyle(yearsColor)
                Text("years").font(StrandFont.rounded(12, weight: .regular))
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            .frame(width: 56)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var yearsColor: Color {
        guard let y = factor.years else { return StrandPalette.textTertiary }
        if y > 0.05 { return NoorAgeStyle.worse }
        if y < -0.05 { return NoorAgeStyle.better }
        return StrandPalette.textPrimary
    }

    private var bar: some View {
        let colors = factor.higherIsBetter ? [NoorAgeStyle.worse, NoorAgeStyle.worse.opacity(0.5), NoorAgeStyle.better.opacity(0.5), NoorAgeStyle.better]
                                           : [NoorAgeStyle.better, NoorAgeStyle.better.opacity(0.5), NoorAgeStyle.worse.opacity(0.5), NoorAgeStyle.worse]
        return HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { i in
                Capsule().fill(segmentColor(colors, Double(i) / 9))
            }
        }
    }

    private func segmentColor(_ c: [Color], _ x: Double) -> Color {
        x < 0.33 ? c[0] : (x < 0.5 ? c[1] : (x < 0.67 ? c[2] : c[3]))
    }
}
