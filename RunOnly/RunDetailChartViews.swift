import Charts
import MapKit
import SwiftUI

struct PerformanceChartInputKey: Hashable {
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
    }
}

struct PerformanceChartRouteKey: Hashable {
    let runID: UUID
    let routeCount: Int
    let routeLastMeters: Double

    init(run: RunningWorkout, detail: RunDetail) {
        runID = run.id
        routeCount = detail.route.count
        routeLastMeters = detail.route.last?.distanceMeters ?? 0
    }
}

struct PerformanceChartData {
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
    let averagePaceSecondsPerKilometer: Double?
    let availableMetrics: [PerformanceChartMetric]
    let strideValues: [Double]
    let maxDistance: Double

    init(run: RunningWorkout, detail: RunDetail) {
        let sortedDistanceTimeline = detail.distanceTimeline.sorted(by: { $0.distanceMeters < $1.distanceMeters })
        let builtPaceSeries = PaceChartPoint.build(from: detail.paceSamples)
        let builtHeartSeries = HeartRateChartPoint.build(from: detail.heartRates)
        let builtCadenceSeries = Self.metricSeries(from: detail.runningMetrics.cadence)
        let builtAltitudeSeries = Self.downsample(
            detail.route
            .compactMap { point -> SimpleMetricChartPoint? in
                guard let altitudeMeters = point.altitudeMeters, altitudeMeters.isFinite else { return nil }
                return SimpleMetricChartPoint(
                    distanceKilometers: point.distanceMeters / 1_000,
                    value: altitudeMeters,
                    segmentIndex: nil
                )
            }
            .sorted(by: { $0.distanceKilometers < $1.distanceKilometers }),
            maxCount: 800
        )
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

        if run.distanceInMeters > 0 {
            averagePaceSecondsPerKilometer = run.duration / max(run.distanceInMeters / 1_000, 0.001)
        } else {
            averagePaceSecondsPerKilometer = nil
        }

        paceRange = Self.stablePaceRange(
            for: builtPaceSeries.map(\.secondsPerKilometer),
            averagePace: averagePaceSecondsPerKilometer
        )

        cadenceRange = Self.metricRange(for: builtCadenceSeries.map(\.value), minimumPadding: 6)
        altitudeRange = Self.metricRange(for: builtAltitudeSeries.map(\.value), minimumPadding: 4)

        var builtMaxDistance = run.distanceInKilometers
        builtMaxDistance = max(builtMaxDistance, (sortedDistanceTimeline.last?.distanceMeters ?? 0) / 1_000)
        builtMaxDistance = max(builtMaxDistance, builtPaceSeries.last?.distanceKilometers ?? 0)
        builtMaxDistance = max(builtMaxDistance, builtHeartSeries.last?.distanceKilometers ?? 0)
        builtMaxDistance = max(builtMaxDistance, builtCadenceSeries.last?.distanceKilometers ?? 0)
        builtMaxDistance = max(builtMaxDistance, builtAltitudeSeries.last?.distanceKilometers ?? 0)
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

    func nearestMetricPoint(for metric: PerformanceChartMetric, toKilometers distanceKilometers: Double) -> SimpleMetricChartPoint? {
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
        nearestMetricPoint(for: metric, toKilometers: distanceKilometers)
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

    private static func metricSeries(from samples: [RunningMetricSample]) -> [SimpleMetricChartPoint] {
        samples
            .compactMap { sample -> SimpleMetricChartPoint? in
                guard let distanceMeters = sample.distanceMeters else { return nil }
                return SimpleMetricChartPoint(
                    distanceKilometers: distanceMeters / 1_000,
                    value: sample.value,
                    segmentIndex: sample.segmentIndex
                )
            }
            .sorted(by: { $0.distanceKilometers < $1.distanceKilometers })
    }

    private static func metricRange(for values: [Double], minimumPadding: Double) -> ClosedRange<Double> {
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? minValue + minimumPadding
        let padding = max((maxValue - minValue) * 0.12, minimumPadding)
        return (minValue - padding)...(maxValue + padding)
    }

    private static func downsample(_ points: [SimpleMetricChartPoint], maxCount: Int) -> [SimpleMetricChartPoint] {
        guard points.count > maxCount, maxCount > 2 else { return points }
        let stride = Double(points.count - 1) / Double(maxCount - 1)
        var result: [SimpleMetricChartPoint] = []
        var lastIndex = -1

        for sampleIndex in 0..<maxCount {
            let sourceIndex = min(Int((Double(sampleIndex) * stride).rounded()), points.count - 1)
            guard sourceIndex != lastIndex else { continue }
            result.append(points[sourceIndex])
            lastIndex = sourceIndex
        }

        if result.last?.id != points.last?.id {
            result.append(points[points.count - 1])
        }
        return result
    }

    private static func stablePaceRange(for values: [Double], averagePace: Double?) -> ClosedRange<Double> {
        let sorted = values.filter(\.isFinite).sorted()
        guard !sorted.isEmpty else {
            let average = averagePace ?? 360
            return max(average - 360, 120)...min(average + 360, 1_000)
        }

        let lower = percentile(0.08, in: sorted)
        let upper = percentile(0.92, in: sorted)
        let center = averagePace ?? sorted[sorted.count / 2]
        let rawSpan = max(upper - lower, 1)
        let minimumSpan = 720.0
        let paddedSpan = max(rawSpan * 1.6, minimumSpan)
        let midpoint = (lower + upper) / 2
        let anchoredMidpoint = (midpoint * 0.45) + (center * 0.55)
        let rangeLower = min(anchoredMidpoint - paddedSpan / 2, center - 60)
        let rangeUpper = max(anchoredMidpoint + paddedSpan / 2, center + 60)
        return max(rangeLower, 120)...min(max(rangeUpper, rangeLower + minimumSpan), 1_000)
    }

    private static func percentile(_ percentile: Double, in sortedValues: [Double]) -> Double {
        guard let first = sortedValues.first else { return 0 }
        guard sortedValues.count > 1 else { return first }

        let clampedPercentile = min(max(percentile, 0), 1)
        let position = clampedPercentile * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        guard lowerIndex != upperIndex else { return sortedValues[lowerIndex] }

        let fraction = position - Double(lowerIndex)
        return sortedValues[lowerIndex] + (sortedValues[upperIndex] - sortedValues[lowerIndex]) * fraction
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

struct PerformanceChartSection: View {
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
        DetailSection(title: "흐름", systemImage: "chart.line.uptrend.xyaxis", tint: PNR2026.heat) {
            if availableMetrics.isEmpty {
                Text("그래프를 그릴 경로 또는 심박 데이터가 없습니다.")
                    .foregroundStyle(PNR2026.muted)
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
                            .foregroundStyle(PNR2026.ink)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 2)

                    RunMetricChartPlot(
                        metric: selectedMetric,
                        selectedDistance: $selectedDistance,
                        selectedPoint: activeSelectedPoint,
                        points: activeSeries,
                        valueRange: activeValueRange,
                        averageValue: activeAverageValue,
                        altitudePoints: chartData.altitudeSeries,
                        altitudeRange: chartData.altitudeRange,
                        strideValues: strideValues,
                        maxDistance: maxDistance
                    )
                    .frame(height: 220)

                }
                .onAppear(perform: syncSelectedMetric)
                .onChange(of: chartInputKey) {
                    rebuildChartData()
                }
                .onChange(of: routeInputKey) {
                    rebuildChartData()
                }
            }
        }
    }

    private var chartInputKey: PerformanceChartInputKey {
        PerformanceChartInputKey(run: run, detail: detail)
    }

    private var routeInputKey: PerformanceChartRouteKey {
        PerformanceChartRouteKey(run: run, detail: detail)
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
        RunDisplayFormatter.cadence(averageCadenceValue)
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

    private var activeAverageValue: Double? {
        switch selectedMetric {
        case .pace:
            return chartData.averagePaceSecondsPerKilometer
        case .heartRate:
            guard !detail.heartRates.isEmpty else { return nil }
            return detail.heartRates.map(\.bpm).reduce(0, +) / Double(detail.heartRates.count)
        case .cadence:
            return averageCadenceValue
        case .altitude:
            return nil
        }
    }

    private var strideValues: [Double] {
        chartData.strideValues
    }

    private var maxDistance: Double {
        chartData.maxDistance
    }

    private var activeMetricHeadlineText: String {
        if let snappedDistanceKilometers,
           let point = chartData.nearestSeriesPoint(for: selectedMetric, toKilometers: snappedDistanceKilometers) {
            return selectedMetric.valueText(point.value)
        }

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

    private var averageCadenceValue: Double? {
        let weightedCadence = detail.splits.reduce(into: (weighted: 0.0, duration: 0.0)) { partial, split in
            guard let cadence = split.averageCadence else { return }
            partial.weighted += cadence * split.duration
            partial.duration += split.duration
        }

        if weightedCadence.duration > 0 {
            return weightedCadence.weighted / weightedCadence.duration
        }

        guard !detail.runningMetrics.cadence.isEmpty else { return nil }
        return detail.runningMetrics.cadence.map(\.value).reduce(0, +) / Double(detail.runningMetrics.cadence.count)
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

enum PerformanceChartMetric: String, CaseIterable, Identifiable {
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
            return PNR2026.heat
        case .heartRate:
            return PNR2026.rose
        case .cadence:
            return PNR2026.water
        case .altitude:
            return PNR2026.track
        }
    }

    func valueText(_ value: Double) -> String {
        switch self {
        case .pace:
            return RunDisplayFormatter.pace(secondsPerKilometer: value)
        case .heartRate:
            return RunDisplayFormatter.heartRate(value) ?? "-"
        case .cadence:
            return RunDisplayFormatter.cadence(value) ?? "-"
        case .altitude:
            return RunDisplayFormatter.elevation(value) ?? "-"
        }
    }

    func averageText(from points: [SimpleMetricChartPoint]) -> String {
        guard !points.isEmpty else { return "-" }
        let average = points.map(\.value).reduce(0, +) / Double(points.count)
        return valueText(average)
    }
}

struct PerformanceMetricPicker: View {
    let metrics: [PerformanceChartMetric]
    @Binding var selectedMetric: PerformanceChartMetric

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(metrics) { metric in
                    Button {
                        selectedMetric = metric
                    } label: {
                        Label(LocalizedStringKey(metric.title), systemImage: metric.systemImage)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .frame(minWidth: 76)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .foregroundStyle(metric == selectedMetric ? PNR2026.ink : PNR2026.muted)
                            .background(
                                Capsule()
                                    .fill(metric == selectedMetric ? metric.tint.opacity(0.18) : PNR2026.surface)
                                    .overlay(
                                        Capsule()
                                            .stroke(metric == selectedMetric ? metric.tint.opacity(0.48) : PNR2026.line, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct RunMetricChartPlot: View {
    let metric: PerformanceChartMetric
    @Binding var selectedDistance: Double?
    let selectedPoint: SimpleMetricChartPoint?
    let points: [SimpleMetricChartPoint]
    let valueRange: ClosedRange<Double>
    let averageValue: Double?
    let altitudePoints: [SimpleMetricChartPoint]
    let altitudeRange: ClosedRange<Double>
    let strideValues: [Double]
    let maxDistance: Double
    var interpolationMethod: InterpolationMethod = .catmullRom

    var body: some View {
        Chart {
            if metric == .pace {
                ForEach(altitudePoints) { point in
                    AreaMark(
                        x: .value("거리", point.distanceKilometers),
                        yStart: .value("고도 기준", 0),
                        yEnd: .value("고도", displayedAltitude(point.value))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                PNR2026.muted.opacity(0.10),
                                PNR2026.muted.opacity(0.00)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }

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
                            metric.tint.opacity(0.14),
                            metric.tint.opacity(0.00)
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
                .interpolationMethod(interpolationMethod)

                if showsAllPoints {
                    PointMark(
                        x: .value("포인트 거리", point.distanceKilometers),
                        y: .value("포인트 값", displayedValue(point.value))
                    )
                    .foregroundStyle(metric.tint)
                    .symbolSize(32)
                }
            }

            if let averageValue {
                RuleMark(y: .value("평균", displayedValue(averageValue)))
                    .foregroundStyle(metric.tint.opacity(0.48))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
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
                .background(FeatureChartPlotBackground(tint: metric.tint))
                .clipShape(RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous))
        }
        .chartXAxis {
            AxisMarks(values: strideValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(PNR2026.line)
                AxisTick()
                    .foregroundStyle(PNR2026.muted.opacity(0.5))
                AxisValueLabel {
                    if let distance = value.as(Double.self) {
                        Text(formatAxisDistance(distance))
                            .foregroundStyle(PNR2026.muted)
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

    private var showsAllPoints: Bool {
        points.count <= 3
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
            return valueRange.upperBound - clamped(rawValue, to: valueRange)
        case .heartRate, .cadence, .altitude:
            return clamped(rawValue, to: valueRange)
        }
    }

    private func displayedAltitude(_ rawValue: Double) -> Double {
        let chartSpan = max(valueRange.upperBound - valueRange.lowerBound, 0.1)
        let altitudeSpan = max(altitudeRange.upperBound - altitudeRange.lowerBound, 0.1)
        let ratio = (clamped(rawValue, to: altitudeRange) - altitudeRange.lowerBound) / altitudeSpan
        return chartSpan * min(max(ratio, 0), 1) * 0.55
    }

    private func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

struct PaceChartPlot: View {
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

struct HeartRateChartPlot: View {
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

func formatAxisDistance(_ distance: Double) -> String {
    RunDisplayFormatter.axisDistance(kilometers: distance)
}

struct SelectedMetrics {
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

#if DEBUG
private struct RunDetailChartPreviewScenario: Identifiable, Hashable {
    let id: String
    let title: String
    let note: String
    let run: RunningWorkout
    let detail: RunDetail

    static func == (lhs: RunDetailChartPreviewScenario, rhs: RunDetailChartPreviewScenario) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let all: [RunDetailChartPreviewScenario] = [
        RunDetailChartPreviewScenario(
            id: "complete",
            title: "정상 메트릭",
            note: "페이스, 심박, 케이던스, 고도가 있는 기본 5K",
            run: .demoSample,
            detail: .mockCompleteMetrics
        ),
        RunDetailChartPreviewScenario(
            id: "paused",
            title: "pause 포함",
            note: "segmentIndex가 갈라지는 구간과 pause 이후 연결감을 확인",
            run: Self.previewRun(distanceMeters: 2_920, duration: 720, offset: 1),
            detail: .mockPausedWorkout
        ),
        RunDetailChartPreviewScenario(
            id: "missingCadence",
            title: "케이던스 없음",
            note: "페이스/심박/고도만 있는 간단한 기록",
            run: Self.previewRun(distanceMeters: 2_980, duration: 840, offset: 2),
            detail: .mockMissingCadence
        ),
        RunDetailChartPreviewScenario(
            id: "noRoute",
            title: "경로 없음",
            note: "고도 배경 없이 거리 타임라인과 심박만 있는 케이스",
            run: Self.previewRun(distanceMeters: 3_100, duration: 900, offset: 3),
            detail: .mockMissingRoute
        ),
        RunDetailChartPreviewScenario(
            id: "noHeartRate",
            title: "심박 없음",
            note: "심박 탭이 빠지고 페이스/고도 중심으로 보이는 케이스",
            run: Self.previewRun(distanceMeters: 2_940, duration: 900, offset: 4),
            detail: .mockMissingHeartRate
        ),
        RunDetailChartPreviewScenario(
            id: "surges",
            title: "인터벌 변동",
            note: "급격한 페이스 변동에서 보간과 축 패딩을 비교",
            run: Self.previewRun(distanceMeters: 6_000, duration: 1_710, offset: 5),
            detail: .mockChartSurges
        )
    ]

    private static func previewRun(distanceMeters: Double, duration: TimeInterval, offset: Int) -> RunningWorkout {
        RunningWorkout(
            id: UUID(uuidString: "10000000-0000-0000-0000-\(String(format: "%012d", offset))") ?? UUID(),
            startDate: RunningWorkout.demoSampleStartDate.addingTimeInterval(Double(offset) * 86_400),
            duration: duration,
            distanceInMeters: distanceMeters,
            sourceName: "PNR Chart Preview",
            sourceBundleIdentifier: "com.shnoah.RunOnly.demo",
            isIndoorWorkout: false
        )
    }
}

private enum RunDetailChartPreviewRangeMode: String, CaseIterable, Identifiable {
    case production
    case tight
    case wide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .production:
            return "앱 기본 축"
        case .tight:
            return "타이트 축"
        case .wide:
            return "와이드 축"
        }
    }

    func range(metric: PerformanceChartMetric, data: PerformanceChartData) -> ClosedRange<Double> {
        let productionRange = data.valueRange(for: metric)
        let values = data.series(for: metric).map(\.value).filter(\.isFinite)
        guard !values.isEmpty else { return productionRange }

        switch self {
        case .production:
            return productionRange
        case .tight:
            return paddedRange(for: values, minimumPadding: minimumPadding(for: metric))
        case .wide:
            let range = paddedRange(for: values, minimumPadding: minimumPadding(for: metric) * 2.5)
            let extra = max(range.upperBound - range.lowerBound, 0.1) * 0.24
            return (range.lowerBound - extra)...(range.upperBound + extra)
        }
    }

    private func paddedRange(for values: [Double], minimumPadding: Double) -> ClosedRange<Double> {
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? minValue
        let padding = max((maxValue - minValue) * 0.08, minimumPadding)
        return (minValue - padding)...(maxValue + padding)
    }

    private func minimumPadding(for metric: PerformanceChartMetric) -> Double {
        switch metric {
        case .pace:
            return 20
        case .heartRate:
            return 4
        case .cadence:
            return 3
        case .altitude:
            return 2
        }
    }
}

private enum RunDetailChartPreviewSmoothingMode: String, CaseIterable, Identifiable {
    case catmullRom
    case linear
    case monotone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .catmullRom:
            return "Catmull"
        case .linear:
            return "Linear"
        case .monotone:
            return "Monotone"
        }
    }

    var interpolationMethod: InterpolationMethod {
        switch self {
        case .catmullRom:
            return .catmullRom
        case .linear:
            return .linear
        case .monotone:
            return .monotone
        }
    }
}

private struct RunDetailChartSandboxPreview: View {
    @State private var scenario = RunDetailChartPreviewScenario.all[0]
    @State private var selectedMetric: PerformanceChartMetric = .pace
    @State private var selectedDistance: Double?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                controls
                fullSection
                comparisonGrid
                scenarioMatrix
            }
            .padding(16)
        }
        .background(AppBackground())
        .preferredColorScheme(.dark)
        .onChange(of: scenario) {
            syncSelectedMetric()
        }
    }

    private var chartData: PerformanceChartData {
        PerformanceChartData(run: scenario.run, detail: scenario.detail)
    }

    private var availableMetrics: [PerformanceChartMetric] {
        chartData.availableMetrics
    }

    private var activeMetric: PerformanceChartMetric {
        availableMetrics.contains(selectedMetric) ? selectedMetric : (availableMetrics.first ?? .pace)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("RunDetailChartViews Sandbox", systemImage: "chart.line.uptrend.xyaxis")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("상세 화면 전체를 띄우지 않고 차트 데이터, 축 범위, 보간 차이를 바로 비교합니다.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("시나리오", selection: $scenario) {
                ForEach(RunDetailChartPreviewScenario.all) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if !availableMetrics.isEmpty {
                PerformanceMetricPicker(metrics: availableMetrics, selectedMetric: $selectedMetric)
            }

            Text(scenario.note)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var fullSection: some View {
        PerformanceChartSection(run: scenario.run, detail: scenario.detail)
    }

    private var comparisonGrid: some View {
        DetailSection(title: "축 / 스무딩 비교", systemImage: "slider.horizontal.3", tint: Color(red: 0.42, green: 0.76, blue: 1.0)) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RunDetailChartComparisonCard(
                    title: "앱 기본",
                    rangeMode: .production,
                    smoothingMode: .catmullRom,
                    metric: activeMetric,
                    chartData: chartData,
                    selectedDistance: $selectedDistance
                )
                RunDetailChartComparisonCard(
                    title: "선형 비교",
                    rangeMode: .production,
                    smoothingMode: .linear,
                    metric: activeMetric,
                    chartData: chartData,
                    selectedDistance: $selectedDistance
                )
                RunDetailChartComparisonCard(
                    title: "타이트 축",
                    rangeMode: .tight,
                    smoothingMode: .catmullRom,
                    metric: activeMetric,
                    chartData: chartData,
                    selectedDistance: $selectedDistance
                )
                RunDetailChartComparisonCard(
                    title: "와이드 + Monotone",
                    rangeMode: .wide,
                    smoothingMode: .monotone,
                    metric: activeMetric,
                    chartData: chartData,
                    selectedDistance: $selectedDistance
                )
            }
        }
    }

    private var scenarioMatrix: some View {
        DetailSection(title: "시나리오 매트릭스", systemImage: "square.grid.2x2.fill", tint: Color(red: 0.29, green: 0.88, blue: 0.63)) {
            VStack(spacing: 12) {
                ForEach(RunDetailChartPreviewScenario.all) { item in
                    RunDetailChartScenarioRow(
                        scenario: item,
                        metric: firstAvailableMetric(for: item),
                        selectedDistance: $selectedDistance
                    )
                }
            }
        }
    }

    private func firstAvailableMetric(for scenario: RunDetailChartPreviewScenario) -> PerformanceChartMetric {
        let data = PerformanceChartData(run: scenario.run, detail: scenario.detail)
        if data.availableMetrics.contains(activeMetric) {
            return activeMetric
        }
        return data.availableMetrics.first ?? .pace
    }

    private func syncSelectedMetric() {
        guard !availableMetrics.isEmpty else { return }
        if !availableMetrics.contains(selectedMetric) {
            selectedMetric = availableMetrics.first ?? .pace
        }
    }
}

private struct RunDetailChartComparisonCard: View {
    let title: String
    let rangeMode: RunDetailChartPreviewRangeMode
    let smoothingMode: RunDetailChartPreviewSmoothingMode
    let metric: PerformanceChartMetric
    let chartData: PerformanceChartData
    @Binding var selectedDistance: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 6)
                Text("\(rangeMode.title) / \(smoothingMode.title)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            RunMetricChartPlot(
                metric: metric,
                selectedDistance: $selectedDistance,
                selectedPoint: selectedPoint,
                points: chartData.series(for: metric),
                valueRange: rangeMode.range(metric: metric, data: chartData),
                averageValue: averageValue,
                altitudePoints: chartData.altitudeSeries,
                altitudeRange: chartData.altitudeRange,
                strideValues: chartData.strideValues,
                maxDistance: chartData.maxDistance,
                interpolationMethod: smoothingMode.interpolationMethod
            )
            .frame(height: 132)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private var selectedPoint: SimpleMetricChartPoint? {
        guard let selectedDistance else { return nil }
        return chartData.nearestSeriesPoint(for: metric, toKilometers: selectedDistance)
    }

    private var averageValue: Double? {
        let points = chartData.series(for: metric)
        guard !points.isEmpty else { return nil }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }
}

private struct RunDetailChartScenarioRow: View {
    let scenario: RunDetailChartPreviewScenario
    let metric: PerformanceChartMetric
    @Binding var selectedDistance: Double?

    var body: some View {
        let data = PerformanceChartData(run: scenario.run, detail: scenario.detail)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(scenario.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(metric.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(metric.tint)
            }

            RunMetricChartPlot(
                metric: metric,
                selectedDistance: $selectedDistance,
                selectedPoint: nil,
                points: data.series(for: metric),
                valueRange: data.valueRange(for: metric),
                averageValue: nil,
                altitudePoints: data.altitudeSeries,
                altitudeRange: data.altitudeRange,
                strideValues: data.strideValues,
                maxDistance: data.maxDistance,
                interpolationMethod: .catmullRom
            )
            .frame(height: 86)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

private extension RunDetail {
    static var mockChartSurges: RunDetail {
        let start = RunningWorkout.demoSampleStartDate.addingTimeInterval(43_200)
        let distances = stride(from: 0.0, through: 6_000.0, by: 300.0).map { $0 }

        let timeline = distances.enumerated().map { index, distance in
            DistanceTimelinePoint(
                date: start.addingTimeInterval(Double(index) * 85),
                elapsed: Double(index) * 85,
                distanceMeters: distance,
                segmentIndex: index < 10 ? 0 : 1
            )
        }

        let paceSamples = distances.dropFirst().enumerated().map { index, distance in
            let phase = Double(index % 5)
            let seconds = [255, 305, 268, 345, 282][Int(phase)]
            return PaceSample(
                date: start.addingTimeInterval(Double(index + 1) * 85),
                distanceMeters: distance,
                secondsPerKilometer: Double(seconds),
                segmentIndex: index < 9 ? 0 : 1
            )
        }

        let heartRates = distances.dropFirst().enumerated().map { index, distance in
            HeartRateSample(
                date: start.addingTimeInterval(Double(index + 1) * 85),
                bpm: 136 + min(Double(index) * 2.4, 38) + (index % 4 == 0 ? 8 : 0),
                elapsed: Double(index + 1) * 85,
                distanceMeters: distance,
                segmentIndex: index < 9 ? 0 : 1
            )
        }

        let route = distances.enumerated().map { index, distance in
            RunRoutePoint(
                latitude: 37.528 + Double(index) * 0.00035,
                longitude: 126.935 + sin(Double(index) * 0.42) * 0.002,
                timestamp: start.addingTimeInterval(Double(index) * 85),
                distanceMeters: distance,
                altitudeMeters: 14 + sin(Double(index) * 0.55) * 9 + Double(index % 3)
            )
        }

        let cadence = distances.dropFirst().enumerated().map { index, distance in
            RunningMetricSample(
                date: start.addingTimeInterval(Double(index + 1) * 85),
                value: Double([182, 174, 186, 168, 180][index % 5]),
                elapsed: Double(index + 1) * 85,
                distanceMeters: distance,
                segmentIndex: index < 9 ? 0 : 1
            )
        }

        return RunDetail(
            route: route,
            distanceTimeline: timeline,
            heartRates: heartRates,
            runningMetrics: RunningMetrics(cadence: cadence),
            paceSamples: paceSamples,
            splits: [
                RunSplit(index: 1, distanceMeters: 1_000, duration: 285, averageHeartRate: 145, averageCadence: 179),
                RunSplit(index: 2, distanceMeters: 1_000, duration: 292, averageHeartRate: 153, averageCadence: 181),
                RunSplit(index: 3, distanceMeters: 1_000, duration: 278, averageHeartRate: 162, averageCadence: 183),
                RunSplit(index: 4, distanceMeters: 1_000, duration: 302, averageHeartRate: 168, averageCadence: 176),
                RunSplit(index: 5, distanceMeters: 1_000, duration: 270, averageHeartRate: 174, averageCadence: 185),
                RunSplit(index: 6, distanceMeters: 1_000, duration: 283, averageHeartRate: 171, averageCadence: 181)
            ],
            activeDuration: 1_710
        )
    }
}

struct RunDetailChartViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RunDetailChartSandboxPreview()
                .previewDisplayName("Chart Sandbox")

            RunDetailChartSandboxPreview()
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("Chart Sandbox SE")
        }
    }
}

#Preview("Chart Sandbox") {
    RunDetailChartSandboxPreview()
}

#Preview("Chart Sandbox SE") {
    RunDetailChartSandboxPreview()
        .frame(width: 375, height: 667)
}
#endif
