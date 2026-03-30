import Charts
import MapKit
import SwiftUI

private struct CompactSelectionRow: View {
    let metrics: SelectedMetrics

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            CompactMetricChip(title: "거리", value: metrics.distanceText, detail: metrics.elapsedText)
            CompactMetricChip(title: "페이스", value: metrics.paceText, detail: "선택 구간")
            CompactMetricChip(title: "심박", value: metrics.heartRateText, detail: "선택 시점")
            if let cadenceText = metrics.cadenceText {
                CompactMetricChip(title: "케이던스", value: cadenceText, detail: "선택 시점")
            }
            if let altitudeText = metrics.altitudeText {
                CompactMetricChip(title: "고도", value: altitudeText, detail: "선택 지점")
            }
        }
    }
}

private struct CompactAverageRow: View {
    let averagePaceText: String
    let averageHeartRateText: String
    let averageCadenceText: String?

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            CompactMetricChip(title: "평균 페이스", value: averagePaceText, detail: "러닝 전체")
            CompactMetricChip(title: "평균 심박", value: averageHeartRateText, detail: "러닝 전체")
            if let averageCadenceText {
                CompactMetricChip(title: "평균 케이던스", value: averageCadenceText, detail: "러닝 전체")
            }
        }
    }
}

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
        return "축하합니다! \(labels.joined(separator: ", ")) 새로운 최고 기록을 달성했습니다!"
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

                VStack(alignment: .leading, spacing: 6) {
                    Text(run.detailDateText)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        RunEnvironmentBadge(text: run.environmentText)
                        Text(run.sourceName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if run.isDemoWorkout {
                    DemoScenarioPanel(viewModel: viewModel)
                }

                switch viewModel.state {
                case .idle, .loading:
                    RunOverviewMetricsSection(run: run, summary: viewModel.cachedSummary)
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
                    RunOverviewMetricsSection(
                        run: run,
                        summary: detail.summaryMetrics.mergingMissingValues(from: viewModel.cachedSummary)
                    )
                    RunSplitSection(detail: detail)
                    PerformanceChartSection(run: run, detail: detail)
                    HeartRateZoneSection(detail: detail, isLoadingSupplementary: viewModel.isLoadingSupplementary)
                    RunGearSection(run: run)
                    RunRouteSection(detail: detail, isLoadingSupplementary: viewModel.isLoadingSupplementary)
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
        DetailSection(title: "러닝 경로") {
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

private struct PerformanceChartSection: View {
    let run: RunningWorkout
    let detail: RunDetail
    @State private var selectedDistance: Double?

    var body: some View {
        DetailSection(title: "퍼포먼스 차트") {
            if heartSeries.isEmpty && paceSeries.isEmpty && cadenceSeries.isEmpty && altitudeSeries.isEmpty {
                Text("그래프를 그릴 경로 또는 심박 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if let selectedMetrics {
                        CompactSelectionRow(metrics: selectedMetrics)
                    } else {
                        CompactAverageRow(
                            averagePaceText: averagePaceText,
                            averageHeartRateText: averageHeartRateText,
                            averageCadenceText: averageCadenceText
                        )
                    }

                    VStack(spacing: 0) {
                        if !paceSeries.isEmpty {
                            metricHeader(title: "페이스", systemImage: "speedometer", tint: .orange)
                                .padding(.bottom, 6)

                            PaceChartPlot(
                                selectedMetrics: selectedMetrics,
                                selectedPacePoint: selectedPacePoint,
                                selectedDistance: $selectedDistance,
                                paceSeries: paceSeries,
                                paceRange: paceRange,
                                strideValues: strideValues,
                                maxDistance: maxDistance,
                                showsXAxis: false
                            )
                            .frame(height: 144)
                        }

                        if !heartSeries.isEmpty {
                            sectionDivider
                            metricHeader(
                                title: "심박",
                                systemImage: "heart.fill",
                                tint: Color(red: 0.45, green: 0.95, blue: 0.76)
                            )
                            .padding(.bottom, 6)

                            HeartRateChartPlot(
                                selectedMetrics: selectedMetrics,
                                selectedHeartPoint: selectedHeartPoint,
                                selectedDistance: $selectedDistance,
                                heartSeries: heartSeries,
                                heartRateRange: heartRateRange,
                                strideValues: strideValues,
                                maxDistance: maxDistance,
                                showsXAxis: cadenceSeries.isEmpty && altitudeSeries.isEmpty
                            )
                            .frame(height: 144)
                        }

                        if !cadenceSeries.isEmpty {
                            sectionDivider
                            metricHeader(
                                title: "케이던스",
                                systemImage: "metronome",
                                tint: Color(red: 0.42, green: 0.76, blue: 1.0)
                            )
                            .padding(.bottom, 6)

                            SyncedMetricChartPlot(
                                selectedDistance: $selectedDistance,
                                selectedPoint: selectedCadencePoint,
                                points: cadenceSeries,
                                valueRange: cadenceRange,
                                strideValues: strideValues,
                                maxDistance: maxDistance,
                                tint: Color(red: 0.42, green: 0.76, blue: 1.0),
                                showsXAxis: altitudeSeries.isEmpty
                            )
                            .frame(height: 144)
                        }

                        if !altitudeSeries.isEmpty {
                            sectionDivider
                            metricHeader(
                                title: "고도",
                                systemImage: "mountain.2.fill",
                                tint: Color(red: 0.68, green: 0.60, blue: 0.96)
                            )
                            .padding(.bottom, 6)

                            SyncedMetricChartPlot(
                                selectedDistance: $selectedDistance,
                                selectedPoint: selectedAltitudePoint,
                                points: altitudeSeries,
                                valueRange: altitudeRange,
                                strideValues: strideValues,
                                maxDistance: maxDistance,
                                tint: Color(red: 0.68, green: 0.60, blue: 0.96),
                                showsXAxis: true
                            )
                            .frame(height: 144)
                        }
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
            return average.formatted(.number.precision(.fractionLength(0))) + " spm"
        }

        guard !detail.runningMetrics.cadence.isEmpty else { return nil }
        let average = detail.runningMetrics.cadence.map(\.value).reduce(0, +) / Double(detail.runningMetrics.cadence.count)
        return average.formatted(.number.precision(.fractionLength(0))) + " spm"
    }

    private var heartSeries: [HeartRateChartPoint] {
        HeartRateChartPoint.build(from: detail.heartRates)
    }

    private var paceSeries: [PaceChartPoint] {
        PaceChartPoint.build(from: detail.paceSamples)
    }

    private var cadenceSeries: [SimpleMetricChartPoint] {
        detail.runningMetrics.cadence.compactMap { sample in
            guard let distanceMeters = sample.distanceMeters else { return nil }
            return SimpleMetricChartPoint(
                distanceKilometers: distanceMeters / 1_000,
                value: sample.value,
                segmentIndex: sample.segmentIndex
            )
        }
    }

    private var altitudeSeries: [SimpleMetricChartPoint] {
        detail.route.map { point in
            SimpleMetricChartPoint(
                distanceKilometers: point.distanceMeters / 1_000,
                value: point.altitudeMeters ?? .nan,
                segmentIndex: nil
            )
        }
        .filter { $0.value.isFinite }
    }

    private var selectedMetrics: SelectedMetrics? {
        guard let resolvedDistanceKilometers = snappedDistanceKilometers else { return nil }

        let resolvedDistanceMeters = resolvedDistanceKilometers * 1_000
        let nearestDistancePoint = detail.distanceTimeline.min(by: {
            abs($0.distanceMeters - resolvedDistanceMeters) < abs($1.distanceMeters - resolvedDistanceMeters)
        })

        return SelectedMetrics(
            distanceMeters: resolvedDistanceMeters,
            elapsed: nearestDistancePoint?.elapsed ?? 0,
            paceSecondsPerKilometer: selectedPacePoint?.secondsPerKilometer,
            heartRate: selectedHeartPoint?.bpm,
            cadence: selectedCadencePoint?.value,
            altitudeMeters: selectedAltitudePoint?.value
        )
    }

    private var snappedDistanceKilometers: Double? {
        guard let selectedDistance else { return nil }
        return min(max(selectedDistance, 0), maxDistance)
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

    private var selectedCadencePoint: SimpleMetricChartPoint? {
        guard let snappedDistanceKilometers else { return nil }
        return cadenceSeries.min(by: {
            abs($0.distanceKilometers - snappedDistanceKilometers) < abs($1.distanceKilometers - snappedDistanceKilometers)
        })
    }

    private var selectedAltitudePoint: SimpleMetricChartPoint? {
        guard let snappedDistanceKilometers else { return nil }
        return altitudeSeries.min(by: {
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

    private var cadenceRange: ClosedRange<Double> {
        metricRange(for: cadenceSeries.map(\.value), minimumPadding: 6)
    }

    private var altitudeRange: ClosedRange<Double> {
        metricRange(for: altitudeSeries.map(\.value), minimumPadding: 4)
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
        var values = Array(0...count).map { Double($0) * stride }
        if let last = values.last, abs(last - maxDistance) > 0.001 {
            values.append(maxDistance)
        }
        return values
    }

    private var maxDistance: Double {
        max(
            run.distanceInKilometers,
            (detail.distanceTimeline.last?.distanceMeters ?? 0) / 1_000,
            paceSeries.last?.distanceKilometers ?? 0,
            heartSeries.last?.distanceKilometers ?? 0
        )
    }

    private func metricHeader(title: String, systemImage: String, tint: Color) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Spacer()
        }
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.vertical, 10)
    }

    private func metricRange(for values: [Double], minimumPadding: Double) -> ClosedRange<Double> {
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? minValue + minimumPadding
        let padding = max((maxValue - minValue) * 0.12, minimumPadding)
        return (minValue - padding)...(maxValue + padding)
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
    let hasFraction = abs(distance.rounded() - distance) > 0.001
    let fractionLength = hasFraction ? 2 : 1
    return distance.formatted(.number.precision(.fractionLength(fractionLength)))
}

private struct RunSplitSection: View {
    let detail: RunDetail

    var body: some View {
        DetailSection(title: "km 스플릿") {
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            CompactMetricChip(title: "거리", value: run.distanceText, detail: "총 거리")
            CompactMetricChip(title: "시간", value: run.durationText, detail: "총 운동 시간")
            CompactMetricChip(title: "평균 페이스", value: run.paceText, detail: "러닝 전체")
            CompactMetricChip(title: "평균 심박", value: averageHeartRateText, detail: "러닝 전체")
            CompactMetricChip(title: "평균 케이던스", value: averageCadenceText, detail: "러닝 전체")
            CompactMetricChip(title: "상승 고도", value: elevationGainText, detail: "러닝 전체")
        }
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

private struct HeartRateZoneSection: View {
    let detail: RunDetail
    let isLoadingSupplementary: Bool

    var body: some View {
        DetailSection(title: "심박 존 1-5") {
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
                    Text(detail.heartRateZoneProfile?.method.descriptionText ?? "심박 존 기준 없음")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))

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
            ("존 1", 0.50, 0.60, Color.blue),
            ("존 2", 0.60, 0.70, Color.green),
            ("존 3", 0.70, 0.80, Color.yellow),
            ("존 4", 0.80, 0.90, Color.orange),
            ("존 5", 0.90, 1.01, Color.red)
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
            let bpmRange = zoneProfile.bpmRange(
                lowerFraction: boundary.lower,
                upperFraction: min(boundary.upper, 1.0)
            )
            return HeartRateZoneRowModel(
                title: boundary.label,
                rangeText: "\(bpmRange.lowerBound)-\(bpmRange.upperBound) bpm",
                intensityText: "\(Int(boundary.lower * 100))-\(Int(min(boundary.upper, 1.0) * 100))%",
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
        VStack(alignment: .leading, spacing: 4) {
            Text("데이터 소스")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(run.sourceName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text(run.sourceBundleIdentifier)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }
}

private struct HeartRateZoneRowModel: Identifiable {
    let id = UUID()
    let title: String
    let rangeText: String
    let intensityText: String
    let duration: TimeInterval
    let percentage: Double
    let color: Color
}

private struct HeartRateZoneRow: View {
    let zone: HeartRateZoneRowModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(zone.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(zone.rangeText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                Text(zone.intensityText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .frame(width: 64, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(zone.color)
                        .frame(width: max(proxy.size.width * max(zone.percentage, 0.02), zone.duration > 0 ? 10 : 0))
                }
            }
            .frame(height: 14)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(zone.duration))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("\((zone.percentage * 100).formatted(.number.precision(.fractionLength(0))))%")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .monospacedDigit()
            }
            .frame(width: 64, alignment: .trailing)
        }
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
                Text(title)
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
        Text(title)
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
    static let distanceWidth: CGFloat = 68
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
        distanceKilometers.formatted(.number.precision(.fractionLength(2))) + " km"
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

    var cadenceText: String? {
        guard let cadence else { return nil }
        return cadence.formatted(.number.precision(.fractionLength(0))) + " spm"
    }

    var altitudeText: String? {
        guard let altitudeMeters else { return nil }
        return altitudeMeters.formatted(.number.precision(.fractionLength(0))) + " m"
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
            .background(AppBackground())
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
