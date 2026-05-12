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

struct PerformanceMetricPicker: View {
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

struct RunMetricChartPlot: View {
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

