import SwiftUI

struct RunShareArtworkView: View {
    let run: RunningWorkout
    let detail: RunDetail
    let template: RunShareTemplate
    let enabledFields: Set<RunShareField>
    let summary: RunSummaryMetrics?
    let style: RunShareArtworkStyle

    private var metrics: [RunShareMetric] {
        var items: [RunShareMetric] = []

        if enabledFields.contains(.distance) {
            items.append(RunShareMetric(field: .distance, title: L10n.tr("거리"), value: run.distanceText))
        }
        if enabledFields.contains(.duration) {
            items.append(RunShareMetric(field: .duration, title: L10n.tr("시간"), value: run.durationText))
        }
        if enabledFields.contains(.pace) {
            items.append(RunShareMetric(field: .pace, title: L10n.tr("페이스"), value: run.paceText))
        }
        if enabledFields.contains(.elevationGain), let elevationGainText {
            items.append(RunShareMetric(field: .elevationGain, title: L10n.tr("상승"), value: elevationGainText))
        }
        if enabledFields.contains(.heartRate), let averageHeartRateText {
            items.append(RunShareMetric(field: .heartRate, title: L10n.tr("심박"), value: averageHeartRateText))
        }
        if enabledFields.contains(.cadence), let averageCadenceText {
            items.append(RunShareMetric(field: .cadence, title: L10n.tr("케이던스"), value: averageCadenceText))
        }

        return items
    }

    private var routeHeight: CGFloat {
        switch template {
        case .sticker:
            return 315
        case .style1:
            return 160
        case .microInline, .minimalStack, .glassPills, .serifCaption, .raceLabel:
            return 180
        }
    }

    private var elevationGainText: String? {
        summary?.elevationGainText
    }

    private var contentPadding: CGFloat {
        switch template {
        case .sticker:
            return 24
        case .style1:
            return 20
        case .microInline:
            return 12
        case .minimalStack:
            return 18
        case .glassPills:
            return 12
        case .serifCaption:
            return 10
        case .raceLabel:
            return 16
        }
    }

    private var headerBrandFontSize: CGFloat {
        switch template {
        case .sticker:
            return 18
        case .style1:
            return 16
        case .microInline, .minimalStack, .glassPills, .serifCaption, .raceLabel:
            return 14
        }
    }

    private var stickerRouteWidth: CGFloat {
        472
    }

    private var styleOneMetrics: [RunShareMetric] {
        let ordered = runShareMetricPriority.filter {
            [.distance, .duration, .pace].contains($0) && enabledFields.contains($0)
        }

        let mapped = ordered.map { field in
            switch field {
            case .distance:
                return RunShareMetric(field: field, title: "Distance", value: run.distanceText)
            case .duration:
                return RunShareMetric(field: field, title: "Time", value: run.durationText)
            case .pace:
                return RunShareMetric(field: field, title: "Pace", value: run.paceText)
            default:
                return RunShareMetric(field: field, title: field.label, value: "")
            }
        }

        if mapped.isEmpty {
            return [
                RunShareMetric(field: .distance, title: "Distance", value: run.distanceText)
            ]
        }

        return Array(mapped.prefix(2))
    }

    private var enabledMetricsInPriorityOrder: [RunShareMetric] {
        runShareMetricPriority.compactMap { field in
            metrics.first { $0.field == field }
        }
    }

    var body: some View {
        Group {
            switch template {
            case .sticker:
                stickerLayout
            case .style1:
                styleOneLayout
            case .microInline:
                microInlineLayout
            case .minimalStack:
                minimalStackLayout
            case .glassPills:
                glassPillsLayout
            case .serifCaption:
                serifCaptionLayout
            case .raceLabel:
                raceLabelLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var header: some View {
        if enabledFields.contains(.logo) {
            if template == .sticker {
                Text("PNR")
                    .font(style.fontChoice.font(size: style.scaled(headerBrandFontSize), weight: .heavy))
                    .foregroundStyle(style.accentColor)
                    .tracking(1.2)
                    .shadow(color: style.accentColor.opacity(0.26), radius: 10, y: 2)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack {
                    Text("PNR")
                        .font(style.fontChoice.font(size: style.scaled(headerBrandFontSize), weight: .heavy))
                        .foregroundStyle(style.accentColor)
                        .tracking(0.8)
                        .shadow(color: style.accentColor.opacity(0.26), radius: 10, y: 2)
                    Spacer()
                }
            }
        }
    }

    private var stickerLayout: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)
                .padding(.bottom, 6)

            if enabledFields.contains(.route) {
                RunShareRouteCanvas(route: detail.route, style: style)
                    .frame(width: stickerRouteWidth, height: routeHeight)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 18)
            }

            if !metrics.isEmpty {
                VStack(spacing: 12) {
                    ForEach(metrics) { metric in
                        RunShareMetricTile(metric: metric, template: template, centered: true, style: style)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, metaPills.isEmpty ? 0 : 10)
            }

            if !metaPills.isEmpty {
                VStack(spacing: 4) {
                    ForEach(metaPills, id: \.self) { item in
                        ShareMetaPill(text: item, centered: true, style: style)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
        }
        .padding(contentPadding)
    }

    private var styleOneLayout: some View {
        let singleMetricMode = styleOneMetrics.count == 1

        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 20) {
                if singleMetricMode, let first = styleOneMetrics.first {
                    StyleOneMetricRow(metric: first, style: style, centered: true)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(styleOneMetrics) { metric in
                            StyleOneMetricRow(metric: metric, style: style, centered: false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if enabledFields.contains(.route) {
                    StyleOneRouteCanvas(route: detail.route, style: style)
                        .frame(width: 292, height: 172)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.46))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.13), lineWidth: 0.9)
                    )
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var microInlineLayout: some View {
        HStack(spacing: 14) {
            Text(run.distanceText.uppercased())
            Text("·")
                .foregroundStyle(.white.opacity(0.36))
            Text(run.durationText)
            Text("·")
                .foregroundStyle(.white.opacity(0.36))
            Text(run.paceText)
            Text("PNR")
                .foregroundStyle(style.accentColor)
                .padding(.leading, 6)
        }
        .font(style.fontChoice.font(size: 44, weight: .black))
        .foregroundStyle(.white)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var minimalStackLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            RunShareMiniStackRow(label: "DIST", value: run.distanceText, style: style)
            RunShareMiniStackRow(label: "TIME", value: run.durationText, style: style)
            RunShareMiniStackRow(label: "PACE", value: run.paceText, style: style)
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var glassPillsLayout: some View {
        HStack(spacing: 12) {
            RunShareGlassPill(text: run.distanceText.uppercased(), style: style)
            RunShareGlassPill(text: run.durationText, style: style)
            RunShareGlassPill(text: run.paceText, style: style)
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var serifCaptionLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("easy miles")
                .font(.system(size: 58, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text("\(run.distanceText.lowercased()) / \(run.durationText)")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(style.accentColor.opacity(0.9))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var raceLabelLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("PNR RUN 004")
                Circle()
                    .fill(style.accentColor)
                    .frame(width: 7, height: 7)
            }
            .font(style.fontChoice.font(size: 20, weight: .black))
            .foregroundStyle(.white.opacity(0.76))

            Text("\(run.distanceText.uppercased())  \(run.durationText)")
                .font(style.fontChoice.font(size: 42, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var metaPills: [String] {
        var items: [String] = []

        if enabledFields.contains(.date) {
            items.append(shareDateText)
        }

        return items
    }

    private var averageHeartRateText: String? {
        summary?.averageHeartRateText
    }

    private var averageCadenceText: String? {
        summary?.averageCadenceText
    }

    private var shareDateText: String {
        RunDisplayFormatter.shareDate(run.startDate)
    }
}

struct RunShareTemplateBackground: View {
    let template: RunShareTemplate
    let style: RunShareArtworkStyle

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.10),
                    Color(red: 0.14, green: 0.15, blue: 0.19),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(style.accentColor.opacity(0.16))
                .frame(width: 340)
                .blur(radius: 24)
                .offset(x: 180, y: -220)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 280)
                .blur(radius: 18)
                .offset(x: -160, y: 260)
        }
    }
}

struct RunShareRouteCanvas: View {
    let route: [RunRoutePoint]
    let style: RunShareArtworkStyle

    var body: some View {
        GeometryReader { geometry in
            let projection = RouteProjection(route: route, size: geometry.size, padding: 18, maxPointCount: 600)

            ZStack {
                if let projection {
                    Path { path in
                        guard let first = projection.points.first else { return }
                        path.move(to: first)
                        for point in projection.points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [
                                style.accentColor,
                                style.accentShadowColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: style.accentColor.opacity(0.28), radius: 18, y: 10)
                } else {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.44))
                                Text("경로 없음")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.44))
                            }
                        )
                }
            }
        }
    }
}

struct RouteProjection {
    let points: [CGPoint]
    let startPoint: CGPoint
    let endPoint: CGPoint

    init?(route: [RunRoutePoint], size: CGSize, padding: CGFloat, maxPointCount: Int? = nil) {
        guard route.count >= 2 else { return nil }

        let latitudes = route.map(\.latitude)
        let longitudes = route.map(\.longitude)

        guard
            let minLatitude = latitudes.min(),
            let maxLatitude = latitudes.max(),
            let minLongitude = longitudes.min(),
            let maxLongitude = longitudes.max()
        else {
            return nil
        }

        let longitudeSpan = max(maxLongitude - minLongitude, 0.00001)
        let latitudeSpan = max(maxLatitude - minLatitude, 0.00001)
        let availableWidth = max(size.width - padding * 2, 1)
        let availableHeight = max(size.height - padding * 2, 1)
        let scale = min(availableWidth / longitudeSpan, availableHeight / latitudeSpan)
        let contentWidth = longitudeSpan * scale
        let contentHeight = latitudeSpan * scale
        let offsetX = (size.width - contentWidth) / 2
        let offsetY = (size.height - contentHeight) / 2

        let projectedPoints = route.map { point in
            CGPoint(
                x: offsetX + (point.longitude - minLongitude) * scale,
                y: offsetY + (maxLatitude - point.latitude) * scale
            )
        }

        let simplifiedPoints = RunShareRoutePointSimplifier.simplify(
            projectedPoints,
            maxCount: maxPointCount ?? projectedPoints.count,
            tolerance: max(min(size.width, size.height) / 280, 0.65)
        )

        guard let startPoint = simplifiedPoints.first, let endPoint = simplifiedPoints.last else {
            return nil
        }

        self.points = simplifiedPoints
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
}

private enum RunShareRoutePointSimplifier {
    static func simplify(_ points: [CGPoint], maxCount: Int, tolerance: CGFloat) -> [CGPoint] {
        let clampedMaxCount = max(2, maxCount)
        guard points.count > clampedMaxCount else { return points }

        let simplified = ramerDouglasPeucker(points, tolerance: tolerance)
        guard simplified.count > clampedMaxCount else { return simplified }

        return cap(simplified, maxCount: clampedMaxCount)
    }

    private static func ramerDouglasPeucker(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var kept = Array(repeating: false, count: points.count)
        kept[0] = true
        kept[points.count - 1] = true

        var stack: [(start: Int, end: Int)] = [(0, points.count - 1)]

        while let segment = stack.popLast() {
            guard segment.end > segment.start + 1 else { continue }

            var furthestIndex = segment.start
            var furthestDistance: CGFloat = 0
            let lineStart = points[segment.start]
            let lineEnd = points[segment.end]

            for index in (segment.start + 1)..<segment.end {
                let distance = perpendicularDistance(
                    from: points[index],
                    lineStart: lineStart,
                    lineEnd: lineEnd
                )

                if distance > furthestDistance {
                    furthestDistance = distance
                    furthestIndex = index
                }
            }

            if furthestDistance > tolerance {
                kept[furthestIndex] = true
                stack.append((segment.start, furthestIndex))
                stack.append((furthestIndex, segment.end))
            }
        }

        return points.enumerated().compactMap { index, point in
            kept[index] ? point : nil
        }
    }

    private static func cap(_ points: [CGPoint], maxCount: Int) -> [CGPoint] {
        guard points.count > maxCount else { return points }
        guard maxCount > 2 else { return [points[0], points[points.count - 1]] }

        return (0..<maxCount).map { index in
            if index == 0 {
                return points[0]
            }
            if index == maxCount - 1 {
                return points[points.count - 1]
            }

            let rawIndex = Double(index) * Double(points.count - 1) / Double(maxCount - 1)
            return points[Int(rawIndex.rounded())]
        }
    }

    private static func perpendicularDistance(from point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let denominator = hypot(dx, dy)

        guard denominator > 0.0001 else {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }

        let numerator = abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x)
        return numerator / denominator
    }
}

struct StyleOneMetricRow: View {
    let metric: RunShareMetric
    let style: RunShareArtworkStyle
    let centered: Bool

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 2) {
            Text(metric.title)
                .font(style.fontChoice.font(size: style.scaled(21), weight: .semibold))
                .foregroundStyle(style.accentColor.opacity(0.78))
                .tracking(0.15)
                .lineLimit(1)

            Text(metric.value)
                .font(style.fontChoice.font(size: style.scaled(64), weight: .heavy))
                .italic()
                .foregroundStyle(style.accentColor.opacity(0.98))
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
        .frame(minWidth: centered ? 220 : 180, maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

struct StyleOneRouteCanvas: View {
    let route: [RunRoutePoint]
    let style: RunShareArtworkStyle

    var body: some View {
        GeometryReader { geometry in
            let projection = RouteProjection(route: route, size: geometry.size, padding: 12, maxPointCount: 400)

            ZStack {
                if let projection {
                    Path { path in
                        guard let first = projection.points.first else { return }
                        path.move(to: first)
                        for point in projection.points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        style.accentColor.opacity(0.92),
                        style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: style.accentShadowColor.opacity(0.34), radius: 4, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("경로 없음")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.white.opacity(0.42))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct RunShareMiniStackRow: View {
    let label: String
    let value: String
    let style: RunShareArtworkStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(label)
                .font(style.fontChoice.font(size: 22, weight: .black))
                .foregroundStyle(style.accentColor.opacity(0.94))
                .frame(width: 62, alignment: .leading)

            Text(value)
                .font(style.fontChoice.font(size: 34, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
    }
}

struct RunShareGlassPill: View {
    let text: String
    let style: RunShareArtworkStyle

    var body: some View {
        Text(text)
            .font(style.fontChoice.font(size: 30, weight: .black))
            .foregroundStyle(.white.opacity(0.96))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.26), lineWidth: 1)
                    )
                    .shadow(color: style.accentColor.opacity(0.16), radius: 18, y: 8)
            )
    }
}

struct RunShareCompactMetric: View {
    let metric: RunShareMetric
    let style: RunShareArtworkStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.title)
                .font(style.fontChoice.font(size: style.scaled(15), weight: .bold))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)

            Text(metric.value)
                .font(style.fontChoice.font(size: style.scaled(34), weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.56)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct RunShareReceiptRow: View {
    let metric: RunShareMetric
    let style: RunShareArtworkStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(metric.title.uppercased())
                .font(style.fontChoice.font(size: style.scaled(17), weight: .bold))
                .foregroundStyle(.white.opacity(0.62))

            Spacer(minLength: 20)

            Text(metric.value)
                .font(style.fontChoice.font(size: style.scaled(30), weight: .heavy))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.56)
        }
        .padding(.vertical, 18)
    }
}

struct RunShareMetricTile: View {
    let metric: RunShareMetric
    let template: RunShareTemplate
    let centered: Bool
    let style: RunShareArtworkStyle

    private var valueFontSize: CGFloat {
        switch template {
        case .sticker:
            return 64
        case .style1:
            return 56
        case .microInline, .minimalStack, .glassPills, .serifCaption, .raceLabel:
            return 34
        }
    }

    private var labelFontSize: CGFloat {
        switch template {
        case .sticker:
            return 24
        case .style1:
            return 22
        case .microInline, .minimalStack, .glassPills, .serifCaption, .raceLabel:
            return 15
        }
    }

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: centered ? 6 : 8) {
            Text(metric.title)
                .font(style.fontChoice.font(size: style.scaled(labelFontSize), weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
                .tracking(0.2)

            Text(metric.value)
                .font(style.fontChoice.font(size: style.scaled(valueFontSize), weight: .heavy))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.28), radius: 6, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

struct ShareMetaPill: View {
    let text: String
    let centered: Bool
    let style: RunShareArtworkStyle

    private let baseFontSize: CGFloat = 16

    var body: some View {
        Text(text)
            .font(style.fontChoice.font(size: style.scaled(baseFontSize), weight: .semibold))
            .foregroundStyle(style.accentColor.opacity(0.94))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

struct RunShareMetaCapsule: View {
    let text: String
    let style: RunShareArtworkStyle

    var body: some View {
        Text(text)
            .font(style.fontChoice.font(size: style.scaled(16), weight: .semibold))
            .foregroundStyle(style.accentColor.opacity(0.96))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

struct TransparentPreviewBackground: View {
    private let tileSize: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.04)))

            let rows = Int(ceil(size.height / tileSize))
            let columns = Int(ceil(size.width / tileSize))

            for row in 0...rows {
                for column in 0...columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.08)))
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
