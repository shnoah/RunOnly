import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private struct RunShareStickerPlacement: Equatable {
    var centerX: CGFloat
    var centerY: CGFloat
    var scale: CGFloat
}

private struct RunShareTemplateLayoutSpec {
    let previewPreferredWidth: CGFloat
    let photoBaseWidthRatio: CGFloat
    let photoBaseHeightRatio: CGFloat
    let defaultPlacement: RunShareStickerPlacement
    let fontScaleRange: ClosedRange<Double>
}

private struct RunShareBackgroundPhotoAssets {
    let renderImage: UIImage
    let previewImage: UIImage
}

private enum RunShareTemplate: String, CaseIterable, Identifiable {
    case sticker
    case style1

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sticker:
            return L10n.tr("스티커")
        case .style1:
            return L10n.tr("스타일 1")
        }
    }

    var descriptionText: String {
        switch self {
        case .sticker:
            return L10n.tr("투명 배경 PNG라 메신저, 노트, 스토리 편집 앱에 붙여 넣기 좋습니다.")
        case .style1:
            return L10n.tr("인스타 스토리 상단 오버레이 느낌의 반투명 스티커입니다.")
        }
    }

    var canvasSize: CGSize {
        switch self {
        case .sticker:
            return CGSize(width: 520, height: 860)
        case .style1:
            return CGSize(width: 1080, height: 300)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .sticker:
            return 0
        case .style1:
            return 0
        }
    }

    func previewHeight(for width: CGFloat) -> CGFloat {
        width * (canvasSize.height / canvasSize.width)
    }

    var composerPreviewWidth: CGFloat {
        layoutSpec.previewPreferredWidth
    }

    var isTransparentStickerTemplate: Bool {
        true
    }

    var policy: RunShareTemplatePolicy {
        switch self {
        case .style1:
            return RunShareTemplatePolicy(
                routeRequired: true,
                metricCandidates: [.distance, .duration, .pace],
                requiredMetrics: [.distance],
                metricMin: 1,
                metricMax: 2,
                supportsFontDebug: true,
                supportsColorDebug: true
            )
        case .sticker:
            return RunShareTemplatePolicy(
                routeRequired: true,
                metricCandidates: [.distance, .duration, .pace, .elevationGain, .heartRate, .cadence],
                requiredMetrics: [],
                metricMin: 0,
                metricMax: 4,
                supportsFontDebug: true,
                supportsColorDebug: true
            )
        }
    }

    var layoutSpec: RunShareTemplateLayoutSpec {
        switch self {
        case .sticker:
            return RunShareTemplateLayoutSpec(
                previewPreferredWidth: 172,
                photoBaseWidthRatio: 0.46,
                photoBaseHeightRatio: 0.58,
                defaultPlacement: RunShareStickerPlacement(centerX: 0.5, centerY: 0.62, scale: 1),
                fontScaleRange: 0.75...1.45
            )
        case .style1:
            return RunShareTemplateLayoutSpec(
                previewPreferredWidth: 440,
                photoBaseWidthRatio: 0.86,
                photoBaseHeightRatio: 0.75,
                defaultPlacement: RunShareStickerPlacement(centerX: 0.5, centerY: 0.15, scale: 1),
                fontScaleRange: 0.92...1.22
            )
        }
    }

    static var defaultPlacements: [RunShareTemplate: RunShareStickerPlacement] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.layoutSpec.defaultPlacement) })
    }
}

private enum RunShareField: String, CaseIterable, Identifiable {
    case logo
    case route
    case date
    case environment
    case distance
    case duration
    case pace
    case elevationGain
    case heartRate
    case cadence
    case shoe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .logo:
            return "RUNONLY"
        case .route:
            return L10n.tr("경로")
        case .date:
            return L10n.tr("날짜")
        case .environment:
            return L10n.tr("실내/실외")
        case .distance:
            return L10n.tr("거리")
        case .duration:
            return L10n.tr("시간")
        case .pace:
            return L10n.tr("페이스")
        case .elevationGain:
            return L10n.tr("상승 고도")
        case .heartRate:
            return L10n.tr("심박")
        case .cadence:
            return L10n.tr("케이던스")
        case .shoe:
            return L10n.tr("신발")
        }
    }

    var systemImage: String {
        switch self {
        case .logo:
            return "app.badge"
        case .route:
            return "point.topleft.down.curvedto.point.bottomright.up"
        case .date:
            return "calendar"
        case .environment:
            return "figure.run"
        case .distance:
            return "ruler"
        case .duration:
            return "timer"
        case .pace:
            return "speedometer"
        case .elevationGain:
            return "mountain.2.fill"
        case .heartRate:
            return "heart.fill"
        case .cadence:
            return "metronome"
        case .shoe:
            return "shoeprints.fill"
        }
    }
}

private struct RunShareMetric: Identifiable {
    let field: RunShareField
    let title: String
    let value: String

    var id: RunShareField { field }
}

private let runShareBasicInfoFields: [RunShareField] = [.logo, .route, .date]
private let runShareMetricPriority: [RunShareField] = [.distance, .duration, .pace, .elevationGain, .heartRate, .cadence]

private let runOnlyShareAccent = Color(red: 0.29, green: 0.88, blue: 0.63)
private let runOnlyShareAccentDark = Color(red: 0.15, green: 0.71, blue: 0.49)

private enum RunShareFontChoice: String, CaseIterable, Identifiable {
    case rounded
    case system
    case serif
    case monospaced
    case condensed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rounded:
            return L10n.tr("둥근")
        case .system:
            return L10n.tr("기본")
        case .serif:
            return L10n.tr("세리프")
        case .monospaced:
            return L10n.tr("모노")
        case .condensed:
            return L10n.tr("콘덴스")
        }
    }

    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .system:
            return .system(size: size, weight: weight, design: .default)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .monospaced:
            return .system(size: size, weight: weight, design: .monospaced)
        case .condensed:
            return .custom("HelveticaNeue-CondensedBold", size: size)
        }
    }
}

private struct RunShareArtworkStyle {
    let accentColor: Color
    let accentShadowColor: Color
    let fontChoice: RunShareFontChoice
    let fontScale: Double

    static let `default` = Self(
        accentColor: runOnlyShareAccent,
        accentShadowColor: runOnlyShareAccentDark,
        fontChoice: .rounded,
        fontScale: 1
    )

    func scaled(_ size: CGFloat) -> CGFloat {
        size * fontScale
    }
}

private struct RunShareTemplatePolicy {
    let routeRequired: Bool
    let metricCandidates: [RunShareField]
    let requiredMetrics: [RunShareField]
    let metricMin: Int
    let metricMax: Int
    let supportsFontDebug: Bool
    let supportsColorDebug: Bool
}

private struct RunShareRGBA: Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var key: String {
        String(format: "%.3f|%.3f|%.3f|%.3f", red, green, blue, alpha)
    }

    func darkened(by factor: Double = 0.72) -> RunShareRGBA {
        RunShareRGBA(
            red: max(min(red * factor, 1), 0),
            green: max(min(green * factor, 1), 0),
            blue: max(min(blue * factor, 1), 0),
            alpha: alpha
        )
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
        } else {
            self.init(red: 0.29, green: 0.88, blue: 0.63, alpha: 1)
        }
        #else
        self.init(red: 0.29, green: 0.88, blue: 0.63, alpha: 1)
        #endif
    }
}

private enum RunShareAccentPreset: String, CaseIterable, Identifiable {
    case mint
    case sky
    case ocean
    case coral
    case amber
    case lime
    case violet
    case rose
    case slate

    var id: String { rawValue }

    var accent: RunShareRGBA {
        switch self {
        case .mint:
            return RunShareRGBA(red: 0.29, green: 0.88, blue: 0.63)
        case .sky:
            return RunShareRGBA(red: 0.33, green: 0.75, blue: 0.98)
        case .ocean:
            return RunShareRGBA(red: 0.30, green: 0.60, blue: 0.98)
        case .coral:
            return RunShareRGBA(red: 0.98, green: 0.50, blue: 0.45)
        case .amber:
            return RunShareRGBA(red: 0.98, green: 0.76, blue: 0.32)
        case .lime:
            return RunShareRGBA(red: 0.70, green: 0.90, blue: 0.38)
        case .violet:
            return RunShareRGBA(red: 0.66, green: 0.55, blue: 0.94)
        case .rose:
            return RunShareRGBA(red: 0.92, green: 0.68, blue: 0.84)
        case .slate:
            return RunShareRGBA(red: 0.55, green: 0.63, blue: 0.76)
        }
    }
}

private enum RunShareAccentColorSource: Equatable {
    case preset(RunShareAccentPreset)
    case custom(RunShareRGBA)

    var accent: RunShareRGBA {
        switch self {
        case .preset(let preset):
            return preset.accent
        case .custom(let value):
            return value
        }
    }

    var shadow: RunShareRGBA {
        accent.darkened()
    }

    var key: String {
        switch self {
        case .preset(let preset):
            return "preset:\(preset.rawValue)"
        case .custom(let value):
            return "custom:\(value.key)"
        }
    }
}

private struct RunShareAdvancedStyle: Equatable {
    var fontChoice: RunShareFontChoice
    var fontScale: Double
    var accentColorSource: RunShareAccentColorSource

    var artworkStyle: RunShareArtworkStyle {
        RunShareArtworkStyle(
            accentColor: accentColorSource.accent.color,
            accentShadowColor: accentColorSource.shadow.color,
            fontChoice: fontChoice,
            fontScale: fontScale
        )
    }

    var key: String {
        [
            fontChoice.rawValue,
            String(format: "%.3f", fontScale),
            accentColorSource.key
        ].joined(separator: "|")
    }

    static func defaultStyle(for template: RunShareTemplate) -> RunShareAdvancedStyle {
        switch template {
        case .sticker:
            return RunShareAdvancedStyle(fontChoice: .rounded, fontScale: 1, accentColorSource: .preset(.mint))
        case .style1:
            return RunShareAdvancedStyle(fontChoice: .serif, fontScale: 1.08, accentColorSource: .preset(.rose))
        }
    }

    static var defaultsByTemplate: [RunShareTemplate: RunShareAdvancedStyle] {
        Dictionary(uniqueKeysWithValues: RunShareTemplate.allCases.map { ($0, defaultStyle(for: $0)) })
    }
}

struct RunShareComposerView: View {
    let run: RunningWorkout
    let detail: RunDetail
    let summary: RunSummaryMetrics?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: RunShareTemplate = .sticker
    @State private var enabledFields: Set<RunShareField> = [.logo, .route, .distance, .duration, .pace]
    @State private var templateStyles: [RunShareTemplate: RunShareAdvancedStyle] = RunShareAdvancedStyle.defaultsByTemplate
    @State private var selectedBackgroundPhotoItem: PhotosPickerItem?
    @State private var backgroundPhotoImage: UIImage?
    @State private var backgroundPreviewPhotoImage: UIImage?
    @State private var backgroundPhotoErrorMessage: String?
    @State private var isLoadingBackgroundPhoto = false
    @State private var previewStickerImage: UIImage?
    @State private var stickerPlacements: [RunShareTemplate: RunShareStickerPlacement] = RunShareTemplate.defaultPlacements
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var exportStatusMessage: String?
    @State private var exportErrorMessage: String?
    private let hiddenFields: Set<RunShareField> = [.environment, .shoe]

    private var selectedTemplatePolicy: RunShareTemplatePolicy {
        selectedTemplate.policy
    }

    private var selectedTemplateLayout: RunShareTemplateLayoutSpec {
        selectedTemplate.layoutSpec
    }

    private var availableFields: [RunShareField] {
        RunShareField.allCases.filter { !hiddenFields.contains($0) && isFieldAvailable($0) }
    }

    private var availableBasicInfoFields: [RunShareField] {
        let source = selectedTemplate == .style1 ? [RunShareField.route] : runShareBasicInfoFields
        return source.filter { availableFields.contains($0) }
    }

    private var availableMetricFields: [RunShareField] {
        selectedTemplatePolicy.metricCandidates.filter { availableFields.contains($0) }
    }

    private var effectiveFields: Set<RunShareField> {
        sanitizedFields(from: enabledFields, for: selectedTemplate)
    }

    private var selectedMetricFields: [RunShareField] {
        runShareMetricPriority.filter { selectedTemplatePolicy.metricCandidates.contains($0) && effectiveFields.contains($0) }
    }

    private var selectedAdvancedStyle: RunShareAdvancedStyle {
        templateStyles[selectedTemplate] ?? RunShareAdvancedStyle.defaultStyle(for: selectedTemplate)
    }

    private var artworkStyle: RunShareArtworkStyle {
        selectedAdvancedStyle.artworkStyle
    }

    private var metricSelectionCountLabel: String {
        "\(selectedMetricFields.count)/\(selectedTemplatePolicy.metricMax)"
    }

    private var selectedStickerPlacement: RunShareStickerPlacement {
        stickerPlacements[selectedTemplate] ?? selectedTemplateLayout.defaultPlacement
    }

    private var selectedStickerPlacementBinding: Binding<RunShareStickerPlacement> {
        Binding(
            get: { stickerPlacements[selectedTemplate] ?? selectedTemplateLayout.defaultPlacement },
            set: { stickerPlacements[selectedTemplate] = $0 }
        )
    }

    private var shareActionForegroundColor: Color {
        let accent = selectedAdvancedStyle.accentColorSource.accent
        let luminance = (accent.red * 0.299) + (accent.green * 0.587) + (accent.blue * 0.114)
        return luminance > 0.62 ? .black : .white
    }

    private func previewWidth(for availableWidth: CGFloat) -> CGFloat {
        min(
            max(selectedTemplateLayout.previewPreferredWidth + 24, 180),
            max(availableWidth - 32, 180)
        )
    }

    private func previewHeight(for availableWidth: CGFloat) -> CGFloat {
        selectedTemplate.previewHeight(for: previewWidth(for: availableWidth))
    }

    private func previewCanvasSize(for availableWidth: CGFloat) -> CGSize {
        let maxPreviewWidth = previewWidth(for: availableWidth)

        guard selectedTemplate.isTransparentStickerTemplate, let previewImage = backgroundPreviewPhotoImage ?? backgroundPhotoImage else {
            return CGSize(width: maxPreviewWidth, height: previewHeight(for: availableWidth))
        }

        return fittedSize(
            for: previewImage.size,
            maxWidth: maxPreviewWidth,
            maxHeight: previewHeight(for: availableWidth)
        )
    }

    private var renderCanvasSize: CGSize {
        guard selectedTemplate.isTransparentStickerTemplate, let backgroundPhotoImage else {
            return selectedTemplate.canvasSize
        }

        return fittedSize(
            for: backgroundPhotoImage.size,
            maxWidth: 2048,
            maxHeight: 2048
        )
    }

    private var previewStickerRenderKey: String {
        let fieldKey = effectiveFields.map(\.rawValue).sorted().joined(separator: ",")
        let photoKey = backgroundPhotoImage == nil ? "no-photo" : "photo"
        return [
            selectedTemplate.rawValue,
            fieldKey,
            selectedAdvancedStyle.key,
            photoKey
        ].joined(separator: "|")
    }

    private var backgroundPhotoButtonTitle: String {
        backgroundPhotoImage == nil ? L10n.tr("사진 불러오기") : L10n.tr("사진 다시 고르기")
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let availableWidth = max(geometry.size.width - 32, 280)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        compactEditorDashboard(availableWidth: availableWidth)

                        if selectedTemplate.isTransparentStickerTemplate {
                            stickerPhotoPanel
                        }

                        shareActionGuidePanel

                        footerPanel
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
            }
            .background(AppBackground())
            .navigationTitle("공유 이미지")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: previewStickerRenderKey) {
                await refreshPreviewStickerImageIfNeeded()
            }
            .task {
                RunShareTemplate.allCases.forEach { template in
                    ensureTemplateStyleExists(for: template)
                    ensureTemplatePlacementExists(for: template)
                    sanitizeTemplateStyle(for: template)
                }
                sanitizeEnabledFields()
            }
            .onChange(of: selectedBackgroundPhotoItem) { _, newItem in
                Task {
                    await loadBackgroundPhoto(from: newItem)
                }
            }
            .onChange(of: selectedTemplate) { _, newTemplate in
                ensureTemplateStyleExists(for: newTemplate)
                ensureTemplatePlacementExists(for: newTemplate)
                sanitizeTemplateStyle(for: newTemplate)
                sanitizeEnabledFields()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await saveToPhotoLibrary()
                        }
                    } label: {
                        shareActionLabel(
                            title: "저장",
                            systemImage: "square.and.arrow.down",
                            foregroundColor: .white,
                            backgroundColor: Color.white.opacity(0.08)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        copyPNGToPasteboard()
                    } label: {
                        shareActionLabel(
                            title: "복사",
                            systemImage: "doc.on.doc",
                            foregroundColor: .white,
                            backgroundColor: Color.white.opacity(0.08)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        shareImage()
                    } label: {
                        shareActionLabel(
                            title: "공유",
                            systemImage: "square.and.arrow.up",
                            foregroundColor: shareActionForegroundColor,
                            backgroundColor: artworkStyle.accentColor
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
        }
    }

    private func ensureTemplateStyleExists(for template: RunShareTemplate) {
        if templateStyles[template] == nil {
            templateStyles[template] = RunShareAdvancedStyle.defaultStyle(for: template)
        }
    }

    private func ensureTemplatePlacementExists(for template: RunShareTemplate) {
        if stickerPlacements[template] == nil {
            stickerPlacements[template] = template.layoutSpec.defaultPlacement
        }
    }

    private func sanitizeTemplateStyle(for template: RunShareTemplate) {
        guard var style = templateStyles[template] else { return }
        let range = template.layoutSpec.fontScaleRange
        let clamped = min(max(style.fontScale, range.lowerBound), range.upperBound)
        if clamped != style.fontScale {
            style.fontScale = clamped
            templateStyles[template] = style
        }
    }

    private func resetPlacement(for template: RunShareTemplate) {
        stickerPlacements[template] = template.layoutSpec.defaultPlacement
    }

    private func updateCurrentTemplateStyle(_ transform: (inout RunShareAdvancedStyle) -> Void) {
        var style = templateStyles[selectedTemplate] ?? RunShareAdvancedStyle.defaultStyle(for: selectedTemplate)
        transform(&style)
        let range = selectedTemplateLayout.fontScaleRange
        style.fontScale = min(max(style.fontScale, range.lowerBound), range.upperBound)
        templateStyles[selectedTemplate] = style
    }

    private func sanitizedFields(from source: Set<RunShareField>, for template: RunShareTemplate) -> Set<RunShareField> {
        let policy = template.policy
        let availableSet = Set(availableFields)
        let candidateMetricSet = Set(policy.metricCandidates)

        var updated = source.intersection(availableSet)

        if template == .style1 {
            updated.remove(.logo)
            updated.remove(.date)
        }

        for metric in runShareMetricPriority where !candidateMetricSet.contains(metric) {
            updated.remove(metric)
        }

        if policy.routeRequired {
            updated.insert(.route)
        }

        for required in policy.requiredMetrics where candidateMetricSet.contains(required) && availableSet.contains(required) {
            updated.insert(required)
        }

        let orderedCandidates = runShareMetricPriority.filter { candidateMetricSet.contains($0) && availableSet.contains($0) }
        var selectedMetrics = orderedCandidates.filter { updated.contains($0) }

        if selectedMetrics.count > policy.metricMax {
            selectedMetrics = Array(selectedMetrics.prefix(policy.metricMax))
        }

        if selectedMetrics.count < policy.metricMin {
            for field in orderedCandidates where !selectedMetrics.contains(field) {
                selectedMetrics.append(field)
                if selectedMetrics.count == policy.metricMin {
                    break
                }
            }
        }

        for metric in runShareMetricPriority {
            updated.remove(metric)
        }
        for metric in selectedMetrics {
            updated.insert(metric)
        }

        return updated
    }

    private func sanitizeEnabledFields() {
        let sanitized = sanitizedFields(from: enabledFields, for: selectedTemplate)
        if sanitized != enabledFields {
            enabledFields = sanitized
        }
    }

    private func toggleField(_ field: RunShareField) {
        if field == .route && selectedTemplatePolicy.routeRequired {
            return
        }

        if selectedTemplatePolicy.metricCandidates.contains(field) {
            toggleMetricField(field)
            return
        }

        guard runShareBasicInfoFields.contains(field) else { return }

        if effectiveFields.contains(field) {
            enabledFields.remove(field)
        } else {
            enabledFields.insert(field)
        }
        sanitizeEnabledFields()
    }

    private func toggleMetricField(_ field: RunShareField) {
        var updated = enabledFields
        let count = selectedMetricFields.count

        if selectedMetricFields.contains(field) {
            if selectedTemplatePolicy.requiredMetrics.contains(field) {
                return
            }
            if count - 1 >= selectedTemplatePolicy.metricMin {
                updated.remove(field)
            }
        } else {
            if count < selectedTemplatePolicy.metricMax {
                updated.insert(field)
            } else if let fallback = selectedMetricFields.reversed().first {
                updated.remove(fallback)
                updated.insert(field)
            }
        }

        enabledFields = updated
        sanitizeEnabledFields()
    }

    @ViewBuilder
    private func compactEditorDashboard(availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            templateSelectorPanel
            previewPanel(availableWidth: availableWidth)
            includedDataPanel(availableWidth: availableWidth)
            advancedSettingsPanel
        }
        .padding(14)
        .background(editorPanelBackground(cornerRadius: 24))
    }

    private func previewPanel(availableWidth: CGFloat) -> some View {
        let canvasSize = previewCanvasSize(for: availableWidth)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("미리보기")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                Text(selectedTemplate.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
            }

            shareCanvasView(canvasSize: canvasSize, interactive: true)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(width: canvasSize.width, height: canvasSize.height)
                .frame(maxWidth: .infinity)
                .frame(height: canvasSize.height)
        }
        .padding(12)
        .background(editorPanelBackground(cornerRadius: 20))
    }

    private var templateSelectorPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("템플릿")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                ForEach(RunShareTemplate.allCases) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        Text(template.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(
                                        selectedTemplate == template
                                            ? artworkStyle.accentColor.opacity(0.24)
                                            : Color.white.opacity(0.06)
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selectedTemplate == template
                                            ? artworkStyle.accentColor.opacity(0.42)
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(editorPanelBackground(cornerRadius: 20))
    }

    private var advancedSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("고급")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if selectedTemplatePolicy.supportsFontDebug {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("폰트 크기")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                        Spacer()
                        Text("\(Int(selectedAdvancedStyle.fontScale * 100))%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .monospacedDigit()
                    }

                    Slider(
                        value: Binding(
                            get: { selectedAdvancedStyle.fontScale },
                            set: { value in
                                updateCurrentTemplateStyle { $0.fontScale = value }
                            }
                        ),
                        in: selectedTemplateLayout.fontScaleRange
                    )
                    .tint(artworkStyle.accentColor)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 8)], spacing: 8) {
                        ForEach(RunShareFontChoice.allCases) { choice in
                            Button {
                                updateCurrentTemplateStyle { $0.fontChoice = choice }
                            } label: {
                                Text(choice.label)
                                    .font(choice.font(size: 13, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                selectedAdvancedStyle.fontChoice == choice
                                                    ? artworkStyle.accentColor.opacity(0.22)
                                                    : Color.white.opacity(0.06)
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                selectedAdvancedStyle.fontChoice == choice
                                                    ? artworkStyle.accentColor.opacity(0.34)
                                                    : Color.white.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if selectedTemplatePolicy.supportsColorDebug {
                VStack(alignment: .leading, spacing: 10) {
                    Text("강조 색상")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 10)], spacing: 10) {
                        ForEach(RunShareAccentPreset.allCases) { preset in
                            Button {
                                updateCurrentTemplateStyle { $0.accentColorSource = .preset(preset) }
                            } label: {
                                Circle()
                                    .fill(preset.accent.color)
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                {
                                                    if case .preset(let current) = selectedAdvancedStyle.accentColorSource {
                                                        return current == preset ? artworkStyle.accentColor : .clear
                                                    }
                                                    return .clear
                                                }(),
                                                lineWidth: 3
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 4) {
                            ColorPicker(
                                "",
                                selection: Binding(
                                    get: { selectedAdvancedStyle.accentColorSource.accent.color },
                                    set: { newValue in
                                        updateCurrentTemplateStyle { $0.accentColorSource = .custom(RunShareRGBA(color: newValue)) }
                                    }
                                ),
                                supportsOpacity: false
                            )
                            .labelsHidden()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                            .overlay(
                                Circle()
                                    .stroke(
                                        {
                                            if case .custom = selectedAdvancedStyle.accentColorSource {
                                                return artworkStyle.accentColor
                                            }
                                            return .clear
                                        }(),
                                        lineWidth: 3
                                    )
                            )

                            Text("직접")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Button("현재 템플릿 초기화") {
                templateStyles[selectedTemplate] = RunShareAdvancedStyle.defaultStyle(for: selectedTemplate)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(artworkStyle.accentColor)
        }
        .padding(12)
        .background(editorPanelBackground(cornerRadius: 20))
    }

    private func includedDataPanel(availableWidth: CGFloat) -> some View {
        let minimumWidth = availableWidth > 520 ? 108.0 : 84.0

        return VStack(alignment: .leading, spacing: 12) {
            Text("포함 데이터")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                Text("기본 정보")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: 8)], spacing: 8) {
                    ForEach(availableBasicInfoFields) { field in
                        let locked = (field == .route && selectedTemplatePolicy.routeRequired)
                        Button {
                            toggleField(field)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: locked ? "lock.fill" : field.systemImage)
                                    .font(.caption.weight(.semibold))
                                Text(field.label)
                                    .lineLimit(1)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        effectiveFields.contains(field)
                                            ? artworkStyle.accentColor.opacity(0.22)
                                            : Color.white.opacity(0.06)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        effectiveFields.contains(field)
                                            ? artworkStyle.accentColor.opacity(0.34)
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                            .opacity(locked ? 0.88 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(locked)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("운동 지표")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(metricSelectionCountLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.62))
                        .monospacedDigit()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: 8)], spacing: 8) {
                    ForEach(availableMetricFields) { field in
                        Button {
                            toggleField(field)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: field.systemImage)
                                    .font(.caption.weight(.semibold))
                                Text(field.label)
                                    .lineLimit(1)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        selectedMetricFields.contains(field)
                                            ? artworkStyle.accentColor.opacity(0.22)
                                            : Color.white.opacity(0.06)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        selectedMetricFields.contains(field)
                                            ? artworkStyle.accentColor.opacity(0.34)
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(editorPanelBackground(cornerRadius: 20))
    }

    private var stickerPhotoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("사진 위에 붙이기")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if backgroundPhotoImage != nil {
                    Button("제거") {
                        clearBackgroundPhoto()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(runOnlyShareAccent)
                }
            }

            PhotosPicker(selection: $selectedBackgroundPhotoItem, matching: .images, photoLibrary: .shared()) {
                Label(LocalizedStringKey(backgroundPhotoButtonTitle), systemImage: "photo.on.rectangle.angled")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if backgroundPhotoImage != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("스티커 크기")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(selectedStickerPlacement.scale * 100))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Slider(
                        value: Binding(
                            get: { selectedStickerPlacementBinding.wrappedValue.scale },
                            set: { newScale in
                                var updated = selectedStickerPlacementBinding.wrappedValue
                                updated.scale = newScale
                                selectedStickerPlacementBinding.wrappedValue = updated
                            }
                        ),
                        in: 0.55...1.7
                    )
                    .tint(artworkStyle.accentColor)

                    Button("위치/크기 초기화") {
                        resetPlacement(for: selectedTemplate)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(runOnlyShareAccent)
                }

                Text("미리보기에서 스티커를 직접 드래그해서 위치를 맞출 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            } else {
                Text("배경 사진은 선택 사항입니다. 고르면 그 위에 스티커를 올려 보고 저장하거나 공유할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            if isLoadingBackgroundPhoto {
                Text("사진을 불러오는 중입니다.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            } else if let backgroundPhotoErrorMessage {
                Text(backgroundPhotoErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(editorPanelBackground(cornerRadius: 24))
    }

    private var shareActionGuidePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내보내기 방법")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Text("• 저장: 사진 앱에 PNG를 저장하며, 이때만 사진 권한을 요청합니다.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text("• 복사: PNG를 클립보드에 복사해 메신저나 노트에 바로 붙여넣을 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text("• 공유: 시스템 공유 시트로 다른 앱에 보냅니다.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
        .background(editorPanelBackground(cornerRadius: 24))
    }

    @ViewBuilder
    private var footerPanel: some View {
        if exportStatusMessage != nil || exportErrorMessage != nil || selectedTemplate.isTransparentStickerTemplate {
            VStack(alignment: .leading, spacing: 8) {
                if let exportStatusMessage {
                    Text(exportStatusMessage)
                        .font(.caption)
                        .foregroundStyle(runOnlyShareAccent)
                }

                if let exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if selectedTemplate.isTransparentStickerTemplate {
                    Text("투명 스티커는 앱마다 alpha 처리 방식이 다를 수 있어 실제 업로드 동작은 기기에서 확인하는 것이 가장 정확합니다.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .padding(16)
            .background(editorPanelBackground(cornerRadius: 24))
        }
    }

    private func editorPanelBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func shareActionLabel(
        title: String,
        systemImage: String,
        foregroundColor: Color,
        backgroundColor: Color
    ) -> some View {
        Label(LocalizedStringKey(title), systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor)
            )
    }

    private func shareImage() {
        do {
            let url = try exportShareImageFile()
            shareItems = [url]
            exportErrorMessage = nil
            exportStatusMessage = L10n.tr("공유용 PNG를 준비했습니다.")
            showingShareSheet = true
        } catch {
            exportStatusMessage = nil
            exportErrorMessage = error.localizedDescription
        }
    }

    private func copyPNGToPasteboard() {
        do {
            let data = try renderPNGData()
            UIPasteboard.general.setItems([[UTType.png.identifier: data]])
            exportErrorMessage = nil
            exportStatusMessage = L10n.tr("PNG를 클립보드에 복사했습니다.")
        } catch {
            exportStatusMessage = nil
            exportErrorMessage = error.localizedDescription
        }
    }

    private func saveToPhotoLibrary() async {
        do {
            let data = try renderPNGData()
            let authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard authorizationStatus == .authorized || authorizationStatus == .limited else {
                exportStatusMessage = nil
                exportErrorMessage = L10n.tr("사진 앱 저장 권한이 필요합니다. 저장 대신 복사나 공유는 바로 사용할 수 있습니다.")
                return
            }

            try await PhotoLibraryPNGWriter.save(data)
            exportErrorMessage = nil
            exportStatusMessage = L10n.tr("카메라롤에 PNG를 저장했습니다.")
        } catch {
            exportStatusMessage = nil
            exportErrorMessage = error.localizedDescription
        }
    }

    private func exportShareImageFile() throws -> URL {
        let data = try renderPNGData()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let filename = "RunOnly-Share-\(formatter.string(from: run.startDate))-\(selectedTemplate.rawValue).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func renderPNGData() throws -> Data {
        let size = renderCanvasSize
        let content = shareCanvasView(canvasSize: size, interactive: false)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw RunShareExportError.renderFailed
        }

        return data
    }

    private func isFieldAvailable(_ field: RunShareField) -> Bool {
        switch field {
        case .logo:
            return true
        case .route:
            return true
        case .heartRate:
            return averageHeartRateText != nil
        case .cadence:
            return averageCadenceText != nil
        case .elevationGain:
            return elevationGainText != nil
        case .shoe, .environment:
            return false
        case .date, .distance, .duration, .pace:
            return true
        }
    }

    private var averageHeartRateText: String? {
        summary?.averageHeartRateText
    }

    private var averageCadenceText: String? {
        summary?.averageCadenceText
    }

    private var elevationGainText: String? {
        summary?.elevationGainText
    }

    @ViewBuilder
    private func shareCanvasView(canvasSize: CGSize, interactive: Bool) -> some View {
        if selectedTemplate.isTransparentStickerTemplate, let backgroundPhotoImage {
            RunSharePhotoCompositeView(
                run: run,
                detail: detail,
                template: selectedTemplate,
                enabledFields: effectiveFields,
                summary: summary,
                style: artworkStyle,
                layoutSpec: selectedTemplateLayout,
                backgroundImage: interactive ? (backgroundPreviewPhotoImage ?? backgroundPhotoImage) : backgroundPhotoImage,
                stickerPreviewImage: interactive ? previewStickerImage : nil,
                stickerPlacement: selectedStickerPlacementBinding,
                interactive: interactive
            )
            .frame(width: canvasSize.width, height: canvasSize.height)
        } else {
            ZStack {
                if selectedTemplate.isTransparentStickerTemplate, interactive {
                    TransparentPreviewBackground()
                }

                RunShareArtworkView(
                    run: run,
                    detail: detail,
                    template: selectedTemplate,
                    enabledFields: effectiveFields,
                    summary: summary,
                    style: artworkStyle
                )
                .frame(
                    width: selectedTemplate.canvasSize.width,
                    height: selectedTemplate.canvasSize.height
                )
                .scaleEffect(canvasSize.width / selectedTemplate.canvasSize.width, anchor: .topLeading)
                .frame(
                    width: canvasSize.width,
                    height: canvasSize.height,
                    alignment: .topLeading
                )
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
        }
    }

    @MainActor
    private func loadBackgroundPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }

        isLoadingBackgroundPhoto = true
        backgroundPhotoErrorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw RunShareExportError.renderFailed
            }

            let assets = try await loadBackgroundPhotoAssets(from: data)
            backgroundPhotoImage = assets.renderImage
            backgroundPreviewPhotoImage = assets.previewImage
            resetPlacement(for: selectedTemplate)
        } catch {
            backgroundPhotoErrorMessage = L10n.tr("사진을 불러오지 못했습니다.")
        }

        selectedBackgroundPhotoItem = nil
        isLoadingBackgroundPhoto = false
    }

    private func clearBackgroundPhoto() {
        backgroundPhotoImage = nil
        backgroundPreviewPhotoImage = nil
        backgroundPhotoErrorMessage = nil
        previewStickerImage = nil
        selectedBackgroundPhotoItem = nil
        RunShareTemplate.allCases.forEach { template in
            resetPlacement(for: template)
        }
    }

    private func fittedSize(for original: CGSize, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard original.width > 0, original.height > 0 else {
            return CGSize(width: maxWidth, height: maxHeight)
        }

        let scale = min(maxWidth / original.width, maxHeight / original.height, 1)
        return CGSize(
            width: max(original.width * scale, 1),
            height: max(original.height * scale, 1)
        )
    }

    @MainActor
    private func refreshPreviewStickerImageIfNeeded() async {
        guard selectedTemplate.isTransparentStickerTemplate, backgroundPhotoImage != nil else {
            previewStickerImage = nil
            return
        }

        do {
            try await Task.sleep(nanoseconds: 120_000_000)
        } catch {
            return
        }

        guard !Task.isCancelled else { return }

        let content = RunShareArtworkView(
            run: run,
            detail: detail,
            template: selectedTemplate,
            enabledFields: effectiveFields,
            summary: summary,
            style: artworkStyle
        )
        .frame(
            width: selectedTemplate.canvasSize.width,
            height: selectedTemplate.canvasSize.height
        )

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        previewStickerImage = renderer.uiImage
    }

    private func loadBackgroundPhotoAssets(from data: Data) async throws -> RunShareBackgroundPhotoAssets {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let assets = try makeBackgroundPhotoAssets(from: data)
                        continuation.resume(returning: assets)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func makeBackgroundPhotoAssets(from data: Data) throws -> RunShareBackgroundPhotoAssets {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw RunShareExportError.renderFailed
        }

        return RunShareBackgroundPhotoAssets(
            renderImage: try downsampledImage(from: source, maxPixelSize: 2_048),
            previewImage: try downsampledImage(from: source, maxPixelSize: 1_400)
        )
    }

    private func downsampledImage(from source: CGImageSource, maxPixelSize: CGFloat) throws -> UIImage {
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            throw RunShareExportError.renderFailed
        }

        return UIImage(cgImage: cgImage)
    }
}

private enum RunShareExportError: LocalizedError {
    case renderFailed
    case photoSaveFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return L10n.tr("공유 이미지를 렌더링하지 못했습니다.")
        case .photoSaveFailed:
            return L10n.tr("사진 앱에 저장하지 못했습니다.")
        }
    }
}

private enum PhotoLibraryPNGWriter {
    static func save(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: RunShareExportError.photoSaveFailed)
                }
            })
        }
    }
}

private struct RunShareArtworkView: View {
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
                Text("RUNONLY")
                    .font(style.fontChoice.font(size: style.scaled(headerBrandFontSize), weight: .heavy))
                    .foregroundStyle(style.accentColor)
                    .tracking(1.2)
                    .shadow(color: style.accentColor.opacity(0.26), radius: 10, y: 2)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack {
                    Text("RUNONLY")
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

private struct RunShareTemplateBackground: View {
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

private struct RunSharePhotoCompositeView: View {
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

private struct RunShareRouteCanvas: View {
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

private struct RouteProjection {
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

private struct StyleOneMetricRow: View {
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

private struct StyleOneRouteCanvas: View {
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

private struct RunShareMetricTile: View {
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

private struct ShareMetaPill: View {
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

private struct RunShareMetaCapsule: View {
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

private struct TransparentPreviewBackground: View {
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

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
