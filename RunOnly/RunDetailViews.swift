import Charts
import MapKit
import SwiftUI

struct RunDetailView: View {
    let run: RunningWorkout
    let personalRecordAchievements: [PersonalRecordDistance]
    @EnvironmentObject private var workoutsViewModel: RunningWorkoutsViewModel
    @EnvironmentObject private var runNoteStore: RunNoteStore
    @StateObject private var viewModel: RunDetailViewModel
    @State private var showingShareComposer = false
    @State private var showingNoteEditor = false

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

                RunOverviewMetricsSection(
                    run: run,
                    summary: displayedSummary,
                    activeDuration: loadedDetail?.activeDuration
                )
                RunNoteSection(run: run) {
                    showingNoteEditor = true
                }

                if run.isDemoWorkout {
                    DemoScenarioPanel(viewModel: viewModel)
                }

                switch viewModel.state {
                case .idle, .loading:
                    RunDetailLoadingSection(
                        title: L10n.tr("흐름"),
                        systemImage: "chart.line.uptrend.xyaxis",
                        tint: Color(red: 0.95, green: 0.59, blue: 0.32),
                        message: L10n.tr("차트 데이터를 불러오는 중")
                    )
                    RunDetailLoadingSection(
                        title: L10n.tr("구간"),
                        systemImage: "flag.pattern.checkered",
                        tint: Color(red: 0.29, green: 0.88, blue: 0.63),
                        message: L10n.tr("구간 데이터를 계산하는 중")
                    )
                    HeartRateZoneSection(detail: .empty, loadState: .loading)
                    RunRouteSection(detail: .empty, loadState: .loading)

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
                    PerformanceChartSection(run: run, detail: detail)
                    RunSplitSection(detail: detail)
                    HeartRateZoneSection(detail: detail, loadState: viewModel.heartRateZoneLoadState)
                    RunRouteSection(detail: detail, loadState: viewModel.routeLoadState)
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
        .sheet(isPresented: $showingNoteEditor) {
            RunNoteEditorView(run: run)
                .environmentObject(runNoteStore)
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
            guard PersonalRecordCalculator.bestDuration(
                for: entry.distance.meters,
                in: detail.distanceTimeline
            ) != nil else {
                return nil
            }

            if entry.workoutID == run.id || abs(entry.date.timeIntervalSince(run.startDate)) < 1 {
                return entry.distance
            }

            return nil
        }

        let currentRecordMatches = workoutsViewModel.personalRecords.compactMap { record -> PersonalRecordDistance? in
            guard record.duration != nil else { return nil }
            guard PersonalRecordCalculator.bestDuration(
                for: record.distance.meters,
                in: detail.distanceTimeline
            ) != nil else {
                return nil
            }

            if record.workoutID == run.id {
                return record.distance
            }

            if let recordDate = record.date, abs(recordDate.timeIntervalSince(run.startDate)) < 1 {
                return record.distance
            }

            return nil
        }

        let matchedDistances = Set(historyMatches + currentRecordMatches)
        return PersonalRecordDistance.allCases.filter { matchedDistances.contains($0) }
    }
}

private struct RunDetailLoadingSection: View {
    let title: String
    let systemImage: String
    let tint: Color
    let message: String

    var body: some View {
        DetailSection(title: title, systemImage: systemImage, tint: tint) {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                Text(message)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }
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
    @StateObject private var runNoteStore = RunNoteStore(loadFromDisk: false, persistsChanges: false)

    var body: some View {
        NavigationStack {
            RunDetailView(
                run: .demoSample,
                initialDebugScenario: scenario
            )
        }
        .environmentObject(workoutsViewModel)
        .environmentObject(shoeStore)
        .environmentObject(runNoteStore)
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
