import Charts
import MapKit
import SwiftUI

struct RunDetailView: View {
    let run: RunningWorkout
    let personalRecordAchievements: [PersonalRecordDistance]
    @EnvironmentObject private var workoutsViewModel: RunningWorkoutsViewModel
    @StateObject private var viewModel: RunDetailViewModel
    @State private var showingShareComposer = false

    init(
        run: RunningWorkout,
        personalRecordAchievements: [PersonalRecordDistance] = [],
        initialDebugScenario: RunDetailViewModel.DebugScenario? = nil
    ) {
        self.run = run
        self.personalRecordAchievements = personalRecordAchievements
        _viewModel = StateObject(wrappedValue: RunDetailViewModel(run: run, initialScenario: initialDebugScenario))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if !displayedPersonalRecordAchievements.isEmpty {
                    RunPersonalRecordBanner(achievements: displayedPersonalRecordAchievements)
                }

                RunOverviewMetricsSection(run: run, summary: displayedSummary)

                if run.isDemoWorkout {
                    DemoScenarioPanel(viewModel: viewModel)
                }

                switch viewModel.state {
                case .idle, .loading:
                    DetailSection(title: "경로", systemImage: "map", tint: Color(red: 0.35, green: 0.72, blue: 1.0)) {
                        ProgressView("상세 데이터를 불러오는 중")
                            .tint(.white)
                            .foregroundStyle(.white)
                    }

                case .failed(let message):
                    DetailSection(title: "상세 데이터를 불러오지 못했습니다", tint: Color(red: 0.92, green: 0.46, blue: 0.44)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(message)
                                .foregroundStyle(.white.opacity(0.72))
                            Button("다시 시도") {
                                Task {
                                    await viewModel.load()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                case .loaded(let detail):
                    RunRouteSection(detail: detail, isLoadingSupplementary: viewModel.isLoadingSupplementary)
                    HeartRateZoneSection(detail: detail, isLoadingSupplementary: viewModel.isLoadingSupplementary)
                    PerformanceChartSection(run: run, detail: detail)
                    RunSplitSection(detail: detail)
                    RunGearSection(run: run)
                    RunDataSourceSection(run: run)
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if loadedDetail != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingShareComposer = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .sheet(isPresented: $showingShareComposer) {
            if let loadedDetail {
                RunShareComposerView(
                    run: run,
                    detail: loadedDetail,
                    summary: loadedDetail.summaryMetrics.mergingMissingValues(from: viewModel.cachedSummary)
                )
            }
        }
    }

    private var loadedDetail: RunDetail? {
        guard case .loaded(let detail) = viewModel.state else { return nil }
        return detail
    }

    private var displayedSummary: RunSummaryMetrics? {
        loadedDetail?.summaryMetrics.mergingMissingValues(from: viewModel.cachedSummary) ?? viewModel.cachedSummary
    }

    private var displayedPersonalRecordAchievements: [PersonalRecordDistance] {
        let explicitAchievements = Set(personalRecordAchievements)
        let liveAchievements = Set(workoutsViewModel.personalRecordAchievements(for: run))
        let inferredAchievements = Set(loadedDetail.map(inferredPersonalRecordAchievements(from:)) ?? [])
        let allAchievements = explicitAchievements
            .union(liveAchievements)
            .union(inferredAchievements)

        return PersonalRecordDistance.allCases.filter { allAchievements.contains($0) }
    }

    private func inferredPersonalRecordAchievements(from detail: RunDetail) -> [PersonalRecordDistance] {
        let historyMatches = workoutsViewModel.personalRecordHistory.compactMap { entry -> PersonalRecordDistance? in
            guard let duration = bestPersonalRecordDuration(for: entry.distance.meters, in: detail.distanceTimeline) else {
                return nil
            }

            if abs(entry.date.timeIntervalSince(run.startDate)) < 1 || abs(duration - entry.duration) < 0.5 {
                return entry.distance
            }

            return nil
        }

        let currentRecordMatches = workoutsViewModel.personalRecords.compactMap { record -> PersonalRecordDistance? in
            guard let targetDuration = record.duration else { return nil }
            guard let duration = bestPersonalRecordDuration(for: record.distance.meters, in: detail.distanceTimeline) else {
                return nil
            }

            if let recordDate = record.date, abs(recordDate.timeIntervalSince(run.startDate)) < 1 {
                return record.distance
            }

            if abs(duration - targetDuration) < 0.5 {
                return record.distance
            }

            return nil
        }

        let matchedDistances = Set(historyMatches + currentRecordMatches)
        return PersonalRecordDistance.allCases.filter { matchedDistances.contains($0) }
    }
}

private func bestPersonalRecordDuration(
    for targetDistance: Double,
    in timeline: [DistanceTimelinePoint]
) -> TimeInterval? {
    guard timeline.count > 1, let lastDistance = timeline.last?.distanceMeters, lastDistance >= targetDistance else {
        return nil
    }

    var best: TimeInterval?
    var lowerIndex = 0

    for endIndex in timeline.indices {
        let endPoint = timeline[endIndex]
        guard endPoint.distanceMeters >= targetDistance else { continue }

        let startDistance = endPoint.distanceMeters - targetDistance
        while lowerIndex + 1 < timeline.count, timeline[lowerIndex + 1].distanceMeters < startDistance {
            lowerIndex += 1
        }

        let startElapsed = interpolatedPersonalRecordElapsed(
            for: startDistance,
            in: timeline,
            lowerIndex: lowerIndex
        )
        let duration = endPoint.elapsed - startElapsed
        guard duration > 0 else { continue }

        if best == nil || duration < (best ?? .greatestFiniteMagnitude) {
            best = duration
        }
    }

    return best
}

private func interpolatedPersonalRecordElapsed(
    for distance: Double,
    in timeline: [DistanceTimelinePoint],
    lowerIndex: Int
) -> TimeInterval {
    let clampedIndex = min(max(lowerIndex, 0), timeline.count - 1)
    let lowerPoint = timeline[clampedIndex]
    guard clampedIndex + 1 < timeline.count else { return lowerPoint.elapsed }

    let upperPoint = timeline[clampedIndex + 1]
    let distanceSpan = upperPoint.distanceMeters - lowerPoint.distanceMeters
    guard distanceSpan > 0 else { return upperPoint.elapsed }

    let ratio = (distance - lowerPoint.distanceMeters) / distanceSpan
    let clampedRatio = min(max(ratio, 0), 1)
    return lowerPoint.elapsed + (upperPoint.elapsed - lowerPoint.elapsed) * clampedRatio
}

struct PredictionMethodView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.tr("현재 예측 기록은 최근 120일 안에서 목표 거리와 충분히 가까운 러닝만 골라 계산합니다."))
                    Text(L10n.tr("각 러닝에 Riegel 공식을 적용한 뒤, 너무 낙관적인 한 번의 기록 대신 상위 후보들의 중앙값에 가까운 값을 사용합니다."))
                    Text(L10n.tr("공식: 예측시간 = 기록시간 × (목표거리 / 기록거리)^1.06"))
                    Text(PredictionModel.eligibilitySummaryText)
                    Text(L10n.tr("정확한 레이스 예측이라기보다, 최근 러닝 폼을 빠르게 보는 참고값으로 보는 편이 맞습니다."))
                }
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle(L10n.tr("예측 방식"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("닫기")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RunDetailPreviewContainer: View {
    let scenario: RunDetailViewModel.DebugScenario

    @StateObject private var workoutsViewModel = RunningWorkoutsViewModel()
    @StateObject private var shoeStore = ShoeStore()

    var body: some View {
        NavigationStack {
            RunDetailView(
                run: .demoSample,
                initialDebugScenario: scenario
            )
        }
        .environmentObject(workoutsViewModel)
        .environmentObject(shoeStore)
        .preferredColorScheme(.dark)
    }
}

struct RunDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RunDetailPreviewContainer(scenario: .completeMetrics)
                .previewDisplayName("상세 기록 - 완전체")

            RunDetailPreviewContainer(scenario: .pausedWorkout)
                .previewDisplayName("상세 기록 - 일시정지 포함")

            RunDetailPreviewContainer(scenario: .missingRoute)
                .previewDisplayName("상세 기록 - 경로 없음")

            RunDetailPreviewContainer(scenario: .missingHeartRate)
                .previewDisplayName("상세 기록 - 심박 없음")
        }
    }
}
