import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

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

