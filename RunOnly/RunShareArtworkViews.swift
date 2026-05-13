import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

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
        }
    }

    private var headerBrandFontSize: CGFloat {
        switch template {
        case .sticker:
            return 18
        case .style1:
            return 16
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

    var body: some View {
        Group {
            switch template {
            case .sticker:
                stickerLayout
            case .style1:
                styleOneLayout
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

struct RunSharePhotoCompositeView: View {
    let run: RunningWorkout
    let detail: RunDetail
    let template: RunShareTemplate
    let enabledFields: Set<RunShareField>
    let summary: RunSummaryMetrics?
    let style: RunShareArtworkStyle
    let layoutSpec: RunShareTemplateLayoutSpec
    let backgroundImage: UIImage
    let stickerPreviewImage: UIImage?
    @Binding var stickerPlacement: RunShareStickerPlacement
    let interactive: Bool

    @GestureState private var dragTranslation: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let stickerSize = stickerCanvasSize(in: geometry.size)
            let livePlacement = translatedPlacement(
                from: stickerPlacement,
                translation: interactive ? dragTranslation : .zero,
                canvasSize: geometry.size,
                stickerSize: stickerSize
            )

            ZStack {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                stickerLayer(size: stickerSize)
                    .position(
                        x: livePlacement.centerX * geometry.size.width,
                        y: livePlacement.centerY * geometry.size.height
                    )
                    .shadow(
                        color: .black.opacity(template == .style1 ? 0.18 : 0.24),
                        radius: template == .style1 ? 12 : 24,
                        y: template == .style1 ? 4 : 12
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .updating($dragTranslation) { value, state, _ in
                                guard interactive else { return }
                                state = value.translation
                            }
                            .onEnded { value in
                                guard interactive else { return }
                                stickerPlacement = translatedPlacement(
                                    from: stickerPlacement,
                                    translation: value.translation,
                                    canvasSize: geometry.size,
                                    stickerSize: stickerSize
                                )
                            }
                    )
            }
        }
    }

    @ViewBuilder
    private func stickerLayer(size: CGSize) -> some View {
        if interactive, let stickerPreviewImage {
            Image(uiImage: stickerPreviewImage)
                .resizable()
                .interpolation(.high)
                .frame(width: size.width, height: size.height)
        } else {
            RunShareArtworkView(
                run: run,
                detail: detail,
                template: template,
                enabledFields: enabledFields,
                summary: summary,
                style: style
            )
            .frame(width: size.width, height: size.height)
        }
    }

    private func stickerCanvasSize(in canvasSize: CGSize) -> CGSize {
        let aspectRatio = template.canvasSize.height / max(template.canvasSize.width, 1)
        let baseWidth = min(
            canvasSize.width * layoutSpec.photoBaseWidthRatio,
            canvasSize.height * layoutSpec.photoBaseHeightRatio
        )
        let width = max(baseWidth * stickerPlacement.scale, 120)
        return CGSize(width: width, height: width * aspectRatio)
    }

    private func translatedPlacement(
        from placement: RunShareStickerPlacement,
        translation: CGSize,
        canvasSize: CGSize,
        stickerSize: CGSize
    ) -> RunShareStickerPlacement {
        let halfWidth = min((stickerSize.width / max(canvasSize.width, 1)) / 2, 0.5)
        let halfHeight = min((stickerSize.height / max(canvasSize.height, 1)) / 2, 0.5)

        var updated = placement
        updated.centerX += translation.width / max(canvasSize.width, 1)
        updated.centerY += translation.height / max(canvasSize.height, 1)
        updated.centerX = min(max(updated.centerX, halfWidth), 1 - halfWidth)
        updated.centerY = min(max(updated.centerY, halfHeight), 1 - halfHeight)
        return updated
    }
}

struct RunShareRouteCanvas: View {
    let route: [RunRoutePoint]
    let style: RunShareArtworkStyle

    var body: some View {
        GeometryReader { geometry in
            let projection = RouteProjection(route: route, size: geometry.size, padding: 18)

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

    init?(route: [RunRoutePoint], size: CGSize, padding: CGFloat) {
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

        guard let startPoint = projectedPoints.first, let endPoint = projectedPoints.last else {
            return nil
        }

        self.points = projectedPoints
        self.startPoint = startPoint
        self.endPoint = endPoint
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
            let projection = RouteProjection(route: route, size: geometry.size, padding: 12)

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
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.42))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
        }
    }

    private var labelFontSize: CGFloat {
        switch template {
        case .sticker:
            return 24
        case .style1:
            return 22
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
