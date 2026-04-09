import Charts
import MapKit
import SwiftUI

private struct RunPersonalRecordBanner: View {
    let achievements: [PersonalRecordDistance]

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var message: String {
        let labels = achievements.map(\.label)
        return L10n.format("축하합니다! %@ 새로운 최고 기록을 달성했습니다!", labels.joined(separator: ", "))
    }
}

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

private struct RunRouteSection: View {
    let detail: RunDetail
    let isLoadingSupplementary: Bool

    var body: some View {
        DetailSection(title: "경로", systemImage: "map", tint: Color(red: 0.35, green: 0.72, blue: 1.0)) {
            if detail.route.isEmpty, isLoadingSupplementary {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("경로 데이터를 불러오는 중")
                        .foregroundStyle(.white.opacity(0.72))
                }
            } else if detail.route.isEmpty {
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

private struct PerformanceChartInputKey: Hashable {
    let runID: UUID
    let runDistanceMeters: Double
    let distanceTimelineCount: Int
    let distanceTimelineLastMeters: Double
    let paceSampleCount: Int
    let paceSampleLastMeters: Double
    let heartRateCount: Int
    let heartRateLastMeters: Double
    let cadenceCount: Int
    let cadenceLastMeters: Double
    let routeCount: Int
    let routeLastMeters: Double

    init(run: RunningWorkout, detail: RunDetail) {
        runID = run.id
        runDistanceMeters = run.distanceInMeters
        distanceTimelineCount = detail.distanceTimeline.count
        distanceTimelineLastMeters = detail.distanceTimeline.last?.distanceMeters ?? 0
        paceSampleCount = detail.paceSamples.count
        paceSampleLastMeters = detail.paceSamples.last?.distanceMeters ?? 0
        heartRateCount = detail.heartRates.count
        heartRateLastMeters = detail.heartRates.last?.distanceMeters ?? 0
        cadenceCount = detail.runningMetrics.cadence.count
        cadenceLastMeters = detail.runningMetrics.cadence.last?.distanceMeters ?? 0
        routeCount = detail.route.count
        routeLastMeters = detail.route.last?.distanceMeters ?? 0
    }
}

private struct PerformanceChartData {
    let distanceTimeline: [DistanceTimelinePoint]
    let timelineDistances: [Double]
    let paceSeries: [PaceChartPoint]
    let paceDistances: [Double]
    let pacePlotPoints: [SimpleMetricChartPoint]
    let heartSeries: [HeartRateChartPoint]
    let heartDistances: [Double]
    let heartPlotPoints: [SimpleMetricChartPoint]
    let cadenceSeries: [SimpleMetricChartPoint]
    let cadenceDistances: [Double]
    let altitudeSeries: [SimpleMetricChartPoint]
    let altitudeDistances: [Double]
    let heartRateRange: ClosedRange<Double>
    let paceRange: ClosedRange<Double>
    let cadenceRange: ClosedRange<Double>
    let altitudeRange: ClosedRange<Double>
    let availableMetrics: [PerformanceChartMetric]
    let strideValues: [Double]
    let maxDistance: Double

    init(run: RunningWorkout, detail: RunDetail) {
        let sortedDistanceTimeline = detail.distanceTimeline.sorted(by: { $0.distanceMeters < $1.distanceMeters })
        let builtPaceSeries = PaceChartPoint.build(from: detail.paceSamples)
        let builtHeartSeries = HeartRateChartPoint.build(from: detail.heartRates)
        let builtCadenceSeries = detail.runningMetrics.cadence
            .compactMap { sample -> SimpleMetricChartPoint? in
                guard let distanceMeters = sample.distanceMeters else { return nil }
                return SimpleMetricChartPoint(
                    distanceKilometers: distanceMeters / 1_000,
                    value: sample.value,
                    segmentIndex: sample.segmentIndex
                )
            }
            .sorted(by: { $0.distanceKilometers < $1.distanceKilometers })
        let builtAltitudeSeries = detail.route
            .compactMap { point -> SimpleMetricChartPoint? in
                guard let altitudeMeters = point.altitudeMeters, altitudeMeters.isFinite else { return nil }
                return SimpleMetricChartPoint(
                    distanceKilometers: point.distanceMeters / 1_000,
                    value: altitudeMeters,
                    segmentIndex: nil
                )
            }
            .sorted(by: { $0.distanceKilometers < $1.distanceKilometers })
        let builtPacePlotPoints = builtPaceSeries.map {
            SimpleMetricChartPoint(
                distanceKilometers: $0.distanceKilometers,
                value: $0.secondsPerKilometer,
                segmentIndex: $0.segmentIndex
            )
        }
        let builtHeartPlotPoints = builtHeartSeries.map {
            SimpleMetricChartPoint(
                distanceKilometers: $0.distanceKilometers,
                value: $0.bpm,
                segmentIndex: $0.segmentIndex
            )
        }

        self.distanceTimeline = sortedDistanceTimeline
        timelineDistances = sortedDistanceTimeline.map(\.distanceMeters)
        self.paceSeries = builtPaceSeries
        paceDistances = builtPaceSeries.map(\.distanceKilometers)
        pacePlotPoints = builtPacePlotPoints
        self.heartSeries = builtHeartSeries
        heartDistances = builtHeartSeries.map(\.distanceKilometers)
        heartPlotPoints = builtHeartPlotPoints
        self.cadenceSeries = builtCadenceSeries
        cadenceDistances = builtCadenceSeries.map(\.distanceKilometers)
        self.altitudeSeries = builtAltitudeSeries
        altitudeDistances = builtAltitudeSeries.map(\.distanceKilometers)

        let heartValues = builtHeartSeries.map(\.bpm)
        let heartMinimum = max((heartValues.min() ?? 110) - 12, 60)
        let heartMaximum = max((heartValues.max() ?? 180) + 12, heartMinimum + 20)
        heartRateRange = heartMinimum...heartMaximum

        let paceValues = builtPaceSeries.map(\.secondsPerKilometer)
        let paceMinimum = paceValues.min() ?? 300
        let paceMaximum = max(paceValues.max() ?? 420, paceMinimum + 1)
        paceRange = paceMinimum...max(paceMaximum, paceMinimum + 1)

        cadenceRange = Self.metricRange(for: builtCadenceSeries.map(\.value), minimumPadding: 6)
        altitudeRange = Self.metricRange(for: builtAltitudeSeries.map(\.value), minimumPadding: 4)

        let builtMaxDistance = max(
            run.distanceInKilometers,
            (sortedDistanceTimeline.last?.distanceMeters ?? 0) / 1_000,
            builtPaceSeries.last?.distanceKilometers ?? 0,
            builtHeartSeries.last?.distanceKilometers ?? 0,
            builtCadenceSeries.last?.distanceKilometers ?? 0,
            builtAltitudeSeries.last?.distanceKilometers ?? 0
        )
        maxDistance = builtMaxDistance
        strideValues = Self.makeStrideValues(maxDistance: builtMaxDistance)

        availableMetrics = PerformanceChartMetric.allCases.filter { metric in
            switch metric {
            case .pace:
                return !builtPacePlotPoints.isEmpty
            case .heartRate:
                return !builtHeartPlotPoints.isEmpty
            case .cadence:
                return !builtCadenceSeries.isEmpty
            case .altitude:
                return !builtAltitudeSeries.isEmpty
            }
        }
    }

    func nearestTimelinePoint(toMeters distanceMeters: Double) -> DistanceTimelinePoint? {
        guard let index = Self.nearestIndex(for: distanceMeters, in: timelineDistances) else { return nil }
        return distanceTimeline[index]
    }

    func nearestPacePoint(toKilometers distanceKilometers: Double) -> PaceChartPoint? {
        guard let index = Self.nearestIndex(for: distanceKilometers, in: paceDistances) else { return nil }
        return paceSeries[index]
    }

    func nearestHeartPoint(toKilometers distanceKilometers: Double) -> HeartRateChartPoint? {
        guard let index = Self.nearestIndex(for: distanceKilometers, in: heartDistances) else { return nil }
        return heartSeries[index]
    }

    func nearestCadencePoint(toKilometers distanceKilometers: Double) -> SimpleMetricChartPoint? {
        guard let index = Self.nearestIndex(for: distanceKilometers, in: cadenceDistances) else { return nil }
        return cadenceSeries[index]
    }

    func nearestAltitudePoint(toKilometers distanceKilometers: Double) -> SimpleMetricChartPoint? {
        guard let index = Self.nearestIndex(for: distanceKilometers, in: altitudeDistances) else { return nil }
        return altitudeSeries[index]
    }

    func series(for metric: PerformanceChartMetric) -> [SimpleMetricChartPoint] {
        switch metric {
        case .pace:
            return pacePlotPoints
        case .heartRate:
            return heartPlotPoints
        case .cadence:
            return cadenceSeries
        case .altitude:
            return altitudeSeries
        }
    }

    func nearestSeriesPoint(for metric: PerformanceChartMetric, toKilometers distanceKilometers: Double) -> SimpleMetricChartPoint? {
        switch metric {
        case .pace:
            guard let point = nearestPacePoint(toKilometers: distanceKilometers) else { return nil }
            return SimpleMetricChartPoint(
                distanceKilometers: point.distanceKilometers,
                value: point.secondsPerKilometer,
                segmentIndex: point.segmentIndex
            )
        case .heartRate:
            guard let point = nearestHeartPoint(toKilometers: distanceKilometers) else { return nil }
            return SimpleMetricChartPoint(
                distanceKilometers: point.distanceKilometers,
                value: point.bpm,
                segmentIndex: point.segmentIndex
            )
        case .cadence:
            return nearestCadencePoint(toKilometers: distanceKilometers)
        case .altitude:
            return nearestAltitudePoint(toKilometers: distanceKilometers)
        }
    }

    func valueRange(for metric: PerformanceChartMetric) -> ClosedRange<Double> {
        switch metric {
        case .pace:
            return paceRange
        case .heartRate:
            return heartRateRange
        case .cadence:
            return cadenceRange
        case .altitude:
            return altitudeRange
        }
    }

    private static func metricRange(for values: [Double], minimumPadding: Double) -> ClosedRange<Double> {
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? minValue + minimumPadding
        let padding = max((maxValue - minValue) * 0.12, minimumPadding)
        return (minValue - padding)...(maxValue + padding)
    }

    private static func makeStrideValues(maxDistance: Double) -> [Double] {
        guard maxDistance > 0 else { return [] }

        let stride: Double
        switch maxDistance {
        case ..<3: stride = 0.5
        case ..<10: stride = 1
        case ..<20: stride = 2
        default: stride = 5
        }

        let count = Int(ceil(maxDistance / stride))
        var values = Array(0...count).map { Double($0) * stride }
        if let last = values.last, abs(last - maxDistance) > 0.001 {
            values.append(maxDistance)
        }
        return values
    }

    private static func nearestIndex(for target: Double, in distances: [Double]) -> Int? {
        guard !distances.isEmpty else { return nil }

        var lowerBound = 0
        var upperBound = distances.count

        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2
            if distances[middle] < target {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        if lowerBound == 0 {
            return 0
        }
        if lowerBound == distances.count {
            return distances.count - 1
        }

        let previousIndex = lowerBound - 1
        let nextIndex = lowerBound
        if abs(distances[previousIndex] - target) <= abs(distances[nextIndex] - target) {
            return previousIndex
        }
        return nextIndex
    }
}

private struct PerformanceChartSection: View {
    let run: RunningWorkout
    let detail: RunDetail
    @State private var selectedDistance: Double?
    @State private var selectedMetric: PerformanceChartMetric = .pace
    @State private var chartData: PerformanceChartData

    init(run: RunningWorkout, detail: RunDetail) {
        self.run = run
        self.detail = detail
        _chartData = State(initialValue: PerformanceChartData(run: run, detail: detail))
    }

    var body: some View {
        DetailSection(title: "흐름", systemImage: "chart.line.uptrend.xyaxis", tint: Color(red: 0.95, green: 0.59, blue: 0.32)) {
            if availableMetrics.isEmpty {
                Text("그래프를 그릴 경로 또는 심박 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    PerformanceMetricPicker(metrics: availableMetrics, selectedMetric: $selectedMetric)

                    HStack(alignment: .firstTextBaseline) {
                        Label(LocalizedStringKey(selectedMetric.title), systemImage: selectedMetric.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedMetric.tint)
                        Spacer()
                        Text(activeMetricHeadlineText)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 2)

                    RunMetricChartPlot(
                        metric: selectedMetric,
                        selectedDistance: $selectedDistance,
                        selectedPoint: activeSelectedPoint,
                        points: activeSeries,
                        valueRange: activeValueRange,
                        strideValues: strideValues,
                        maxDistance: maxDistance
                    )
                    .frame(height: 220)
                }
                .onAppear(perform: syncSelectedMetric)
                .onChange(of: chartInputKey) {
                    rebuildChartData()
                }
            }
        }
    }

    private var chartInputKey: PerformanceChartInputKey {
        PerformanceChartInputKey(run: run, detail: detail)
    }

    private var averageHeartRateText: String {
        guard !detail.heartRates.isEmpty else { return "-" }
        let avg = detail.heartRates.map(\.bpm).reduce(0, +) / Double(detail.heartRates.count)
        return RunDisplayFormatter.heartRate(avg) ?? "-"
    }

    private var averagePaceText: String {
        run.paceText
    }

    private var averageCadenceText: String? {
        let weightedCadence = detail.splits.reduce(into: (weighted: 0.0, duration: 0.0)) { partial, split in
            guard let cadence = split.averageCadence else { return }
            partial.weighted += cadence * split.duration
            partial.duration += split.duration
        }

        if weightedCadence.duration > 0 {
            let average = weightedCadence.weighted / weightedCadence.duration
            return RunDisplayFormatter.cadence(average)
        }

        guard !detail.runningMetrics.cadence.isEmpty else { return nil }
        let average = detail.runningMetrics.cadence.map(\.value).reduce(0, +) / Double(detail.runningMetrics.cadence.count)
        return RunDisplayFormatter.cadence(average)
    }

    private var availableMetrics: [PerformanceChartMetric] {
        chartData.availableMetrics
    }

    private var snappedDistanceKilometers: Double? {
        guard let selectedDistance else { return nil }
        return min(max(selectedDistance, 0), maxDistance)
    }

    private var selectedMetrics: SelectedMetrics? {
        guard let resolvedDistanceKilometers = snappedDistanceKilometers else { return nil }

        let resolvedDistanceMeters = resolvedDistanceKilometers * 1_000
        let nearestDistancePoint = chartData.nearestTimelinePoint(toMeters: resolvedDistanceMeters)

        return SelectedMetrics(
            distanceMeters: resolvedDistanceMeters,
            elapsed: nearestDistancePoint?.elapsed ?? 0,
            paceSecondsPerKilometer: chartData.nearestPacePoint(toKilometers: resolvedDistanceKilometers)?.secondsPerKilometer,
            heartRate: chartData.nearestHeartPoint(toKilometers: resolvedDistanceKilometers)?.bpm,
            cadence: chartData.nearestCadencePoint(toKilometers: resolvedDistanceKilometers)?.value,
            altitudeMeters: chartData.nearestAltitudePoint(toKilometers: resolvedDistanceKilometers)?.value
        )
    }

    private var activeSeries: [SimpleMetricChartPoint] {
        chartData.series(for: selectedMetric)
    }

    private var activeSelectedPoint: SimpleMetricChartPoint? {
        guard let snappedDistanceKilometers else { return nil }
        return chartData.nearestSeriesPoint(for: selectedMetric, toKilometers: snappedDistanceKilometers)
    }

    private var activeValueRange: ClosedRange<Double> {
        chartData.valueRange(for: selectedMetric)
    }

    private var strideValues: [Double] {
        chartData.strideValues
    }

    private var maxDistance: Double {
        chartData.maxDistance
    }

    private var activeMetricHeadlineText: String {
        if let selectedMetrics {
            switch selectedMetric {
            case .pace:
                return selectedMetrics.paceText
            case .heartRate:
                return selectedMetrics.heartRateText
            case .cadence:
                return selectedMetrics.cadenceText ?? "-"
            case .altitude:
                return selectedMetrics.altitudeText ?? "-"
            }
        }

        switch selectedMetric {
        case .pace:
            return averagePaceText
        case .heartRate:
            return averageHeartRateText
        case .cadence:
            return averageCadenceText ?? "-"
        case .altitude:
            return detail.elevationGainText ?? "-"
        }
    }

    private func rebuildChartData() {
        chartData = PerformanceChartData(run: run, detail: detail)
        syncSelectedMetric()
    }

    private func syncSelectedMetric() {
        guard !availableMetrics.isEmpty else { return }
        if !availableMetrics.contains(selectedMetric) {
            selectedMetric = availableMetrics.first ?? .pace
        }
    }
}

private enum PerformanceChartMetric: String, CaseIterable, Identifiable {
    case pace
    case heartRate
    case cadence
    case altitude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pace:
            return "페이스"
        case .heartRate:
            return "심박"
        case .cadence:
            return "케이던스"
        case .altitude:
            return "고도"
        }
    }

    var systemImage: String {
        switch self {
        case .pace:
            return "speedometer"
        case .heartRate:
            return "heart.fill"
        case .cadence:
            return "metronome"
        case .altitude:
            return "mountain.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pace:
            return .orange
        case .heartRate:
            return Color(red: 0.45, green: 0.95, blue: 0.76)
        case .cadence:
            return Color(red: 0.42, green: 0.76, blue: 1.0)
        case .altitude:
            return Color(red: 0.68, green: 0.60, blue: 0.96)
        }
    }
}

private struct PerformanceMetricPicker: View {
    let metrics: [PerformanceChartMetric]
    @Binding var selectedMetric: PerformanceChartMetric

    var body: some View {
        HStack(spacing: 8) {
            ForEach(metrics) { metric in
                Button {
                    selectedMetric = metric
                } label: {
                    Label(LocalizedStringKey(metric.title), systemImage: metric.systemImage)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .foregroundStyle(metric == selectedMetric ? .white : .white.opacity(0.64))
                        .background(
                            Capsule()
                                .fill(metric == selectedMetric ? metric.tint.opacity(0.2) : Color.white.opacity(0.05))
                                .overlay(
                                    Capsule()
                                        .stroke(metric == selectedMetric ? metric.tint.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RunMetricChartPlot: View {
    let metric: PerformanceChartMetric
    @Binding var selectedDistance: Double?
    let selectedPoint: SimpleMetricChartPoint?
    let points: [SimpleMetricChartPoint]
    let valueRange: ClosedRange<Double>
    let strideValues: [Double]
    let maxDistance: Double

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("거리", point.distanceKilometers),
                    yStart: .value("기준", areaBaseline),
                    yEnd: .value(metric.title, displayedValue(point.value)),
                    series: .value("세그먼트", point.segmentIndex ?? -1)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            metric.tint.opacity(0.22),
                            metric.tint.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.linear)

                LineMark(
                    x: .value("거리", point.distanceKilometers),
                    y: .value(metric.title, displayedValue(point.value)),
                    series: .value("세그먼트", point.segmentIndex ?? -1)
                )
                .foregroundStyle(metric.tint)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            if let selectedPoint {
                RuleMark(x: .value("선택", selectedPoint.distanceKilometers))
                    .foregroundStyle(.white.opacity(0.32))
                    .lineStyle(StrokeStyle(lineWidth: 1.2))

                PointMark(
                    x: .value("선택값", selectedPoint.distanceKilometers),
                    y: .value("선택값Y", displayedValue(selectedPoint.value))
                )
                .foregroundStyle(metric.tint)
                .symbolSize(30)
            }
        }
        .chartXSelection(value: $selectedDistance)
        .chartXScale(domain: 0...max(maxDistance, 0.1))
        .chartYScale(domain: chartYDomain)
        .chartPlotStyle { plotArea in
            plotArea
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
        }
        .chartXAxis {
            AxisMarks(values: strideValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.12))
                AxisTick()
                    .foregroundStyle(.white.opacity(0.35))
                AxisValueLabel {
                    if let distance = value.as(Double.self) {
                        Text(formatAxisDistance(distance))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
            }
        }
        .chartYAxis(.hidden)
    }

    private var areaBaseline: Double {
        switch metric {
        case .pace:
            return 0
        case .heartRate, .cadence, .altitude:
            return valueRange.lowerBound
        }
    }

    private var chartYDomain: ClosedRange<Double> {
        switch metric {
        case .pace:
            return 0...max(valueRange.upperBound - valueRange.lowerBound, 0.1)
        case .heartRate, .cadence, .altitude:
            return valueRange.lowerBound...valueRange.upperBound
        }
    }

    private func displayedValue(_ rawValue: Double) -> Double {
        switch metric {
        case .pace:
            return valueRange.upperBound - rawValue
        case .heartRate, .cadence, .altitude:
            return rawValue
        }
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
    let showsXAxis: Bool

    var body: some View {
        Chart {
            ForEach(paceSeries) { sample in
                LineMark(
                    x: .value("거리", sample.distanceKilometers),
                    y: .value("페이스", displayedPace(sample.secondsPerKilometer)),
                    series: .value("세그먼트", sample.segmentIndex)
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
            AxisMarks(values: showsXAxis ? strideValues : []) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.12))
                if showsXAxis {
                    AxisTick()
                        .foregroundStyle(.white.opacity(0.4))
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text(formatAxisDistance(distance))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
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
    let showsXAxis: Bool

    var body: some View {
        Chart {
            ForEach(heartSeries) { sample in
                LineMark(
                    x: .value("거리", sample.distanceKilometers),
                    y: .value("심박", sample.bpm),
                    series: .value("세그먼트", sample.segmentIndex)
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
            AxisMarks(values: showsXAxis ? strideValues : []) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.12))
                if showsXAxis {
                    AxisTick()
                        .foregroundStyle(.white.opacity(0.4))
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text(formatAxisDistance(distance))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
        .chartYAxis(.hidden)
    }
}

private func formatAxisDistance(_ distance: Double) -> String {
    RunDisplayFormatter.axisDistance(kilometers: distance)
}

private struct RunSplitSection: View {
    let detail: RunDetail

    var body: some View {
        DetailSection(title: L10n.tr("구간"), systemImage: "flag.pattern.checkered", tint: Color(red: 0.29, green: 0.88, blue: 0.63)) {
            if detail.splits.isEmpty {
                Text("스플릿을 계산할 경로 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(spacing: 0) {
                    SplitTableHeader()
                    ForEach(detail.splits) { split in
                        SplitTableRow(split: split)
                        if split.id != detail.splits.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                                .padding(.leading, 4)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

private struct RunOverviewMetricsSection: View {
    let run: RunningWorkout
    let summary: RunSummaryMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                RunHeroMoodBadge(text: moodBadgeText)

                Text(run.detailDateText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                RunEnvironmentBadge(text: run.environmentBadgeText)
            }

            HStack(spacing: 8) {
                RunHeroPrimaryMetric(title: "거리", value: run.distanceText)
                RunHeroPrimaryMetric(title: "시간", value: run.durationText)
                RunHeroPrimaryMetric(title: "페이스", value: run.paceText)
            }

            if !secondaryMetrics.isEmpty {
                LazyVGrid(columns: secondaryColumns, spacing: 8) {
                    ForEach(secondaryMetrics) { metric in
                        RunHeroSecondaryMetric(metric: metric)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color(red: 0.22, green: 0.54, blue: 0.84).opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
        )
    }

    private var secondaryColumns: [GridItem] {
        let count = min(max(secondaryMetrics.count, 1), 3)
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    private var moodBadgeText: String {
        if run.isIndoorWorkout == true {
            return L10n.tr("트레드밀")
        }

        switch run.distanceInKilometers {
        case ..<3:
            return L10n.tr("가벼운 런")
        case ..<8:
            return L10n.tr("데일리 런")
        case ..<15:
            return L10n.tr("지구력 런")
        default:
            return L10n.tr("롱 런")
        }
    }

    private var secondaryMetrics: [RunOverviewSecondaryMetric] {
        var metrics: [RunOverviewSecondaryMetric] = []

        if averageHeartRateText != "-" {
            metrics.append(RunOverviewSecondaryMetric(title: "심박", value: averageHeartRateText))
        }
        if averageCadenceText != "-" {
            metrics.append(RunOverviewSecondaryMetric(title: "케이던스", value: averageCadenceText))
        }
        if elevationGainText != "-" {
            metrics.append(RunOverviewSecondaryMetric(title: "상승", value: elevationGainText))
        }

        return metrics
    }

    private var averageHeartRateText: String {
        summary?.averageHeartRateText ?? "-"
    }

    private var averageCadenceText: String {
        summary?.averageCadenceText ?? "-"
    }

    private var elevationGainText: String {
        summary?.elevationGainText ?? "-"
    }
}

private struct RunHeroPrimaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

private struct RunOverviewSecondaryMetric: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

private struct RunHeroSecondaryMetric: View {
    let metric: RunOverviewSecondaryMetric

    var body: some View {
        HStack(spacing: 6) {
            Text(LocalizedStringKey(metric.title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(metric.value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

private struct RunHeroMoodBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.76))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(red: 0.96, green: 0.56, blue: 0.34).opacity(0.18))
            )
    }
}

private struct HeartRateZoneSection: View {
    let detail: RunDetail
    let isLoadingSupplementary: Bool

    var body: some View {
        DetailSection(title: "심박", systemImage: "heart.fill", tint: Color(red: 0.94, green: 0.41, blue: 0.45)) {
            if zoneRows.isEmpty, isLoadingSupplementary {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("심박 존 데이터를 계산하는 중")
                        .foregroundStyle(.white.opacity(0.72))
                }
            } else if zoneRows.isEmpty {
                Text("심박 데이터가 부족해 존 분포를 계산할 수 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(zoneRows) { zone in
                        HeartRateZoneRow(zone: zone)
                    }
                }
            }
        }
    }

    private var zoneRows: [HeartRateZoneRowModel] {
        guard detail.heartRates.count >= 2 else { return [] }
        guard let zoneProfile = detail.heartRateZoneProfile else { return [] }

        let boundaries: [(label: String, lower: Double, upper: Double, color: Color)] = [
            (L10n.tr("존 1"), 0.50, 0.60, Color(red: 0.42, green: 0.76, blue: 1.0)),
            (L10n.tr("존 2"), 0.60, 0.70, Color(red: 0.45, green: 0.95, blue: 0.76)),
            (L10n.tr("존 3"), 0.70, 0.80, Color(red: 0.95, green: 0.84, blue: 0.40)),
            (L10n.tr("존 4"), 0.80, 0.90, Color(red: 0.95, green: 0.59, blue: 0.32)),
            (L10n.tr("존 5"), 0.90, 1.01, Color(red: 0.94, green: 0.41, blue: 0.45))
        ]

        let sortedHeartRates = detail.heartRates.sorted {
            ($0.elapsed ?? .greatestFiniteMagnitude) < ($1.elapsed ?? .greatestFiniteMagnitude)
        }
        let totalDuration = max(detail.activeDuration, 1)
        var durations = Array(repeating: 0.0, count: boundaries.count)

        for index in sortedHeartRates.indices {
            let current = sortedHeartRates[index]
            guard let currentElapsed = current.elapsed else { continue }
            let nextElapsed = sortedHeartRates.indices.contains(index + 1)
                ? (sortedHeartRates[index + 1].elapsed ?? detail.activeDuration)
                : detail.activeDuration
            let sampleDuration = max(nextElapsed - currentElapsed, 0)
            guard sampleDuration > 0 else { continue }

            if let zoneIndex = boundaries.firstIndex(where: {
                let bpmRange = zoneProfile.bpmRange(lowerFraction: $0.lower, upperFraction: min($0.upper, 1.0))
                return current.bpm >= Double(bpmRange.lowerBound) && current.bpm < Double(bpmRange.upperBound + 1)
            }) {
                durations[zoneIndex] += sampleDuration
            }
        }

        return boundaries.enumerated().map { index, boundary in
            return HeartRateZoneRowModel(
                title: boundary.label,
                duration: durations[index],
                percentage: durations[index] / totalDuration,
                color: boundary.color
            )
        }
    }
}

private struct RunDataSourceSection: View {
    let run: RunningWorkout

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(red: 0.49, green: 0.78, blue: 1.0))

            Text(run.sourceSummaryText)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }
}

private struct HeartRateZoneRowModel: Identifiable {
    let id = UUID()
    let title: String
    let duration: TimeInterval
    let percentage: Double
    let color: Color
}

private struct HeartRateZoneRow: View {
    let zone: HeartRateZoneRowModel

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(zone.color)
                    .frame(width: 8, height: 8)

                Text(LocalizedStringKey(zone.title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, alignment: .leading)

            GeometryReader { proxy in
                let barWidth = proxy.size.width
                let fillWidth = max(barWidth * max(zone.percentage, 0.02), zone.duration > 0 ? 10 : 0)
                let showsLabelInside = fillWidth >= 54

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(zone.color)
                        .frame(width: fillWidth)

                    if zone.duration > 0 {
                        if showsLabelInside {
                            HStack {
                                Spacer(minLength: 0)
                                Text(zone.percentageText)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                            }
                            .padding(.trailing, 8)
                            .frame(width: fillWidth, alignment: .trailing)
                        } else {
                            Text(zone.percentageText)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(zone.color.opacity(0.92))
                                .monospacedDigit()
                                .padding(.leading, fillWidth + 8)
                        }
                    }
                }
            }
            .frame(height: 22)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(zone.duration))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(width: 92, alignment: .trailing)
        }
    }
}

private extension HeartRateZoneRowModel {
    var percentageText: String {
        "\((percentage * 100).formatted(.number.precision(.fractionLength(0))))%"
    }
}

private struct SimpleMetricChartPoint: Identifiable {
    let id: String
    let distanceKilometers: Double
    let value: Double
    let segmentIndex: Int?

    init(distanceKilometers: Double, value: Double, segmentIndex: Int?) {
        self.id = "\(distanceKilometers)-\(segmentIndex ?? -1)"
        self.distanceKilometers = distanceKilometers
        self.value = value
        self.segmentIndex = segmentIndex
    }
}

private struct SyncedMetricChartPlot: View {
    @Binding var selectedDistance: Double?
    let selectedPoint: SimpleMetricChartPoint?
    let points: [SimpleMetricChartPoint]
    let valueRange: ClosedRange<Double>
    let strideValues: [Double]
    let maxDistance: Double
    let tint: Color
    let showsXAxis: Bool

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("거리", point.distanceKilometers),
                    y: .value("값", point.value),
                    series: .value("세그먼트", point.segmentIndex ?? -1)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            if let selectedPoint {
                RuleMark(x: .value("선택", selectedPoint.distanceKilometers))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.2))

                PointMark(
                    x: .value("선택값", selectedPoint.distanceKilometers),
                    y: .value("선택값Y", selectedPoint.value)
                )
                .foregroundStyle(tint)
                .symbolSize(24)
            }
        }
        .chartXSelection(value: $selectedDistance)
        .chartXScale(domain: 0...max(maxDistance, 0.1))
        .chartYScale(domain: valueRange.lowerBound...valueRange.upperBound)
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
        .chartXAxis {
            AxisMarks(values: showsXAxis ? strideValues : []) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.12))
                if showsXAxis {
                    AxisTick()
                        .foregroundStyle(.white.opacity(0.35))
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text(formatAxisDistance(distance))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }
                }
            }
        }
        .chartYAxis(.hidden)
    }
}

private struct AdditionalMetricChart: View {
    let title: String
    let tint: Color
    let yLabel: String
    let points: [SimpleMetricChartPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(yLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Chart(points) { point in
                LineMark(
                    x: .value("거리", point.distanceKilometers),
                    y: .value(title, point.value)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 140)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.white.opacity(0.12))
                    AxisTick()
                        .foregroundStyle(.white.opacity(0.35))
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text(formatAxisDistance(distance))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel {
                        if let raw = value.as(Double.self) {
                            Text(raw.formatted(.number.precision(.fractionLength(0))))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.background(.clear)
            }
        }
    }
}

private struct SplitTableHeader: View {
    var body: some View {
        HStack(spacing: SplitColumnLayout.spacing) {
            splitColumnTitle("거리", width: SplitColumnLayout.distanceWidth, alignment: .leading)
            splitColumnTitle("페이스", width: SplitColumnLayout.paceWidth, alignment: .trailing)
            splitColumnTitle("심박", width: SplitColumnLayout.heartWidth, alignment: .trailing)
            splitColumnTitle("케이던스", width: SplitColumnLayout.cadenceWidth, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
    }

    private func splitColumnTitle(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(LocalizedStringKey(title))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.45))
            .frame(width: width, alignment: alignment)
    }
}

private struct SplitTableRow: View {
    let split: RunSplit

    var body: some View {
        HStack(spacing: SplitColumnLayout.spacing) {
            Text(split.titleText)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: SplitColumnLayout.distanceWidth, alignment: .leading)

            Text(split.paceText)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .frame(width: SplitColumnLayout.paceWidth, alignment: .trailing)
                .monospacedDigit()

            Text(split.heartRateText)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(split.averageHeartRate == nil ? .white.opacity(0.45) : .white.opacity(0.78))
                .frame(width: SplitColumnLayout.heartWidth, alignment: .trailing)
                .monospacedDigit()

            Text(split.cadenceText)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(split.averageCadence == nil ? .white.opacity(0.45) : .white.opacity(0.78))
                .frame(width: SplitColumnLayout.cadenceWidth, alignment: .trailing)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum SplitColumnLayout {
    static let spacing: CGFloat = 10
    static let distanceWidth: CGFloat = 48
    static let paceWidth: CGFloat = 88
    static let heartWidth: CGFloat = 72
    static let cadenceWidth: CGFloat = 82
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
    let segmentIndex: Int

    init(distanceMeters: Double, secondsPerKilometer: Double, segmentIndex: Int) {
        self.id = distanceMeters
        self.distanceMeters = distanceMeters
        self.distanceKilometers = distanceMeters / 1_000
        self.secondsPerKilometer = secondsPerKilometer
        self.segmentIndex = segmentIndex
    }

    static func build(from samples: [PaceSample]) -> [PaceChartPoint] {
        let sorted = samples.sorted { $0.distanceMeters < $1.distanceMeters }
        let points = sorted.map {
            PaceChartPoint(
                distanceMeters: $0.distanceMeters,
                secondsPerKilometer: $0.secondsPerKilometer,
                segmentIndex: $0.segmentIndex
            )
        }
        return movingAverage(points: points, radius: 2)
    }

    private static func movingAverage(points: [PaceChartPoint], radius: Int) -> [PaceChartPoint] {
        guard !points.isEmpty else { return [] }

        return points.indices.map { index in
            let segmentIndex = points[index].segmentIndex
            let window = points[max(0, index - radius)...min(points.count - 1, index + radius)]
                .filter { $0.segmentIndex == segmentIndex }
            let averagePace = window.map(\.secondsPerKilometer).reduce(0, +) / Double(window.count)
            return PaceChartPoint(
                distanceMeters: points[index].distanceMeters,
                secondsPerKilometer: averagePace,
                segmentIndex: points[index].segmentIndex
            )
        }
    }
}

private struct HeartRateChartPoint: Identifiable {
    let id: Double
    let distanceMeters: Double
    let distanceKilometers: Double
    let bpm: Double
    let segmentIndex: Int

    init(distanceMeters: Double, bpm: Double, segmentIndex: Int) {
        self.id = distanceMeters
        self.distanceMeters = distanceMeters
        self.distanceKilometers = distanceMeters / 1_000
        self.bpm = bpm
        self.segmentIndex = segmentIndex
    }

    static func build(from samples: [HeartRateSample]) -> [HeartRateChartPoint] {
        let normalized = samples.compactMap { sample -> HeartRateChartPoint? in
            guard let distanceMeters = sample.distanceMeters, let segmentIndex = sample.segmentIndex else { return nil }
            return HeartRateChartPoint(distanceMeters: distanceMeters, bpm: sample.bpm, segmentIndex: segmentIndex)
        }
        let sorted = normalized.sorted { $0.distanceMeters < $1.distanceMeters }
        return movingAverage(points: sorted, radius: 1)
    }

    private static func movingAverage(points: [HeartRateChartPoint], radius: Int) -> [HeartRateChartPoint] {
        guard !points.isEmpty else { return [] }

        return points.indices.map { index in
            let segmentIndex = points[index].segmentIndex
            let window = points[max(0, index - radius)...min(points.count - 1, index + radius)]
                .filter { $0.segmentIndex == segmentIndex }
            let averageHeartRate = window.map(\.bpm).reduce(0, +) / Double(window.count)
            return HeartRateChartPoint(
                distanceMeters: points[index].distanceMeters,
                bpm: averageHeartRate,
                segmentIndex: points[index].segmentIndex
            )
        }
    }
}

private struct DemoScenarioPanel: View {
    @ObservedObject var viewModel: RunDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("샘플 러닝")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))

            Menu {
                Button("기본 샘플") {
                    Task {
                        await viewModel.applyDebugScenario(.completeMetrics)
                    }
                }
                Button("pause 포함") {
                    Task {
                        await viewModel.applyDebugScenario(.pausedWorkout)
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
                Button("고급 메트릭 없음") {
                    Task {
                        await viewModel.applyDebugScenario(.missingAdvancedMetrics)
                    }
                }
                Button("빈 상세") {
                    Task {
                        await viewModel.applyDebugScenario(.empty)
                    }
                }
            } label: {
                Label("다른 샘플 보기", systemImage: "sparkles.rectangle.stack")
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
}

private struct SelectedMetrics {
    let distanceMeters: Double
    let elapsed: TimeInterval
    let paceSecondsPerKilometer: Double?
    let heartRate: Double?
    let cadence: Double?
    let altitudeMeters: Double?

    var distanceKilometers: Double {
        distanceMeters / 1_000
    }

    var distanceText: String {
        RunDisplayFormatter.distance(meters: distanceMeters, fractionLength: 2)
    }

    var elapsedText: String {
        RunDisplayFormatter.duration(elapsed)
    }

    var paceText: String {
        guard let paceSecondsPerKilometer else { return "-" }
        return RunDisplayFormatter.pace(secondsPerKilometer: paceSecondsPerKilometer)
    }

    var heartRateText: String {
        RunDisplayFormatter.heartRate(heartRate) ?? "-"
    }

    var cadenceText: String? {
        RunDisplayFormatter.cadence(cadence)
    }

    var altitudeText: String? {
        RunDisplayFormatter.elevation(altitudeMeters)
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

private struct RunGearSection: View {
    let run: RunningWorkout
    @EnvironmentObject private var shoeStore: ShoeStore

    var body: some View {
        DetailSection(title: "러닝화", systemImage: "shoeprints.fill", tint: Color(red: 0.91, green: 0.69, blue: 0.38)) {
            if shoeStore.shoes.isEmpty {
                Text("신발 탭에서 러닝화를 추가하면 이 러닝에 연결할 수 있습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(shoeStore.shoe(for: run.id)?.displayName ?? L10n.tr("신발 미선택"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(shoeStore.shoe(for: run.id)?.brandModelText ?? L10n.tr("이 러닝에 어떤 신발을 신었는지 기록해두세요."))
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

// 상세 화면은 mock 시나리오별로 캔버스에서 빠르게 품질을 점검한다.
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
