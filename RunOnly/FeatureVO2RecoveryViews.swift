import Charts
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 홈 탭은 요약 카드와 최근 상태를 빠르게 보는 대시보드 역할을 맡는다.
struct VO2MaxTrendView: View {
    let samples: [VO2MaxSample]
    @State private var selectedRange: VO2TrendRange = .oneYear
    @State private var selectedSampleDate: Date?

    init(samples: [VO2MaxSample], initialRange: VO2TrendRange = .oneYear) {
        self.samples = samples
        _selectedRange = State(initialValue: initialRange)
    }

    private var filteredSamples: [VO2MaxSample] {
        selectedRange.filtered(samples)
    }

    private var latest: VO2MaxSample? { filteredSamples.last }
    private var best: VO2MaxSample? { filteredSamples.max(by: { $0.value < $1.value }) }
    private var focusedSample: VO2MaxSample? {
        guard let selectedSampleDate else { return latest }
        return filteredSamples.min {
            abs($0.date.timeIntervalSince(selectedSampleDate)) < abs($1.date.timeIntervalSince(selectedSampleDate))
        }
    }
    private var changeText: String {
        guard let first = filteredSamples.first, let latest else { return "-" }
        return String(format: "%+.1f", latest.value - first.value)
    }
    private var chartYDomain: ClosedRange<Double> {
        let values = filteredSamples.map(\.value).filter(\.isFinite)
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0...1
        }
        let padding = max((maximum - minimum) * 0.18, 0.8)
        return max(minimum - padding, 0)...(maximum + padding)
    }
    private var chartXDomain: ClosedRange<Date> {
        let dates = filteredSamples.map(\.date).sorted()
        guard let start = dates.first, let end = dates.last else {
            let now = Date()
            return now...now
        }

        let span = end.timeIntervalSince(start)
        let padding = max(span * 0.04, 14 * 24 * 60 * 60)
        return start.addingTimeInterval(-padding)...end.addingTimeInterval(padding)
    }
    private var subtitleText: String {
        guard let focusedSample else {
            return "VO2 Max 데이터가 쌓이면 회복과 지구력 흐름이 더 선명하게 보여요."
        }
        return "\(focusedSample.date.formatted(date: .abbreviated, time: .omitted)) 기준 지구력 흐름이에요."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PNRPageHeader(
                    eyebrow: "ENDURANCE",
                    title: "VO2 Max",
                    subtitle: "지구력 흐름을 기간별로 확인합니다."
                )

                VO2TrendHeroCard(
                    selectedRangeLabel: selectedRange.label,
                    subtitleText: subtitleText,
                    currentText: latest.map { String(format: "%.1f", $0.value) } ?? "-",
                    bestText: best.map { String(format: "%.1f", $0.value) } ?? "-",
                    changeText: changeText
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("비교 기간")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PNR2026.muted)

                    Picker("기간", selection: $selectedRange) {
                        ForEach(VO2TrendRange.allCases) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(PNR2026.track)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .fill(PNR2026.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                                .stroke(PNR2026.line, lineWidth: 1)
                        )
                )

                DetailSection(
                    title: "VO2 Max 흐름",
                    systemImage: "heart.circle.fill",
                    tint: PNR2026.rose
                ) {
                    if filteredSamples.isEmpty {
                        Text("VO2 Max 데이터가 없습니다.")
                            .foregroundStyle(PNR2026.muted)
                    } else {
                        Chart(filteredSamples, id: \.date) { sample in
                            AreaMark(
                                x: .value("날짜", sample.date),
                                yStart: .value("VO2 Max 기준", chartYDomain.lowerBound),
                                yEnd: .value("VO2 Max", sample.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        PNR2026.rose.opacity(0.14),
                                        PNR2026.rose.opacity(0.00)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("날짜", sample.date),
                                y: .value("VO2 Max", sample.value)
                            )
                            .foregroundStyle(PNR2026.rose)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("날짜", sample.date),
                                y: .value("VO2 Max", sample.value)
                            )
                            .foregroundStyle(Color.white.opacity(focusedSample?.date == sample.date ? 1 : 0.8))
                            .symbolSize(focusedSample?.date == sample.date ? 54 : 18)

                            if let focusedSample, focusedSample.date == sample.date {
                                RuleMark(x: .value("선택", sample.date))
                                    .foregroundStyle(Color.white.opacity(0.22))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .annotation(position: .top, spacing: 8, overflowResolution: .init(x: .fit, y: .fit)) {
                                        FeatureChartCallout(
                                            title: "선택 값",
                                            value: String(format: "%.1f", sample.value),
                                            detail: sample.date.formatted(date: .abbreviated, time: .omitted),
                                            tint: PNR2026.rose
                                        )
                                    }
                            }
                        }
                        .frame(height: 240)
                        .chartXSelection(value: $selectedSampleDate)
                        .chartXScale(domain: chartXDomain)
                        .chartYScale(domain: chartYDomain)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                    .foregroundStyle(PNR2026.line)
                                AxisValueLabel {
                                    if let number = value.as(Double.self) {
                                        Text(String(format: "%.1f", number))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(PNR2026.muted)
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                AxisGridLine().foregroundStyle(PNR2026.line)
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(PNR2026.muted)
                            }
                        }
                        .chartPlotStyle { plotArea in
                            plotArea
                                .background(FeatureChartPlotBackground(tint: PNR2026.rose))
                                .clipShape(RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VO2TrendHeroCard: View {
    let selectedRangeLabel: String
    let subtitleText: String
    let currentText: String
    let bestText: String
    let changeText: String

    var body: some View {
        MetricDetailHeroCard(
            primaryBadge: "VO2 Max",
            secondaryBadge: selectedRangeLabel,
            title: "지구력 흐름",
            subtitle: subtitleText,
            tint: PNR2026.rose,
            secondaryTint: PNR2026.water
        ) {
            ViewThatFits(in: .vertical) {
                HStack(spacing: 10) {
                    FeatureMiniStatCard(title: "현재", value: currentText, tint: PNR2026.water)
                    FeatureMiniStatCard(title: "최고", value: bestText, tint: PNR2026.track)
                    FeatureMiniStatCard(title: "변화", value: changeText, tint: PNR2026.rose)
                }

                VStack(spacing: 10) {
                    FeatureMiniStatCard(title: "현재", value: currentText, tint: PNR2026.water)
                    FeatureMiniStatCard(title: "최고", value: bestText, tint: PNR2026.track)
                    FeatureMiniStatCard(title: "변화", value: changeText, tint: PNR2026.rose)
                }
            }
        }
    }
}

// VO2 Max 차트에서 사용할 기간 필터다.
enum VO2TrendRange: String, CaseIterable, Identifiable {
    case sixMonths
    case oneYear
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sixMonths: return L10n.tr("6개월")
        case .oneYear: return L10n.tr("1년")
        case .all: return L10n.tr("전체")
        }
    }

    func filtered(_ samples: [VO2MaxSample]) -> [VO2MaxSample] {
        let sortedSamples = samples.sorted { $0.date < $1.date }
        guard self != .all else { return sortedSamples }

        let days = self == .sixMonths ? -180 : -365
        let anchorDate = sortedSamples.last?.date ?? Date()
        let startDate = Calendar.current.date(byAdding: .day, value: days, to: anchorDate) ?? .distantPast
        return sortedSamples.filter { $0.date >= startDate }
    }
}

struct RecoveryReadinessView: View {
    let readiness: RecoveryReadiness
    @State private var selectedLoadDate: Date?
    @State private var showingEvidence = false

    private var primaryTint: Color {
        guard readiness.isDataSufficient, let score = readiness.score else {
            return PNR2026.water
        }

        switch score {
        case 82...:
            return PNR2026.track
        case 63..<82:
            return PNR2026.water
        case 45..<63:
            return PNR2026.heat
        default:
            return PNR2026.rose
        }
    }

    private var secondaryTint: Color {
        guard readiness.isDataSufficient, let score = readiness.score else {
            return PNR2026.track
        }

        switch score {
        case 82...:
            return PNR2026.water
        case 63..<82:
            return PNR2026.track
        case 45..<63:
            return PNR2026.water
        default:
            return PNR2026.heat
        }
    }

    private var focusedLoadPoint: RecoveryLoadPoint? {
        guard let selectedLoadDate else {
            return readiness.weeklyLoadChart.last(where: { $0.load > 0 }) ?? readiness.weeklyLoadChart.last
        }

        return readiness.weeklyLoadChart.min {
            abs($0.date.timeIntervalSince(selectedLoadDate)) < abs($1.date.timeIntervalSince(selectedLoadDate))
        }
    }

    private var hasLoadChart: Bool {
        readiness.weeklyLoadChart.contains(where: { $0.load > 0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PNRPageHeader(
                    eyebrow: "READINESS",
                    title: L10n.tr("러닝 준비도"),
                    subtitle: L10n.tr("최근 부하와 회복 간격을 같은 기준으로 확인합니다.")
                )

                RecoveryReadinessHeroCard(
                    readiness: readiness,
                    primaryTint: primaryTint,
                    secondaryTint: secondaryTint
                )

                DetailSection(
                    title: L10n.tr("오늘 권장 러닝"),
                    systemImage: "figure.run",
                    tint: primaryTint
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(readiness.recommendationTitle)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(readiness.recommendationDetail)
                            .foregroundStyle(.white.opacity(0.76))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(readiness.confidenceText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(primaryTint.opacity(0.92))
                    }
                }

                DetailSection(
                    title: readiness.isDataSufficient ? L10n.tr("왜 이렇게 봤나요") : L10n.tr("계산 조건"),
                    systemImage: readiness.isDataSufficient ? "sparkles" : "exclamationmark.circle.fill",
                    tint: secondaryTint
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        if !readiness.isDataSufficient, let dataRequirementText = readiness.dataRequirementText {
                            Text(dataRequirementText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        ForEach(Array(readiness.factors.enumerated()), id: \.offset) { _, factor in
                            RecoveryReasonRow(
                                text: factor,
                                tint: secondaryTint
                            )
                        }
                    }
                }

                if hasLoadChart {
                    DetailSection(
                        title: L10n.tr("최근 부하"),
                        systemImage: "chart.bar.fill",
                        tint: primaryTint
                    ) {
                        RecoveryLoadChartCard(
                            points: readiness.weeklyLoadChart,
                            focusedPoint: focusedLoadPoint,
                            tint: primaryTint,
                            secondaryTint: secondaryTint,
                            selectedLoadDate: $selectedLoadDate
                        )
                    }
                }

                Button {
                    showingEvidence = true
                } label: {
                    HStack {
                        Image(systemName: "book.closed")
                        Text(L10n.tr("근거 보기"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PNR2026.ink)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                            .fill(PNR2026.surfaceHigh)
                            .overlay(
                                RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                                    .stroke(PNR2026.line, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEvidence) {
            ReadinessEvidenceView()
        }
    }
}

struct RecoveryReadinessHeroCard: View {
    let readiness: RecoveryReadiness
    let primaryTint: Color
    let secondaryTint: Color

    var body: some View {
        MetricDetailHeroCard(
            primaryBadge: L10n.tr("러닝 준비도"),
            secondaryBadge: readiness.status,
            title: readiness.scoreText,
            subtitle: readiness.detail,
            tint: primaryTint,
            secondaryTint: secondaryTint,
            titleFont: .system(size: 48, weight: .bold, design: .rounded)
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    FeatureMiniStatCard(
                        title: L10n.tr("최근 부하"),
                        value: readiness.recentLoadText,
                        detail: readiness.effortBasisText ?? readiness.loadRatioText ?? L10n.tr("최근 7일 기준"),
                        tint: primaryTint
                    )
                    FeatureMiniStatCard(
                        title: L10n.tr("마지막 러닝"),
                        value: readiness.lastRunText,
                        detail: readiness.isDataSufficient ? L10n.tr("회복 간격") : L10n.tr("최근 기록 기준"),
                        tint: secondaryTint
                    )
                }

                FeatureMiniStatCard(
                    title: readiness.restingHeartRateText == nil ? L10n.tr("기준") : L10n.tr("안정시 심박"),
                    value: readiness.restingHeartRateText ?? readiness.confidenceText,
                    detail: readiness.restingHeartRateText == nil ? L10n.tr("현재 계산 방식") : L10n.tr("기준 대비 변화"),
                    tint: PNR2026.heat
                )
            }
        }
    }
}

struct RecoveryReasonRow: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .padding(.top, 6)

            Text(text)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RecoveryLoadChartCard: View {
    let points: [RecoveryLoadPoint]
    let focusedPoint: RecoveryLoadPoint?
    let tint: Color
    let secondaryTint: Color
    @Binding var selectedLoadDate: Date?

    var body: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("날짜", point.date, unit: .day),
                    y: .value("부하", point.load),
                    width: .fixed(22)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: focusedPoint?.id == point.id
                            ? [Color.white, tint]
                            : [tint, secondaryTint.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(focusedPoint == nil || focusedPoint?.id == point.id ? 1 : 0.42)
                .cornerRadius(8)
                .annotation(position: .top, spacing: 8) {
                    if focusedPoint?.id == point.id {
                        FeatureChartCallout(
                            title: point.label,
                            value: point.loadText,
                            detail: point.dateText,
                            tint: tint
                        )
                    }
                }
            }
        }
        .frame(height: 220)
        .chartXSelection(value: $selectedLoadDate)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(0.08))
                AxisValueLabel {
                    if let load = value.as(Double.self) {
                        Text(L10n.format("%d", Int(load.rounded())))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.54))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: points.map(\.date)) { value in
                AxisGridLine()
                    .foregroundStyle(.white.opacity(0.05))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(FeatureChartPlotBackground(tint: tint))
                .clipShape(RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous))
        }
    }
}

struct ReadinessEvidenceView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PNRPageHeader(
                        eyebrow: "EVIDENCE",
                        title: L10n.tr("준비도 근거"),
                        subtitle: L10n.tr("준비도 계산에 쓰는 신호와 한계를 확인합니다.")
                    )

                    DetailSection(
                        title: L10n.tr("이 점수는 무엇인가요"),
                        systemImage: "heart.text.square.fill",
                        tint: PNR2026.water
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.tr("러닝 준비도는 몸 상태를 진단하는 의료 점수가 아니라, 최근 러닝 부하와 회복 간격을 바탕으로 오늘 러닝 강도를 가볍게 가이드하는 점수예요."))
                            Text(L10n.tr("현재 버전은 최근 28일 러닝 기록, Apple 노력 점수, 마지막 러닝 이후 시간, 그리고 있으면 안정시 심박을 함께 참고합니다."))
                            Text(L10n.tr("논문에서 널리 쓰는 훈련 부하와 회복 모니터링 개념을 참고했지만, 점수화 방식은 PNR에 맞게 단순화한 가이드예요."))
                        }
                        .foregroundStyle(.white.opacity(0.82))
                    }

                    DetailSection(
                        title: L10n.tr("참고 문헌"),
                        systemImage: "book.fill",
                        tint: PNR2026.track
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ReadinessEvidenceLinkRow(
                                title: "Foster et al. (2001)",
                                subtitle: "A new approach to monitoring exercise training",
                                urlString: "https://pubmed.ncbi.nlm.nih.gov/11708692/"
                            )
                            ReadinessEvidenceLinkRow(
                                title: "Kiviniemi et al. (2007)",
                                subtitle: "HRV-guided endurance training",
                                urlString: "https://pubmed.ncbi.nlm.nih.gov/17849143/"
                            )
                            ReadinessEvidenceLinkRow(
                                title: "Plews et al. (2013)",
                                subtitle: "HRV and endurance monitoring review",
                                urlString: "https://pubmed.ncbi.nlm.nih.gov/23852425/"
                            )
                            ReadinessEvidenceLinkRow(
                                title: "Manresa-Rocamora et al. (2021)",
                                subtitle: "HRV-guided training meta-analysis",
                                urlString: "https://pubmed.ncbi.nlm.nih.gov/34639599/"
                            )
                        }
                    }

                    DetailSection(
                        title: L10n.tr("한계"),
                        systemImage: "exclamationmark.triangle.fill",
                        tint: PNR2026.heat
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.tr("수면, HRV, 스트레스 같은 데이터는 아직 반영하지 않아 실제 회복 상태를 완전히 대변하지는 못합니다."))
                            Text(L10n.tr("데이터가 부족하면 억지로 점수를 만들지 않고 `데이터 필요` 상태로 남겨둡니다."))
                            Text(L10n.tr("몸 상태가 평소와 다르거나 통증이 있다면 준비도 점수보다 내 컨디션을 우선해 주세요."))
                        }
                        .foregroundStyle(.white.opacity(0.82))
                    }
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ReadinessEvidenceLinkRow: View {
    let title: String
    let subtitle: String
    let urlString: String

    var body: some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PNR2026.muted)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PNR2026.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(PNR2026.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .fill(PNR2026.surfaceHigh)
                        .overlay(
                            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                                .stroke(PNR2026.line, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// 예상 기록 추세 화면은 거리별 최근 러닝 폼을 요약한다.
