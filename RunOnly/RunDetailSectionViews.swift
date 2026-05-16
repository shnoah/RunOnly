import Charts
import MapKit
import SwiftUI

struct RunPersonalRecordBanner: View {
    let achievements: [PersonalRecordDistance]

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(PNR2026.heat)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PNR2026.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(PNR2026.heat.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .stroke(PNR2026.heat.opacity(0.24), lineWidth: 1)
                )
        )
    }

    private var message: String {
        let labels = achievements.map(\.label)
        return L10n.format("축하합니다! %@ 새로운 최고 기록을 달성했습니다!", labels.joined(separator: ", "))
    }
}

struct RunRouteSection: View {
    let detail: RunDetail
    let loadState: RunDetailSupplementaryLoadState

    var body: some View {
        DetailSection(title: "경로", systemImage: "map", tint: Color(red: 0.35, green: 0.72, blue: 1.0)) {
            if detail.route.isEmpty, loadState == .loading || loadState == .idle {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("경로 데이터를 불러오는 중")
                        .foregroundStyle(.white.opacity(0.72))
                }
            } else if detail.route.isEmpty, loadState == .failed {
                Text(L10n.tr("경로 데이터를 불러오지 못했습니다."))
                    .foregroundStyle(.white.opacity(0.72))
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

struct RunSplitSection: View {
    let detail: RunDetail
    @State private var isExpanded = false

    private let collapsedSplitCount = 5

    var body: some View {
        DetailSection(title: L10n.tr("구간"), systemImage: "flag.pattern.checkered", tint: Color(red: 0.29, green: 0.88, blue: 0.63)) {
            if detail.splits.isEmpty {
                Text("스플릿을 계산할 경로 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(spacing: 0) {
                    SplitTableHeader()
                    ForEach(visibleSplits) { split in
                        SplitTableRow(split: split)
                        if split.id != visibleSplits.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                                .padding(.leading, 4)
                        }
                    }

                    if shouldCollapse {
                        SplitTableToggleButton(
                            isExpanded: isExpanded,
                            hiddenCount: hiddenSplitCount
                        ) {
                            withAnimation(.snappy(duration: 0.22)) {
                                isExpanded.toggle()
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var shouldCollapse: Bool {
        detail.splits.count > collapsedSplitCount
    }

    private var hiddenSplitCount: Int {
        max(detail.splits.count - collapsedSplitCount, 0)
    }

    private var visibleSplits: [RunSplit] {
        guard shouldCollapse, !isExpanded else { return detail.splits }
        return Array(detail.splits.prefix(collapsedSplitCount))
    }
}

struct RunOverviewMetricsSection: View {
    let run: RunningWorkout
    let summary: RunSummaryMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        RunHeroMoodBadge(text: moodBadgeText)
                        RunEnvironmentBadge(text: run.environmentBadgeText)
                    }

                    Text(run.detailDateText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PNR2026.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                Text("RUN REPORT")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(PNR2026.track.opacity(0.70))
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(run.distanceText)
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(PNR2026.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(run.paceText)
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundStyle(PNR2026.ink)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(run.durationText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PNR2026.muted)
                        .monospacedDigit()
                }
            }

            if !secondaryMetrics.isEmpty {
                HStack(spacing: 8) {
                    ForEach(secondaryMetrics) { metric in
                        RunHeroSecondaryMetric(metric: metric)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            heroTint.opacity(0.16),
                            PNR2026.water.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .stroke(PNR2026.line, lineWidth: 1)
                )
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

    private var heroTint: Color {
        run.isIndoorWorkout == true ? PNR2026.heat : PNR2026.track
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

struct RunHeroPrimaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        PNRMetricBlock(title: title, value: value, tint: PNR2026.track)
    }
}

struct RunOverviewSecondaryMetric: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

struct RunHeroSecondaryMetric: View {
    let metric: RunOverviewSecondaryMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(metric.title))
                .font(.caption2.weight(.bold))
                .foregroundStyle(PNR2026.muted)
            Text(metric.value)
                .font(.caption.weight(.black))
                .foregroundStyle(PNR2026.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(Color.black.opacity(0.16))
        )
    }
}

struct RunHeroMoodBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.black))
            .foregroundStyle(PNR2026.track)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(PNR2026.track.opacity(0.14))
            )
    }
}

struct HeartRateZoneSection: View {
    let detail: RunDetail
    let loadState: RunDetailSupplementaryLoadState
    private let zoneRows: [HeartRateZoneRowModel]

    init(detail: RunDetail, loadState: RunDetailSupplementaryLoadState) {
        self.detail = detail
        self.loadState = loadState
        self.zoneRows = HeartRateZoneRowModel.build(
            distribution: detail.heartRateZoneDistribution,
            heartRates: detail.heartRates,
            zoneProfile: detail.heartRateZoneProfile,
            activeDuration: detail.activeDuration
        )
    }

    var body: some View {
        DetailSection(title: "심박", systemImage: "heart.fill", tint: Color(red: 0.94, green: 0.41, blue: 0.45)) {
            if zoneRows.isEmpty, loadState == .loading || loadState == .idle {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("심박 존 데이터를 계산하는 중")
                        .foregroundStyle(.white.opacity(0.72))
                }
            } else if zoneRows.isEmpty, loadState == .failed {
                Text(L10n.tr("심박 존 데이터를 불러오지 못했습니다."))
                    .foregroundStyle(.white.opacity(0.72))
            } else if zoneRows.isEmpty {
                Text("심박 데이터가 부족해 존 분포를 계산할 수 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(zoneRows) { zone in
                        HeartRateZoneRow(zone: zone)
                    }

                    if loadState == .provisional {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text(L10n.tr("개인 기준으로 갱신하는 중"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.56))
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }
}

struct RunDataSourceSection: View {
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

struct HeartRateZoneRowModel: Identifiable {
    let id = UUID()
    let title: String
    let duration: TimeInterval
    let percentage: Double
    let color: Color

    static func build(
        distribution: HeartRateZoneDistribution?,
        heartRates: [HeartRateSample],
        zoneProfile: HeartRateZoneProfile?,
        activeDuration: TimeInterval
    ) -> [HeartRateZoneRowModel] {
        let displayRows: [(label: String, color: Color)] = [
            (L10n.tr("존 1"), Color(red: 0.42, green: 0.76, blue: 1.0)),
            (L10n.tr("존 2"), Color(red: 0.45, green: 0.95, blue: 0.76)),
            (L10n.tr("존 3"), Color(red: 0.95, green: 0.84, blue: 0.40)),
            (L10n.tr("존 4"), Color(red: 0.95, green: 0.59, blue: 0.32)),
            (L10n.tr("존 5"), Color(red: 0.94, green: 0.41, blue: 0.45))
        ]

        let resolvedDistribution = distribution ?? HeartRateZoneDistribution.build(
            heartRates: heartRates,
            zoneProfile: zoneProfile,
            activeDuration: activeDuration
        )
        guard let resolvedDistribution else { return [] }

        return resolvedDistribution.entries.compactMap { entry in
            guard displayRows.indices.contains(entry.zoneIndex) else {
                return nil
            }
            let displayRow = displayRows[entry.zoneIndex]
            return HeartRateZoneRowModel(
                title: displayRow.label,
                duration: entry.duration,
                percentage: entry.percentage,
                color: displayRow.color
            )
        }
    }
}

struct HeartRateZoneRow: View {
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

extension HeartRateZoneRowModel {
    var percentageText: String {
        "\((percentage * 100).formatted(.number.precision(.fractionLength(0))))%"
    }
}

struct SimpleMetricChartPoint: Identifiable {
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

struct SyncedMetricChartPlot: View {
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

struct AdditionalMetricChart: View {
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

struct SplitTableHeader: View {
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

struct SplitTableRow: View {
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

struct SplitTableToggleButton: View {
    let isExpanded: Bool
    let hiddenCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white.opacity(0.86))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        if isExpanded {
            return L10n.tr("간단히 보기")
        }

        return L10n.format("%d개 구간 더보기", hiddenCount)
    }
}

enum SplitColumnLayout {
    static let spacing: CGFloat = 10
    static let distanceWidth: CGFloat = 48
    static let paceWidth: CGFloat = 88
    static let heartWidth: CGFloat = 72
    static let cadenceWidth: CGFloat = 82
}

struct RouteMapView: View {
    private let displayData: RouteMapDisplayData
    @State private var position: MapCameraPosition = .automatic

    init(points: [RunRoutePoint]) {
        self.displayData = RouteMapDisplayData(points: points)
    }

    var body: some View {
        Map(position: $position) {
            if let start = displayData.startCoordinate {
                Annotation("Start", coordinate: start) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                }
            }

            if let end = displayData.endCoordinate {
                Annotation("End", coordinate: end) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                }
            }

            MapPolyline(coordinates: displayData.coordinates)
                .stroke(Color(red: 0.29, green: 0.88, blue: 0.63), lineWidth: 5)
        }
        .mapStyle(.standard(elevation: .flat))
        .onAppear {
            position = .rect(displayData.mapRect)
        }
    }
}

private struct RouteMapDisplayData {
    let coordinates: [CLLocationCoordinate2D]
    let startCoordinate: CLLocationCoordinate2D?
    let endCoordinate: CLLocationCoordinate2D?
    let mapRect: MKMapRect

    init(points: [RunRoutePoint]) {
        let displayPoints = Self.downsample(points, maxCount: 800)
        coordinates = displayPoints.map(\.coordinate)
        startCoordinate = points.first?.coordinate
        endCoordinate = points.last?.coordinate
        mapRect = Self.makeMapRect(from: displayPoints)
    }

    private static func makeMapRect(from points: [RunRoutePoint]) -> MKMapRect {
        let mapPoints = points.map { MKMapPoint($0.coordinate) }
        guard let first = mapPoints.first else { return .world }

        return mapPoints.dropFirst().reduce(
            MKMapRect(origin: first, size: MKMapSize(width: 0, height: 0))
        ) { partialResult, point in
            partialResult.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
    }

    private static func downsample(_ points: [RunRoutePoint], maxCount: Int) -> [RunRoutePoint] {
        guard points.count > maxCount, maxCount > 2 else { return points }
        let stride = Double(points.count - 1) / Double(maxCount - 1)
        var result: [RunRoutePoint] = []
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
}

extension RunRoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PaceChartPoint: Identifiable {
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

struct HeartRateChartPoint: Identifiable {
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

struct DemoScenarioPanel: View {
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
                Button("케이던스 없음") {
                    Task {
                        await viewModel.applyDebugScenario(.missingCadence)
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

struct RunGearSection: View {
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
