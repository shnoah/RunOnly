import Charts
import MapKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RunningWorkoutsViewModel()
    @StateObject private var shoeStore = ShoeStore()

    var body: some View {
        TabView {
            HomeTabView(viewModel: viewModel)
                .environmentObject(shoeStore)
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            RecordTabView(viewModel: viewModel)
                .environmentObject(shoeStore)
                .tabItem {
                    Label("기록", systemImage: "list.bullet.rectangle")
                }

            ShoesTabView(runs: viewModel.allRuns)
                .environmentObject(shoeStore)
                .tabItem {
                    Label("신발", systemImage: "shoeprints.fill")
                }
        }
        .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
    }
}

private struct HomeTabView: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("러닝 데이터를 불러오는 중")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .empty:
                    StatusView(
                        title: "러닝 기록이 없습니다",
                        message: viewModel.showAppleWorkoutOnly
                            ? "Apple 운동 앱에서 기록된 러닝이 아직 보이지 않습니다."
                            : "애플워치나 iPhone의 Workout 앱에서 기록한 러닝이 아직 보이지 않습니다.",
                        buttonTitle: "새로고침"
                    ) {
                        Task {
                            await viewModel.load()
                        }
                    }

                case .failed(let message):
                    StatusView(
                        title: "불러오기에 실패했습니다",
                        message: message,
                        buttonTitle: "다시 시도"
                    ) {
                        Task {
                            await viewModel.load()
                        }
                    }

                case .loaded(let runs):
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("RNL / Runing Never Lies v0.1")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .tracking(0.2)
                            .padding(.horizontal, 20)

                            DashboardHeader(
                                summary: viewModel.summary,
                                runs: runs,
                                vo2MaxSamples: viewModel.vo2MaxSamples,
                                monthlyMileage: viewModel.monthlyMileage,
                                yearlyMileage: viewModel.yearlyMileage,
                                showAppleWorkoutOnly: $viewModel.showAppleWorkoutOnly
                            ) {
                                viewModel.applyFilter()
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await viewModel.load()
        }
    }
}

private struct RecordTabView: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("러닝 데이터를 불러오는 중")
                        .tint(.white)
                        .foregroundStyle(.white)
                case .empty:
                    StatusView(
                        title: "러닝 기록이 없습니다",
                        message: "표시할 러닝 기록이 없습니다.",
                        buttonTitle: "새로고침"
                    ) {
                        Task {
                            await viewModel.load()
                        }
                    }
                case .failed(let message):
                    StatusView(
                        title: "불러오기에 실패했습니다",
                        message: message,
                        buttonTitle: "다시 시도"
                    ) {
                        Task {
                            await viewModel.load()
                        }
                    }
                case .loaded(let runs):
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(spacing: 14) {
                                ForEach(runs) { run in
                                    NavigationLink {
                                        RunDetailView(run: run)
                                    } label: {
                                        RunRowCard(run: run)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)

                            if viewModel.hasMoreHistory {
                                Button {
                                    Task {
                                        await viewModel.loadMoreHistory()
                                    }
                                } label: {
                                    HStack {
                                        if viewModel.isLoadingMoreHistory {
                                            ProgressView()
                                                .tint(.white)
                                        }
                                        Text(viewModel.isLoadingMoreHistory ? "이전 달 불러오는 중" : "이전 달 더 불러오기")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.white.opacity(0.08))
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .navigationTitle("기록")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await viewModel.load()
        }
    }
}

private struct MetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatusView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DashboardHeader: View {
    let summary: RunningSummary
    let runs: [RunningWorkout]
    let vo2MaxSamples: [VO2MaxSample]
    let monthlyMileage: [MileagePeriod]
    let yearlyMileage: [MileagePeriod]
    @Binding var showAppleWorkoutOnly: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink {
                MileageBreakdownView(monthlyMileage: monthlyMileage, yearlyMileage: yearlyMileage)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("이번달")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(summary.monthDistanceText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Label("올해 \(summary.yearDistanceText)", systemImage: "figure.run")
                        Label(summary.trainingStatus, systemImage: "waveform.path.ecg")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                SummaryCard(title: "트레이닝 상태", value: summary.trainingStatus, detail: summary.trainingStatusDetail)
                NavigationLink {
                    VO2MaxTrendView(samples: vo2MaxSamples)
                } label: {
                    SummaryCard(title: "VO2 Max", value: summary.vo2MaxText, detail: summary.vo2MaxDateText)
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                PredictionTrendView(runs: runs)
            } label: {
                PredictionSummaryCard(
                    predicted5KText: summary.predicted5KText,
                    predicted10KText: summary.predicted10KText,
                    predictedHalfText: summary.predictedHalfText,
                    predictedMarathonText: summary.predictedMarathonText
                )
            }
            .buttonStyle(.plain)

            Toggle(isOn: $showAppleWorkoutOnly) {
                Text("Apple 운동 앱 기록만 보기")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
            .onChange(of: showAppleWorkoutOnly) {
                onToggle()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

private struct CompactSelectionRow: View {
    let metrics: SelectedMetrics

    var body: some View {
        HStack(spacing: 10) {
            CompactMetricChip(title: "거리", value: metrics.distanceText, detail: metrics.elapsedText)
            CompactMetricChip(title: "페이스", value: metrics.paceText, detail: "선택 구간")
            CompactMetricChip(title: "심박", value: metrics.heartRateText, detail: "선택 시점")
        }
    }
}

private struct CompactAverageRow: View {
    let averagePaceText: String
    let averageHeartRateText: String

    var body: some View {
        HStack(spacing: 10) {
            CompactMetricChip(title: "평균 페이스", value: averagePaceText, detail: "러닝 전체")
            CompactMetricChip(title: "평균 심박", value: averageHeartRateText, detail: "러닝 전체")
        }
    }
}

private struct CompactMetricChip: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

private struct PredictionSummaryCard: View {
    let predicted5KText: String
    let predicted10KText: String
    let predictedHalfText: String
    let predictedMarathonText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("예상 기록")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PredictionCell(title: "5K", value: predicted5KText)
                PredictionCell(title: "10K", value: predicted10KText)
                PredictionCell(title: "하프", value: predictedHalfText)
                PredictionCell(title: "풀", value: predictedMarathonText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

private struct PredictionCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

private struct RunRowCard: View {
    let run: RunningWorkout
    @EnvironmentObject private var shoeStore: ShoeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(run.titleText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 10) {
                RunMetricPill(title: "거리", value: run.distanceText)
                RunMetricPill(title: "시간", value: run.durationText)
                RunMetricPill(title: "페이스", value: run.paceText)
            }

            Text(run.sourceName)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))

            if let shoe = shoeStore.shoe(for: run.id) {
                Label(shoe.displayName, systemImage: "shoeprints.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct RunMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

private struct RunDetailView: View {
    let run: RunningWorkout
    @StateObject private var viewModel: RunDetailViewModel
    @EnvironmentObject private var shoeStore: ShoeStore

    init(run: RunningWorkout) {
        self.run = run
        _viewModel = StateObject(wrappedValue: RunDetailViewModel(run: run))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(run.titleText)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(run.sourceName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                DebugScenarioPanel(viewModel: viewModel)

                HStack(spacing: 12) {
                    SummaryCard(title: "거리", value: run.distanceText, detail: "이번 러닝 총 거리")
                    SummaryCard(title: "시간", value: run.durationText, detail: "총 운동 시간")
                }

                HStack(spacing: 12) {
                    SummaryCard(title: "평균 페이스", value: run.paceText, detail: "러닝 전체 평균")
                    SummaryCard(title: "데이터 소스", value: run.sourceName, detail: run.sourceBundleIdentifier)
                }

                RunGearSection(run: run)

                switch viewModel.state {
                case .idle, .loading:
                    DetailSection(title: "러닝 경로") {
                        ProgressView("상세 데이터를 불러오는 중")
                            .tint(.white)
                            .foregroundStyle(.white)
                    }

                case .failed(let message):
                    DetailSection(title: "상세 데이터를 불러오지 못했습니다") {
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
                    RunRouteSection(detail: detail)
                    PerformanceChartSection(detail: detail)
                    RunSplitSection(detail: detail)
                    RunInsightSection(run: run, detail: detail)
                }
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
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}

private struct RunRouteSection: View {
    let detail: RunDetail

    var body: some View {
        DetailSection(title: "러닝 경로") {
            if detail.route.isEmpty {
                Text("이 러닝에는 경로 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                RouteMapView(points: detail.route)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

private struct PerformanceChartSection: View {
    let detail: RunDetail
    @State private var selectedDistance: Double?

    var body: some View {
        DetailSection(title: "심박 & 페이스") {
            if heartSeries.isEmpty && paceSeries.isEmpty {
                Text("그래프를 그릴 경로 또는 심박 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if let selectedMetrics {
                        CompactSelectionRow(metrics: selectedMetrics)
                    } else {
                        CompactAverageRow(
                            averagePaceText: averagePaceText,
                            averageHeartRateText: averageHeartRateText
                        )
                    }

                    VStack(spacing: 0) {
                        HStack {
                            Label("페이스", systemImage: "speedometer")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                            Spacer()
                        }
                        .padding(.bottom, 6)

                        PaceChartPlot(
                            selectedMetrics: selectedMetrics,
                            selectedPacePoint: selectedPacePoint,
                            selectedDistance: $selectedDistance,
                            paceSeries: paceSeries,
                            paceRange: paceRange,
                            strideValues: strideValues,
                            maxDistance: maxDistance
                        )
                        .frame(height: 144)

                        Divider()
                            .overlay(Color.white.opacity(0.08))
                            .padding(.vertical, 10)

                        HStack {
                            Label("심박", systemImage: "heart.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(red: 0.45, green: 0.95, blue: 0.76))
                            Spacer()
                        }
                        .padding(.bottom, 6)

                        HeartRateChartPlot(
                            selectedMetrics: selectedMetrics,
                            selectedHeartPoint: selectedHeartPoint,
                            selectedDistance: $selectedDistance,
                            heartSeries: heartSeries,
                            heartRateRange: heartRateRange,
                            strideValues: strideValues,
                            maxDistance: maxDistance
                        )
                        .frame(height: 144)
                    }

                    HStack {
                        Label("페이스", systemImage: "speedometer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("거리 (km)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        Label("심박", systemImage: "heart.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.45, green: 0.95, blue: 0.76))
                    }
                }
            }
        }
    }

    private var averageHeartRateText: String {
        guard !detail.heartRates.isEmpty else { return "-" }
        let avg = detail.heartRates.map(\.bpm).reduce(0, +) / Double(detail.heartRates.count)
        return avg.formatted(.number.precision(.fractionLength(0))) + " bpm"
    }

    private var averagePaceText: String {
        guard !detail.paceSamples.isEmpty else { return "-" }
        let avg = detail.paceSamples.map(\.secondsPerKilometer).reduce(0, +) / Double(detail.paceSamples.count)
        return formatPace(avg)
    }

    private var heartSeries: [HeartRateChartPoint] {
        HeartRateChartPoint.build(from: detail.heartRates)
    }

    private var paceSeries: [PaceChartPoint] {
        PaceChartPoint.build(from: detail.paceSamples)
    }

    private var selectedMetrics: SelectedMetrics? {
        guard let resolvedDistanceKilometers = snappedDistanceKilometers else { return nil }

        let resolvedDistanceMeters = resolvedDistanceKilometers * 1_000
        let routeStart = detail.route.first?.timestamp
        let nearestRoutePoint = detail.route.min(by: {
            abs($0.distanceMeters - resolvedDistanceMeters) < abs($1.distanceMeters - resolvedDistanceMeters)
        })

        let elapsed: TimeInterval
        if let routeStart, let nearestRoutePoint {
            elapsed = nearestRoutePoint.timestamp.timeIntervalSince(routeStart)
        } else if let routeStart, let selectedPacePoint {
            elapsed = detail.paceSamples.min(by: {
                abs($0.distanceMeters - selectedPacePoint.distanceMeters) < abs($1.distanceMeters - selectedPacePoint.distanceMeters)
            })?.date.timeIntervalSince(routeStart) ?? 0
        } else {
            elapsed = 0
        }

        return SelectedMetrics(
            distanceMeters: resolvedDistanceMeters,
            elapsed: elapsed,
            paceSecondsPerKilometer: selectedPacePoint?.secondsPerKilometer,
            heartRate: selectedHeartPoint?.bpm
        )
    }

    private var requestedDistanceKilometers: Double? {
        selectedDistance
            ?? paceSeries.first?.distanceKilometers
            ?? heartSeries.first?.distanceKilometers
    }

    private var snappedDistanceKilometers: Double? {
        guard let requestedDistanceKilometers else { return nil }
        let nearestPaceDistance = paceSeries.min(by: {
            abs($0.distanceKilometers - requestedDistanceKilometers) < abs($1.distanceKilometers - requestedDistanceKilometers)
        })?.distanceKilometers
        let nearestHeartDistance = heartSeries.min(by: {
            abs($0.distanceKilometers - requestedDistanceKilometers) < abs($1.distanceKilometers - requestedDistanceKilometers)
        })?.distanceKilometers

        return nearestPaceDistance ?? nearestHeartDistance ?? requestedDistanceKilometers
    }

    private var selectedPacePoint: PaceChartPoint? {
        guard let snappedDistanceKilometers else { return nil }
        return paceSeries.min(by: {
            abs($0.distanceKilometers - snappedDistanceKilometers) < abs($1.distanceKilometers - snappedDistanceKilometers)
        })
    }

    private var selectedHeartPoint: HeartRateChartPoint? {
        guard let snappedDistanceKilometers else { return nil }
        return heartSeries.min(by: {
            abs($0.distanceKilometers - snappedDistanceKilometers) < abs($1.distanceKilometers - snappedDistanceKilometers)
        })
    }

    private var heartRateRange: ClosedRange<Double> {
        let values = heartSeries.map(\.bpm)
        let minValue = max((values.min() ?? 110) - 12, 60)
        let maxValue = max((values.max() ?? 180) + 12, minValue + 20)
        return minValue...maxValue
    }

    private var paceRange: ClosedRange<Double> {
        let values = paceSeries.map(\.secondsPerKilometer)
        let minValue = values.min() ?? 300
        let maxValue = max(values.max() ?? 420, minValue + 1)
        return minValue...max(maxValue, minValue + 1)
    }

    private var strideValues: [Double] {
        guard maxDistance > 0 else { return [] }

        let stride: Double
        switch maxDistance {
        case ..<3: stride = 0.5
        case ..<10: stride = 1
        case ..<20: stride = 2
        default: stride = 5
        }

        let count = Int(ceil(maxDistance / stride))
        return Array(0...count).map { Double($0) * stride }
    }

    private var maxDistance: Double {
        max(
            paceSeries.last?.distanceKilometers ?? 0,
            heartSeries.last?.distanceKilometers ?? 0
        )
    }

    private func formatPace(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return (formatter.string(from: seconds) ?? "-") + "/km"
    }
}

private struct PaceChartPlot: View {
    let selectedMetrics: SelectedMetrics?
    let selectedPacePoint: PaceChartPoint?
    @Binding var selectedDistance: Double?
    let paceSeries: [PaceChartPoint]
    let paceRange: ClosedRange<Double>
    let strideValues: [Double]
    let maxDistance: Double

    var body: some View {
        Chart {
            ForEach(paceSeries) { sample in
                LineMark(
                    x: .value("거리", sample.distanceKilometers),
                    y: .value("페이스", displayedPace(sample.secondsPerKilometer))
                )
                .foregroundStyle(Color.orange.opacity(0.95))
                .lineStyle(StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            if let selectedMetrics {
                RuleMark(x: .value("선택", selectedPacePoint?.distanceKilometers ?? selectedMetrics.distanceKilometers))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.2))

                if let selectedPacePoint {
                    PointMark(
                        x: .value("선택 페이스", selectedPacePoint.distanceKilometers),
                        y: .value("선택 페이스값", displayedPace(selectedPacePoint.secondsPerKilometer))
                    )
                    .foregroundStyle(Color.orange)
                    .symbolSize(24)
                }
            }
        }
        .chartXSelection(value: $selectedDistance)
        .chartXScale(domain: 0...max(maxDistance, 0.1))
        .chartYScale(domain: 0...max(paceRange.upperBound - paceRange.lowerBound, 0.1))
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
        .chartXAxis {
            AxisMarks(values: strideValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.12))
            }
        }
        .chartYAxis(.hidden)
    }

    private func displayedPace(_ seconds: Double) -> Double {
        paceRange.upperBound - seconds
    }
}

private struct HeartRateChartPlot: View {
    let selectedMetrics: SelectedMetrics?
    let selectedHeartPoint: HeartRateChartPoint?
    @Binding var selectedDistance: Double?
    let heartSeries: [HeartRateChartPoint]
    let heartRateRange: ClosedRange<Double>
    let strideValues: [Double]
    let maxDistance: Double

    var body: some View {
        Chart {
            ForEach(heartSeries) { sample in
                LineMark(
                    x: .value("거리", sample.distanceKilometers),
                    y: .value("심박", sample.bpm)
                )
                .foregroundStyle(Color(red: 0.45, green: 0.95, blue: 0.76))
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            if let selectedMetrics {
                RuleMark(x: .value("선택", selectedHeartPoint?.distanceKilometers ?? selectedMetrics.distanceKilometers))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.2))

                if let selectedHeartPoint {
                    PointMark(
                        x: .value("선택 심박", selectedHeartPoint.distanceKilometers),
                        y: .value("선택 심박값", selectedHeartPoint.bpm)
                    )
                    .foregroundStyle(Color(red: 0.45, green: 0.95, blue: 0.76))
                    .symbolSize(24)
                }
            }
        }
        .chartXSelection(value: $selectedDistance)
        .chartXScale(domain: 0...max(maxDistance, 0.1))
        .chartYScale(domain: heartRateRange.lowerBound...heartRateRange.upperBound)
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
        .chartXAxis {
            AxisMarks(values: strideValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.12))
                AxisTick()
                    .foregroundStyle(.white.opacity(0.4))
                AxisValueLabel {
                    if let distance = value.as(Double.self) {
                        Text(distance.formatted(.number.precision(.fractionLength(strideValues.count > 8 ? 0 : 1))))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .chartYAxis(.hidden)
    }
}

private struct RunSplitSection: View {
    let detail: RunDetail

    var body: some View {
        DetailSection(title: "km 스플릿") {
            if detail.splits.isEmpty {
                Text("스플릿을 계산할 경로 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(spacing: 10) {
                    ForEach(detail.splits) { split in
                        SplitBarRow(split: split, fastestPace: fastestPace)
                    }
                }
            }
        }
    }

    private var fastestPace: Double {
        detail.splits.map(\.paceSecondsPerKilometer).min() ?? 1
    }
}

private struct RunInsightSection: View {
    let run: RunningWorkout
    let detail: RunDetail

    var body: some View {
        DetailSection(title: "러닝 인사이트") {
            HStack(spacing: 12) {
                SummaryCard(
                    title: "km당 효율",
                    value: efficiencyText,
                    detail: "1km 기준 소요 시간"
                )
                SummaryCard(
                    title: "경로 포인트",
                    value: "\(detail.route.count)",
                    detail: "지도에 표시된 위치 수"
                )
            }
        }
    }

    private var efficiencyText: String {
        run.paceText
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

private struct SplitBarRow: View {
    let split: RunSplit
    let fastestPace: Double

    var body: some View {
        HStack(spacing: 12) {
            Text(split.titleText)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 54, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(Color(red: 0.30, green: 0.58, blue: 0.95))
                        .frame(width: barWidth(in: proxy.size.width))
                }
            }
            .frame(height: 18)

            VStack(alignment: .trailing, spacing: 2) {
                Text(split.paceText)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(split.durationText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(width: 86, alignment: .trailing)
            .monospacedDigit()
        }
    }

    private func barWidth(in totalWidth: CGFloat) -> CGFloat {
        let ratio = fastestPace / max(split.paceSecondsPerKilometer, fastestPace)
        let adjusted = 0.28 + (ratio * 0.72)
        return totalWidth * adjusted
    }
}

private struct RouteMapView: View {
    let points: [RunRoutePoint]
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if let start = points.first {
                Annotation("Start", coordinate: start.coordinate) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                }
            }

            if let end = points.last {
                Annotation("End", coordinate: end.coordinate) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                }
            }

            MapPolyline(coordinates: points.map(\.coordinate))
                .stroke(Color(red: 0.29, green: 0.88, blue: 0.63), lineWidth: 5)
        }
        .mapStyle(.standard(elevation: .flat))
        .onAppear {
            position = .rect(mapRect)
        }
    }

    private var mapRect: MKMapRect {
        let mapPoints = points.map { MKMapPoint($0.coordinate) }
        guard let first = mapPoints.first else { return .world }

        return mapPoints.dropFirst().reduce(
            MKMapRect(origin: first, size: MKMapSize(width: 0, height: 0))
        ) { partialResult, point in
            partialResult.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
    }
}

private extension RunRoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct PaceChartPoint: Identifiable {
    let id: Double
    let distanceMeters: Double
    let distanceKilometers: Double
    let secondsPerKilometer: Double

    init(distanceMeters: Double, secondsPerKilometer: Double) {
        self.id = distanceMeters
        self.distanceMeters = distanceMeters
        self.distanceKilometers = distanceMeters / 1_000
        self.secondsPerKilometer = secondsPerKilometer
    }

    static func build(from samples: [PaceSample]) -> [PaceChartPoint] {
        let bucketSize: Double = 200
        let grouped = Dictionary(grouping: samples) { Int($0.distanceMeters / bucketSize) }

        var results: [PaceChartPoint] = []
        for bucket in grouped.keys.sorted() {
            guard let bucketSamples = grouped[bucket], !bucketSamples.isEmpty else { continue }
            let distance = bucketSamples[bucketSamples.count / 2].distanceMeters
            let averagePace = bucketSamples.map(\.secondsPerKilometer).reduce(0, +) / Double(bucketSamples.count)
            results.append(PaceChartPoint(distanceMeters: distance, secondsPerKilometer: averagePace))
        }

        return movingAverage(points: results, radius: 1)
    }

    private static func movingAverage(points: [PaceChartPoint], radius: Int) -> [PaceChartPoint] {
        guard !points.isEmpty else { return [] }

        return points.indices.map { index in
            let start = max(0, index - radius)
            let end = min(points.count - 1, index + radius)
            let window = points[start...end]
            let averagePace = window.map(\.secondsPerKilometer).reduce(0, +) / Double(window.count)
            return PaceChartPoint(distanceMeters: points[index].distanceMeters, secondsPerKilometer: averagePace)
        }
    }
}

private struct HeartRateChartPoint: Identifiable {
    let id: Double
    let distanceMeters: Double
    let distanceKilometers: Double
    let bpm: Double

    init(distanceMeters: Double, bpm: Double) {
        self.id = distanceMeters
        self.distanceMeters = distanceMeters
        self.distanceKilometers = distanceMeters / 1_000
        self.bpm = bpm
    }

    static func build(from samples: [HeartRateSample]) -> [HeartRateChartPoint] {
        let bucketSize: Double = 200
        let normalized = samples.compactMap { sample -> HeartRateChartPoint? in
            guard let distanceMeters = sample.distanceMeters else { return nil }
            return HeartRateChartPoint(distanceMeters: distanceMeters, bpm: sample.bpm)
        }
        let grouped = Dictionary(grouping: normalized) { Int($0.distanceMeters / bucketSize) }

        var results: [HeartRateChartPoint] = []
        for bucket in grouped.keys.sorted() {
            guard let bucketSamples = grouped[bucket], !bucketSamples.isEmpty else { continue }
            let distance = bucketSamples[bucketSamples.count / 2].distanceMeters
            let averageHeartRate = bucketSamples.map(\.bpm).reduce(0, +) / Double(bucketSamples.count)
            results.append(HeartRateChartPoint(distanceMeters: distance, bpm: averageHeartRate))
        }

        return movingAverage(points: results, radius: 1)
    }

    private static func movingAverage(points: [HeartRateChartPoint], radius: Int) -> [HeartRateChartPoint] {
        guard !points.isEmpty else { return [] }

        return points.indices.map { index in
            let start = max(0, index - radius)
            let end = min(points.count - 1, index + radius)
            let window = points[start...end]
            let averageHeartRate = window.map(\.bpm).reduce(0, +) / Double(window.count)
            return HeartRateChartPoint(distanceMeters: points[index].distanceMeters, bpm: averageHeartRate)
        }
    }
}

private struct DebugScenarioPanel: View {
    @ObservedObject var viewModel: RunDetailViewModel

    var body: some View {
        Menu {
            Button("실데이터") {
                Task {
                    await viewModel.applyDebugScenario(.live)
                }
            }
            Button("빈 경로") {
                Task {
                    await viewModel.applyDebugScenario(.missingRoute)
                }
            }
            Button("빈 심박") {
                Task {
                    await viewModel.applyDebugScenario(.missingHeartRate)
                }
            }
            Button("빈 상세") {
                Task {
                    await viewModel.applyDebugScenario(.empty)
                }
            }
        } label: {
            Label("테스트 데이터", systemImage: "ladybug")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
        }
    }
}

private struct SelectedMetrics {
    let distanceMeters: Double
    let elapsed: TimeInterval
    let paceSecondsPerKilometer: Double?
    let heartRate: Double?

    var distanceKilometers: Double {
        distanceMeters / 1_000
    }

    var distanceText: String {
        distanceKilometers.formatted(.number.precision(.fractionLength(distanceKilometers < 10 ? 1 : 2))) + " km"
    }

    var elapsedText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: elapsed) ?? "-"
    }

    var paceText: String {
        guard let paceSecondsPerKilometer else { return "-" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return (formatter.string(from: paceSecondsPerKilometer) ?? "-") + "/km"
    }

    var heartRateText: String {
        guard let heartRate else { return "-" }
        return heartRate.formatted(.number.precision(.fractionLength(0))) + " bpm"
    }

    func paceScaledForChart(heartRateRange: ClosedRange<Double>, paceRange: ClosedRange<Double>) -> Double? {
        guard let paceSecondsPerKilometer else {
            return nil
        }

        let paceSpan = max(paceRange.upperBound - paceRange.lowerBound, 0.1)
        let ratio = (paceRange.upperBound - paceSecondsPerKilometer) / paceSpan
        return heartRateRange.lowerBound + ratio * (heartRateRange.upperBound - heartRateRange.lowerBound)
    }
}

private struct PredictionMethodView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("현재 예측 기록은 최근 120일 러닝 중 1km 이상 기록들을 기준으로 계산합니다.")
                    Text("각 러닝에 Riegel 공식을 적용합니다.")
                    Text("공식: 예측시간 = 기록시간 × (목표거리 / 기록거리)^1.06")
                    Text("5K, 10K, 하프, 풀 각각에 대해 계산한 뒤 가장 빠른 예측값을 보여줍니다.")
                    Text("정확한 레이스 예측이라기보다, 최근 러닝 폼을 빠르게 보는 참고값으로 보는 편이 맞습니다.")
                }
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))
                .padding(20)
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
            .navigationTitle("예측 방식")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RunGearSection: View {
    let run: RunningWorkout
    @EnvironmentObject private var shoeStore: ShoeStore

    var body: some View {
        DetailSection(title: "착용 신발") {
            if shoeStore.shoes.isEmpty {
                Text("신발 탭에서 러닝화를 추가하면 이 러닝에 연결할 수 있습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(shoeStore.shoe(for: run.id)?.displayName ?? "신발 미선택")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(shoeStore.shoe(for: run.id)?.brandModelText ?? "이 러닝에 어떤 신발을 신었는지 기록해두세요.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Menu {
                        Button("선택 해제") {
                            shoeStore.assign(nil, to: run.id)
                        }
                        ForEach(shoeStore.shoes) { shoe in
                            Button(shoe.displayName) {
                                shoeStore.assign(shoe.id, to: run.id)
                            }
                        }
                    } label: {
                        Text("선택")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                }
            }
        }
    }
}

private struct VO2MaxTrendView: View {
    let samples: [VO2MaxSample]
    @State private var selectedRange: VO2TrendRange = .oneYear

    private var filteredSamples: [VO2MaxSample] {
        selectedRange.filtered(samples)
    }

    private var latest: VO2MaxSample? { filteredSamples.last }
    private var best: VO2MaxSample? { filteredSamples.max(by: { $0.value < $1.value }) }
    private var changeText: String {
        guard let first = filteredSamples.first, let latest else { return "-" }
        return String(format: "%+.1f", latest.value - first.value)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("기간", selection: $selectedRange) {
                    ForEach(VO2TrendRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SummaryCard(title: "현재", value: latest.map { String(format: "%.1f", $0.value) } ?? "-", detail: latest.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? "데이터 없음")
                    SummaryCard(title: "최고", value: best.map { String(format: "%.1f", $0.value) } ?? "-", detail: best.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? "데이터 없음")
                    SummaryCard(title: "변화", value: changeText, detail: "\(selectedRange.label) 기준")
                }

                DetailSection(title: "VO2 Max 추세") {
                    if filteredSamples.isEmpty {
                        Text("VO2 Max 데이터가 없습니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        Chart(filteredSamples.indices, id: \.self) { index in
                            let sample = filteredSamples[index]
                            LineMark(
                                x: .value("날짜", sample.date),
                                y: .value("VO2 Max", sample.value)
                            )
                            .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("날짜", sample.date),
                                y: .value("VO2 Max", sample.value)
                            )
                            .foregroundStyle(Color.white)
                            .symbolSize(index == filteredSamples.count - 1 ? 46 : 18)
                        }
                        .frame(height: 220)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine().foregroundStyle(.white.opacity(0.12))
                                AxisValueLabel {
                                    if let number = value.as(Double.self) {
                                        Text(String(format: "%.1f", number))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) { _ in
                                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
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

private enum VO2TrendRange: String, CaseIterable, Identifiable {
    case sixMonths
    case oneYear
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sixMonths: return "6개월"
        case .oneYear: return "1년"
        case .all: return "전체"
        }
    }

    func filtered(_ samples: [VO2MaxSample]) -> [VO2MaxSample] {
        guard self != .all else { return samples }

        let days = self == .sixMonths ? -180 : -365
        let startDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? .distantPast
        return samples.filter { $0.date >= startDate }
    }
}

private struct PredictionTrendView: View {
    let runs: [RunningWorkout]
    @State private var selectedDistance: PredictionDistance = .fiveK
    @State private var showingMethod = false

    private var points: [PredictionTrendPoint] {
        PredictionTrendPoint.build(for: selectedDistance, runs: runs)
    }

    private var latestPoint: PredictionTrendPoint? { points.last }
    private var bestPoint: PredictionTrendPoint? { points.min(by: { $0.seconds < $1.seconds }) }
    private var deltaText: String {
        guard let first = points.first, let latestPoint else { return "-" }
        return formatSignedDuration(latestPoint.seconds - first.seconds)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("거리", selection: $selectedDistance) {
                    ForEach(PredictionDistance.allCases) { distance in
                        Text(distance.label).tag(distance)
                    }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SummaryCard(title: "현재 예상", value: latestPoint.map { formatDuration($0.seconds) } ?? "-", detail: selectedDistance.label)
                    SummaryCard(title: "최고 예상", value: bestPoint.map { formatDuration($0.seconds) } ?? "-", detail: bestPoint.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? "데이터 없음")
                    SummaryCard(title: "변화", value: deltaText, detail: "첫 포인트 대비")
                }

                DetailSection(title: "예상 기록 추세") {
                    if points.isEmpty {
                        Text("추세를 계산할 러닝 데이터가 부족합니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        Chart(points) { point in
                            LineMark(
                                x: .value("날짜", point.date),
                                y: .value("예상 기록", point.seconds)
                            )
                            .foregroundStyle(Color(red: 0.46, green: 0.66, blue: 0.98))
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("날짜", point.date),
                                y: .value("예상 기록", point.seconds)
                            )
                            .foregroundStyle(Color.white.opacity(0.9))
                            .symbolSize(point.id == latestPoint?.id ? 46 : 18)
                        }
                        .frame(height: 220)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine().foregroundStyle(.white.opacity(0.12))
                                AxisValueLabel {
                                    if let seconds = value.as(Double.self) {
                                        Text(formatDuration(seconds))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) { _ in
                                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                        }
                    }
                }

                Button {
                    showingMethod = true
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("예측 기록 계산 방식 보기")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("예상 기록")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMethod) {
            PredictionMethodView()
        }
    }
}

private enum PredictionDistance: String, CaseIterable, Identifiable {
    case fiveK
    case tenK
    case half
    case marathon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fiveK: return "5K"
        case .tenK: return "10K"
        case .half: return "하프"
        case .marathon: return "풀"
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

private struct PredictionTrendPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let seconds: Double

    static func build(for distance: PredictionDistance, runs: [RunningWorkout]) -> [PredictionTrendPoint] {
        let sortedRuns = runs
            .filter { $0.distanceInMeters >= 1_000 }
            .sorted(by: { $0.startDate < $1.startDate })

        var points: [PredictionTrendPoint] = []
        for run in sortedRuns {
            let windowStart = Calendar.current.date(byAdding: .day, value: -120, to: run.startDate) ?? .distantPast
            let candidates = sortedRuns.filter { $0.startDate >= windowStart && $0.startDate <= run.startDate }
            guard let predictedSeconds = candidates
                .map({ $0.duration * pow(distance.targetMeters / $0.distanceInMeters, 1.06) })
                .min()
            else { continue }

            points.append(PredictionTrendPoint(date: run.startDate, seconds: predictedSeconds))
        }
        return points
    }
}

private struct ShoesTabView: View {
    let runs: [RunningWorkout]
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingAddShoe = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if shoeStore.shoes.isEmpty {
                        DetailSection(title: "신발") {
                            Text("러닝화를 등록하면 신발별 누적 거리와 남은 수명을 볼 수 있습니다.")
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    } else {
                        VStack(spacing: 14) {
                            ForEach(shoeStore.shoes) { shoe in
                                NavigationLink {
                                    ShoeDetailView(shoe: shoe, runs: runs)
                                } label: {
                                    ShoeSummaryCard(
                                        shoe: shoe,
                                        distanceKilometers: shoeStore.distance(for: shoe.id, runs: runs),
                                        runCount: shoeStore.runCount(for: shoe.id)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("신발")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("추가") {
                        showingAddShoe = true
                    }
                }
            }
            .sheet(isPresented: $showingAddShoe) {
                AddShoeView()
                    .environmentObject(shoeStore)
            }
        }
    }
}

private struct ShoeSummaryCard: View {
    let shoe: RunningShoe
    let distanceKilometers: Double
    let runCount: Int

    private var totalKilometers: Double {
        shoe.startMileageKilometers + distanceKilometers
    }

    private var usageRatio: Double {
        min(totalKilometers / max(shoe.retirementKilometers, 1), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shoe.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(shoe.brandModelText)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.4))
            }

            HStack(spacing: 12) {
                RunMetricPill(title: "누적", value: formatKilometers(totalKilometers))
                RunMetricPill(title: "남은 거리", value: formatKilometers(max(shoe.retirementKilometers - totalKilometers, 0)))
                RunMetricPill(title: "러닝 수", value: "\(runCount)회")
            }

            ProgressView(value: usageRatio)
                .tint(usageRatio >= 0.8 ? .orange : Color(red: 0.29, green: 0.88, blue: 0.63))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct ShoeDetailView: View {
    let shoe: RunningShoe
    let runs: [RunningWorkout]
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingEditSheet = false

    private var currentShoe: RunningShoe {
        shoeStore.shoes.first(where: { $0.id == shoe.id }) ?? shoe
    }

    private var assignedRuns: [RunningWorkout] {
        shoeStore.runs(for: currentShoe.id, in: runs)
    }

    private var totalKilometers: Double {
        currentShoe.startMileageKilometers + assignedRuns.reduce(0) { $0 + $1.distanceInKilometers }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    SummaryCard(title: "누적 거리", value: formatKilometers(totalKilometers), detail: "시작 거리 포함")
                    SummaryCard(title: "목표 수명", value: formatKilometers(currentShoe.retirementKilometers), detail: currentShoe.brandModelText)
                }

                HStack(spacing: 12) {
                    SummaryCard(title: "남은 거리", value: formatKilometers(max(currentShoe.retirementKilometers - totalKilometers, 0)), detail: "교체까지 남은 거리")
                    SummaryCard(title: "착용 러닝", value: "\(assignedRuns.count)회", detail: "현재 불러온 러닝 기준")
                }

                DetailSection(title: "최근 착용 러닝") {
                    if assignedRuns.isEmpty {
                        Text("이 신발에 연결된 러닝이 없습니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(assignedRuns.prefix(10)) { run in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(run.titleText)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text(run.distanceText)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.55))
                                    }
                                    Spacer()
                                    Text(run.paceText)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle(currentShoe.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("수정") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddShoeView(existingShoe: currentShoe)
                .environmentObject(shoeStore)
        }
    }
}

private struct AddShoeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var shoeStore: ShoeStore

    let existingShoe: RunningShoe?

    @State private var nickname: String
    @State private var brand: String
    @State private var model: String
    @State private var startMileage: Double
    @State private var retirementMileage: Double

    init(existingShoe: RunningShoe? = nil) {
        self.existingShoe = existingShoe
        _nickname = State(initialValue: existingShoe?.nickname ?? "")
        _brand = State(initialValue: existingShoe?.brand ?? "")
        _model = State(initialValue: existingShoe?.model ?? "")
        _startMileage = State(initialValue: existingShoe?.startMileageKilometers ?? 0)
        _retirementMileage = State(initialValue: existingShoe?.retirementKilometers ?? 600)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("별칭", text: $nickname)
                    TextField("브랜드", text: $brand)
                    TextField("모델", text: $model)
                }

                Section("마일리지") {
                    TextField("시작 거리 (km)", value: $startMileage, format: .number)
                        .keyboardType(.decimalPad)
                    Text("단위는 km입니다. 이미 다른 앱이나 실제 사용으로 누적된 거리가 있다면 입력하고, 새 신발이면 0으로 두면 됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("목표 수명 거리 (km)", value: $retirementMileage, format: .number)
                        .keyboardType(.decimalPad)
                    Text("단위는 km입니다. 교체를 고려할 기준 거리이며, 보통 500~800km 범위에서 잡습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(existingShoe == nil ? "신발 추가" : "신발 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(existingShoe == nil ? "저장" : "완료") {
                        let updatedShoe = RunningShoe(
                            id: existingShoe?.id ?? UUID(),
                            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                            startMileageKilometers: max(startMileage, 0),
                            retirementKilometers: max(retirementMileage, 1),
                            createdAt: existingShoe?.createdAt ?? .now
                        )

                        if existingShoe == nil {
                            shoeStore.addShoe(updatedShoe)
                        } else {
                            shoeStore.updateShoe(updatedShoe)
                        }
                        dismiss()
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

@MainActor
final class ShoeStore: ObservableObject {
    @Published private(set) var shoes: [RunningShoe] = []
    @Published private(set) var assignments: [ShoeAssignmentRecord] = []

    private let shoesKey = "runonly.shoes"
    private let assignmentsKey = "runonly.shoeAssignments"

    init() {
        load()
    }

    func addShoe(_ shoe: RunningShoe) {
        shoes.insert(shoe, at: 0)
        save()
    }

    func updateShoe(_ shoe: RunningShoe) {
        guard let index = shoes.firstIndex(where: { $0.id == shoe.id }) else { return }
        shoes[index] = shoe
        save()
    }

    func shoe(for runID: UUID) -> RunningShoe? {
        guard let shoeID = assignments.first(where: { $0.runID == runID })?.shoeID else { return nil }
        return shoes.first(where: { $0.id == shoeID })
    }

    func assign(_ shoeID: UUID?, to runID: UUID) {
        assignments.removeAll { $0.runID == runID }
        if let shoeID {
            assignments.append(ShoeAssignmentRecord(runID: runID, shoeID: shoeID))
        }
        save()
    }

    func distance(for shoeID: UUID, runs allRuns: [RunningWorkout]) -> Double {
        self.runs(for: shoeID, in: allRuns).reduce(0) { $0 + $1.distanceInKilometers }
    }

    func runCount(for shoeID: UUID) -> Int {
        assignments.filter { $0.shoeID == shoeID }.count
    }

    func runs(for shoeID: UUID, in runs: [RunningWorkout]) -> [RunningWorkout] {
        let runIDs = assignments.filter { $0.shoeID == shoeID }.map(\.runID)
        return runs.filter { runIDs.contains($0.id) }.sorted(by: { $0.startDate > $1.startDate })
    }

    private func load() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: shoesKey),
           let decodedShoes = try? decoder.decode([RunningShoe].self, from: data) {
            shoes = decodedShoes
        }

        if let data = UserDefaults.standard.data(forKey: assignmentsKey),
           let decodedAssignments = try? decoder.decode([ShoeAssignmentRecord].self, from: data) {
            assignments = decodedAssignments
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(shoes) {
            UserDefaults.standard.set(data, forKey: shoesKey)
        }
        if let data = try? encoder.encode(assignments) {
            UserDefaults.standard.set(data, forKey: assignmentsKey)
        }
    }
}

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.14, blue: 0.20),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct MileageBreakdownView: View {
    let monthlyMileage: [MileagePeriod]
    let yearlyMileage: [MileagePeriod]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
    }
}

private struct MileageSection: View {
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

private func formatKilometers(_ kilometers: Double) -> String {
    kilometers.formatted(.number.precision(.fractionLength(1))) + " km"
}

private func formatDuration(_ seconds: Double) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = [.pad]
    return formatter.string(from: seconds) ?? "-"
}

private func formatSignedDuration(_ seconds: Double) -> String {
    let sign = seconds > 0 ? "+" : seconds < 0 ? "-" : ""
    return sign + formatDuration(abs(seconds))
}

#Preview {
    ContentView()
}
