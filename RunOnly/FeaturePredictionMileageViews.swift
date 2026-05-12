import Charts
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 홈 탭은 요약 카드와 최근 상태를 빠르게 보는 대시보드 역할을 맡는다.
struct PredictionTrendView: View {
    let runs: [RunningWorkout]
    @State private var selectedDistance: PredictionDistance = .fiveK
    @State private var showingMethod = false
    @State private var selectedPredictionDate: Date?
    @State private var cachedPointsByDistance: [PredictionDistance: [PredictionTrendPoint]]

    init(runs: [RunningWorkout]) {
        self.runs = runs
        _cachedPointsByDistance = State(initialValue: Self.buildPointCache(for: runs))
    }

    private var points: [PredictionTrendPoint] {
        cachedPointsByDistance[selectedDistance] ?? []
    }

    private var latestPoint: PredictionTrendPoint? { points.last }
    private var bestPoint: PredictionTrendPoint? { points.min(by: { $0.seconds < $1.seconds }) }
    private var focusedPoint: PredictionTrendPoint? {
        guard let selectedPredictionDate else { return latestPoint }
        return points.min {
            abs($0.date.timeIntervalSince(selectedPredictionDate)) < abs($1.date.timeIntervalSince(selectedPredictionDate))
        }
    }
    private var deltaText: String {
        guard let first = points.first, let latestPoint else { return "-" }
        return formatSignedDuration(latestPoint.seconds - first.seconds)
    }
    private var heroSubtitle: String {
        guard let focusedPoint else {
            return L10n.tr("러닝이 더 쌓이면 거리별 예상 흐름이 자연스럽게 보일 거예요.")
        }
        return L10n.format(
            "%@까지의 최근 흐름을 반영했어요.",
            focusedPoint.date.formatted(date: .abbreviated, time: .omitted)
        )
    }

    private var pointBadgeText: String {
        points.isEmpty ? L10n.tr("데이터 준비 중") : L10n.format("%d개 포인트", points.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PredictionTrendHeroCard(
                    selectedDistance: selectedDistance,
                    subtitle: heroSubtitle,
                    badgeText: pointBadgeText,
                    latestText: latestPoint.map { formatDuration($0.seconds) } ?? "-",
                    bestText: bestPoint.map { formatDuration($0.seconds) } ?? "-",
                    changeText: deltaText
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("비교 거리"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))

                    Picker(L10n.tr("거리"), selection: $selectedDistance) {
                        ForEach(PredictionDistance.allCases) { distance in
                            Text(distance.label).tag(distance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Color(red: 0.95, green: 0.59, blue: 0.32))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color(red: 0.42, green: 0.76, blue: 1.0).opacity(0.1)
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
                    title: L10n.tr("예상 흐름"),
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: Color(red: 0.95, green: 0.59, blue: 0.32)
                ) {
                    if points.isEmpty {
                        Text(L10n.tr("추세를 계산할 러닝 데이터가 부족합니다."))
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        Chart(points) { point in
                            AreaMark(
                                x: .value("날짜", point.date),
                                y: .value("예상 기록", point.seconds)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.95, green: 0.59, blue: 0.32).opacity(0.28),
                                        Color(red: 0.42, green: 0.76, blue: 1.0).opacity(0.04)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("날짜", point.date),
                                y: .value("예상 기록", point.seconds)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.95, green: 0.59, blue: 0.32),
                                        Color(red: 0.42, green: 0.76, blue: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("날짜", point.date),
                                y: .value("예상 기록", point.seconds)
                            )
                            .foregroundStyle(Color.white.opacity(focusedPoint?.id == point.id ? 1 : 0.82))
                            .symbolSize(focusedPoint?.id == point.id ? 54 : 18)

                            if let focusedPoint, focusedPoint.id == point.id {
                                RuleMark(x: .value("선택", point.date))
                                    .foregroundStyle(Color.white.opacity(0.22))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .annotation(position: .top, spacing: 8, overflowResolution: .init(x: .fit, y: .fit)) {
                                        FeatureChartCallout(
                                            title: selectedDistance.label,
                                            value: formatDuration(point.seconds),
                                            detail: point.date.formatted(date: .abbreviated, time: .omitted),
                                            tint: Color(red: 0.95, green: 0.59, blue: 0.32)
                                        )
                                    }
                            }
                        }
                        .frame(height: 240)
                        .chartXSelection(value: $selectedPredictionDate)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                    .foregroundStyle(.white.opacity(0.08))
                                AxisValueLabel {
                                    if let seconds = value.as(Double.self) {
                                        Text(formatDuration(seconds))
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
                                .background(FeatureChartPlotBackground(tint: Color(red: 0.95, green: 0.59, blue: 0.32)))
                        }
                    }
                }

                Button {
                    showingMethod = true
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                        Text(L10n.tr("예측 기록 계산 방식 보기"))
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
                                        Color(red: 0.95, green: 0.59, blue: 0.32).opacity(0.12)
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
        .navigationTitle(L10n.tr("예상 기록"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: runsCacheKey) {
            rebuildPointCache()
        }
        .sheet(isPresented: $showingMethod) {
            PredictionMethodView()
        }
    }

    private var runsCacheKey: [UUID] {
        runs.map(\.id)
    }

    private func rebuildPointCache() {
        cachedPointsByDistance = Self.buildPointCache(for: runs)
        selectedPredictionDate = nil
    }

    private static func buildPointCache(for runs: [RunningWorkout]) -> [PredictionDistance: [PredictionTrendPoint]] {
        let sortedRuns = runs.sorted(by: { $0.startDate < $1.startDate })
        return Dictionary(
            uniqueKeysWithValues: PredictionDistance.allCases.map { distance in
                (distance, PredictionTrendPoint.build(for: distance, sortedRuns: sortedRuns))
            }
        )
    }
}

struct PredictionTrendHeroCard: View {
    let selectedDistance: PredictionDistance
    let subtitle: String
    let badgeText: String
    let latestText: String
    let bestText: String
    let changeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FeatureToneBadge(
                    text: L10n.tr("예상 기록"),
                    tint: Color(red: 0.95, green: 0.59, blue: 0.32),
                    foreground: Color(red: 1.0, green: 0.86, blue: 0.76)
                )

                Spacer()

                FeatureToneBadge(
                    text: badgeText,
                    tint: Color(red: 0.42, green: 0.76, blue: 1.0),
                    foreground: Color(red: 0.74, green: 0.90, blue: 1.0)
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.format("%@ 흐름", selectedDistance.label))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .vertical) {
                HStack(spacing: 10) {
                    FeatureMiniStatCard(title: L10n.tr("현재"), value: latestText, tint: Color(red: 0.42, green: 0.76, blue: 1.0))
                    FeatureMiniStatCard(title: L10n.tr("최고"), value: bestText, tint: Color(red: 0.29, green: 0.88, blue: 0.63))
                    FeatureMiniStatCard(title: L10n.tr("변화"), value: changeText, tint: Color(red: 0.95, green: 0.59, blue: 0.32))
                }

                VStack(spacing: 10) {
                    FeatureMiniStatCard(title: L10n.tr("현재"), value: latestText, tint: Color(red: 0.42, green: 0.76, blue: 1.0))
                    FeatureMiniStatCard(title: L10n.tr("최고"), value: bestText, tint: Color(red: 0.29, green: 0.88, blue: 0.63))
                    FeatureMiniStatCard(title: L10n.tr("변화"), value: changeText, tint: Color(red: 0.95, green: 0.59, blue: 0.32))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.17, blue: 0.27),
                            Color(red: 0.95, green: 0.59, blue: 0.32).opacity(0.16),
                            Color(red: 0.42, green: 0.76, blue: 1.0).opacity(0.14)
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

// 5K/10K/하프/풀 거리 필터를 정의한다.
enum PredictionDistance: String, CaseIterable, Identifiable {
    case fiveK
    case tenK
    case half
    case marathon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fiveK: return "5K"
        case .tenK: return "10K"
        case .half: return L10n.tr("하프")
        case .marathon: return L10n.tr("풀")
        }
    }

    var targetMeters: Double {
        switch self {
        case .fiveK: return 5_000
        case .tenK: return 10_000
        case .half: return 21_097.5
        case .marathon: return 42_195
        }
    }
}

// 예측 추세 차트에서 한 점은 특정 날짜의 최적 예측값을 뜻한다.
struct PredictionTrendPoint: Identifiable, Equatable {
    let date: Date
    let seconds: Double

    var id: Date { date }

    static func build(for distance: PredictionDistance, runs: [RunningWorkout]) -> [PredictionTrendPoint] {
        build(
            for: distance,
            sortedRuns: runs.sorted(by: { $0.startDate < $1.startDate })
        )
    }

    static func build(for distance: PredictionDistance, sortedRuns: [RunningWorkout]) -> [PredictionTrendPoint] {
        var points: [PredictionTrendPoint] = []
        for run in sortedRuns {
            guard let predictedSeconds = PredictionModel.predictedSeconds(
                for: distance.targetMeters,
                from: sortedRuns,
                referenceDate: run.startDate
            ) else { continue }

            points.append(PredictionTrendPoint(date: run.startDate, seconds: predictedSeconds))
        }
        return points
    }
}

// 신발 탭은 등록된 러닝화와 누적 사용량을 관리한다.
struct MileageBreakdownView: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    @State private var selectedRange: MileageHistoryRange = .currentYear

    private var summary: MileageRangeSummary {
        viewModel.mileageSummary(for: selectedRange)
    }

    private var monthlyMileage: [MileagePeriod] {
        viewModel.mileageMonthlyPeriods(for: selectedRange)
    }

    private var yearlyMileage: [MileagePeriod] {
        viewModel.mileageYearlyPeriods(for: selectedRange)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("범위")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))

                    Picker("마일리지 범위", selection: $selectedRange) {
                        ForEach(MileageHistoryRange.allCases) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SummaryCard(
                        title: "누적 거리",
                        value: formatKilometers(summary.totalDistanceKilometers),
                        detail: L10n.format("%d회 러닝", summary.runCount)
                    )
                    SummaryCard(
                        title: "데이터 범위",
                        value: selectedRange.label,
                        detail: summary.isFullyLoaded ? "선택 범위 반영 완료" : "선택 범위 확장 중"
                    )
                }

                DetailSection(title: "불러오는 범위") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(summary.helperText)
                            .foregroundStyle(.white.opacity(0.78))

                        if selectedRange != .currentYear && viewModel.isPreparingMileageHistory {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(.white)
                                Text("과거 마일리지 데이터를 불러오는 중")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                            }
                        }
                    }
                }

                MileageSection(title: "월별 마일리지", periods: monthlyMileage)
                MileageSection(title: "연별 마일리지", periods: yearlyMileage)
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.14, blue: 0.20),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("마일리지")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedRange) {
            await viewModel.prepareMileageHistory(for: selectedRange)
        }
    }
}

// 월간/연간 기간 카드 목록을 같은 컴포넌트로 재사용한다.
struct MileageSection: View {
    let title: String
    let periods: [MileagePeriod]

    var body: some View {
        DetailSection(title: title) {
            if periods.isEmpty {
                Text("불러온 러닝 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(spacing: 10) {
                    ForEach(periods) { period in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(period.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(period.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            Text(period.distanceText)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
