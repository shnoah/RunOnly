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
    private var subtitleText: String {
        guard let focusedSample else {
            return "VO2 Max 데이터가 쌓이면 회복과 지구력 흐름이 더 선명하게 보여요."
        }
        return "\(focusedSample.date.formatted(date: .abbreviated, time: .omitted)) 기준 지구력 흐름이에요."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
                        .foregroundStyle(.white.opacity(0.58))

                    Picker("기간", selection: $selectedRange) {
                        ForEach(VO2TrendRange.allCases) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color(red: 0.94, green: 0.41, blue: 0.45).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        )
                )

                DetailSection(
                    title: "VO2 Max 흐름",
                    systemImage: "heart.circle.fill",
                    tint: Color(red: 0.94, green: 0.41, blue: 0.45)
                ) {
                    if filteredSamples.isEmpty {
                        Text("VO2 Max 데이터가 없습니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        Chart(filteredSamples, id: \.date) { sample in
                            AreaMark(
                                x: .value("날짜", sample.date),
                                y: .value("VO2 Max", sample.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.94, green: 0.41, blue: 0.45).opacity(0.28),
                                        Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.04)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("날짜", sample.date),
                                y: .value("VO2 Max", sample.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.94, green: 0.41, blue: 0.45),
                                        Color(red: 0.29, green: 0.88, blue: 0.63)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
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
                                            tint: Color(red: 0.94, green: 0.41, blue: 0.45)
                                        )
                                    }
                            }
                        }
                        .frame(height: 240)
                        .chartXSelection(value: $selectedSampleDate)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                    .foregroundStyle(.white.opacity(0.08))
                                AxisValueLabel {
                                    if let number = value.as(Double.self) {
                                        Text(String(format: "%.1f", number))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.58))
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) { _ in
                                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        .chartPlotStyle { plotArea in
                            plotArea
                                .background(FeatureChartPlotBackground(tint: Color(red: 0.94, green: 0.41, blue: 0.45)))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("VO2 Max")
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FeatureToneBadge(
                    text: "VO2 Max",
                    tint: Color(red: 0.94, green: 0.41, blue: 0.45),
                    foreground: Color(red: 1.0, green: 0.84, blue: 0.86)
                )

                Spacer()

                FeatureToneBadge(
                    text: selectedRangeLabel,
                    tint: Color(red: 0.42, green: 0.76, blue: 1.0),
                    foreground: Color(red: 0.74, green: 0.9, blue: 1.0)
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("지구력 흐름")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .vertical) {
                HStack(spacing: 10) {
                    FeatureMiniStatCard(title: "현재", value: currentText, tint: Color(red: 0.42, green: 0.76, blue: 1.0))
                    FeatureMiniStatCard(title: "최고", value: bestText, tint: Color(red: 0.29, green: 0.88, blue: 0.63))
                    FeatureMiniStatCard(title: "변화", value: changeText, tint: Color(red: 0.94, green: 0.41, blue: 0.45))
                }

                VStack(spacing: 10) {
                    FeatureMiniStatCard(title: "현재", value: currentText, tint: Color(red: 0.42, green: 0.76, blue: 1.0))
                    FeatureMiniStatCard(title: "최고", value: bestText, tint: Color(red: 0.29, green: 0.88, blue: 0.63))
                    FeatureMiniStatCard(title: "변화", value: changeText, tint: Color(red: 0.94, green: 0.41, blue: 0.45))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.17, green: 0.14, blue: 0.2),
                            Color(red: 0.94, green: 0.41, blue: 0.45).opacity(0.18),
                            Color(red: 0.42, green: 0.76, blue: 1.0).opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
        )
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
        guard self != .all else { return samples }

        let days = self == .sixMonths ? -180 : -365
        let startDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? .distantPast
        return samples.filter { $0.date >= startDate }
    }
}

struct RecoveryReadinessView: View {
    let readiness: RecoveryReadiness
    @State private var selectedLoadDate: Date?
    @State private var showingEvidence = false

    private var primaryTint: Color {
        guard readiness.isDataSufficient, let score = readiness.score else {
            return Color(red: 0.42, green: 0.76, blue: 1.0)
        }

        switch score {
        case 82...:
            return Color(red: 0.29, green: 0.88, blue: 0.63)
        case 63..<82:
            return Color(red: 0.42, green: 0.76, blue: 1.0)
        case 45..<63:
            return Color(red: 0.95, green: 0.59, blue: 0.32)
        default:
            return Color(red: 0.94, green: 0.41, blue: 0.45)
        }
    }

    private var secondaryTint: Color {
        guard readiness.isDataSufficient, let score = readiness.score else {
            return Color(red: 0.29, green: 0.88, blue: 0.63)
        }

        switch score {
        case 82...:
            return Color(red: 0.42, green: 0.76, blue: 1.0)
        case 63..<82:
            return Color(red: 0.29, green: 0.88, blue: 0.63)
        case 45..<63:
            return Color(red: 0.42, green: 0.76, blue: 1.0)
        default:
            return Color(red: 0.95, green: 0.59, blue: 0.32)
        }
    }

    private var badgeForeground: Color {
        Color.white.opacity(0.92)
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
                RecoveryReadinessHeroCard(
                    readiness: readiness,
                    primaryTint: primaryTint,
                    secondaryTint: secondaryTint,
                    badgeForeground: badgeForeground
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
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.07),
                                        secondaryTint.opacity(0.16)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle(L10n.tr("러닝 준비도"))
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
    let badgeForeground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FeatureToneBadge(
                    text: L10n.tr("러닝 준비도"),
                    tint: primaryTint,
                    foreground: badgeForeground
                )

                Spacer()

                FeatureToneBadge(
                    text: readiness.status,
                    tint: secondaryTint,
                    foreground: badgeForeground
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(readiness.scoreText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(readiness.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .vertical) {
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
                    FeatureMiniStatCard(
                        title: readiness.restingHeartRateText == nil ? L10n.tr("기준") : L10n.tr("안정시 심박"),
                        value: readiness.restingHeartRateText ?? readiness.confidenceText,
                        detail: readiness.restingHeartRateText == nil ? L10n.tr("현재 계산 방식") : L10n.tr("기준 대비 변화"),
                        tint: Color(red: 0.95, green: 0.59, blue: 0.32)
                    )
                }

                VStack(spacing: 10) {
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
                    FeatureMiniStatCard(
                        title: readiness.restingHeartRateText == nil ? L10n.tr("기준") : L10n.tr("안정시 심박"),
                        value: readiness.restingHeartRateText ?? readiness.confidenceText,
                        detail: readiness.restingHeartRateText == nil ? L10n.tr("현재 계산 방식") : L10n.tr("기준 대비 변화"),
                        tint: Color(red: 0.95, green: 0.59, blue: 0.32)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.17, blue: 0.24),
                            primaryTint.opacity(0.18),
                            secondaryTint.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
        )
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
        }
    }
}

struct ReadinessEvidenceView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DetailSection(
                        title: L10n.tr("이 점수는 무엇인가요"),
                        systemImage: "heart.text.square.fill",
                        tint: Color(red: 0.42, green: 0.76, blue: 1.0)
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
                        tint: Color(red: 0.29, green: 0.88, blue: 0.63)
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
                        tint: Color(red: 0.95, green: 0.59, blue: 0.32)
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
            .navigationTitle(L10n.tr("준비도 근거"))
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
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// 예상 기록 추세 화면은 거리별 최근 러닝 폼을 요약한다.
