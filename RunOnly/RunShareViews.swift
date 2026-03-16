import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum RunShareTemplate: String, CaseIterable, Identifiable {
    case sticker
    case square
    case story

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sticker:
            return "스티커"
        case .square:
            return "정사각형"
        case .story:
            return "스토리"
        }
    }

    var descriptionText: String {
        switch self {
        case .sticker:
            return "투명 배경 PNG로 복사/공유하기 좋습니다."
        case .square:
            return "피드용 카드에 가까운 정사각형 이미지입니다."
        case .story:
            return "세로 비율이 긴 스토리형 포스터입니다."
        }
    }

    var canvasSize: CGSize {
        switch self {
        case .sticker:
            return CGSize(width: 520, height: 860)
        case .square:
            return CGSize(width: 1080, height: 1080)
        case .story:
            return CGSize(width: 1080, height: 1680)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .sticker:
            return 0
        case .square:
            return 34
        case .story:
            return 0
        }
    }

    func previewHeight(for width: CGFloat) -> CGFloat {
        width * (canvasSize.height / canvasSize.width)
    }

    var composerPreviewWidth: CGFloat {
        switch self {
        case .sticker:
            return 190
        case .square:
            return 208
        case .story:
            return 164
        }
    }
}

private enum RunShareField: String, CaseIterable, Identifiable {
    case logo
    case route
    case date
    case weather
    case environment
    case distance
    case duration
    case pace
    case heartRate
    case cadence
    case shoe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .logo:
            return "RUNONLY"
        case .route:
            return "경로"
        case .date:
            return "날짜"
        case .weather:
            return "날씨"
        case .environment:
            return "실내/실외"
        case .distance:
            return "거리"
        case .duration:
            return "시간"
        case .pace:
            return "페이스"
        case .heartRate:
            return "심박"
        case .cadence:
            return "케이던스"
        case .shoe:
            return "신발"
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
        case .weather:
            return "cloud.sun.fill"
        case .environment:
            return "figure.run"
        case .distance:
            return "ruler"
        case .duration:
            return "timer"
        case .pace:
            return "speedometer"
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
            return "둥근"
        case .system:
            return "기본"
        case .serif:
            return "세리프"
        case .monospaced:
            return "모노"
        case .condensed:
            return "콘덴스"
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

private struct RunShareStickerDebugSettings {
    var fontChoice: RunShareFontChoice = .rounded
    var fontScale: Double = 1

    var artworkStyle: RunShareArtworkStyle {
        RunShareArtworkStyle(
            accentColor: runOnlyShareAccent,
            accentShadowColor: runOnlyShareAccentDark,
            fontChoice: fontChoice,
            fontScale: fontScale
        )
    }
}

private struct RunShareStickerPlacement {
    var centerX: CGFloat = 0.5
    var centerY: CGFloat = 0.62
    var scale: CGFloat = 1
}

struct RunShareComposerView: View {
    let run: RunningWorkout
    let detail: RunDetail

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: RunShareTemplate = .sticker
    @State private var enabledFields: Set<RunShareField> = [.logo, .route, .weather, .distance, .duration, .pace]
    @State private var stickerDebugSettings = RunShareStickerDebugSettings()
    @State private var selectedBackgroundPhotoItem: PhotosPickerItem?
    @State private var backgroundPhotoImage: UIImage?
    @State private var backgroundPreviewPhotoImage: UIImage?
    @State private var backgroundPhotoErrorMessage: String?
    @State private var isLoadingBackgroundPhoto = false
    @State private var previewStickerImage: UIImage?
    @State private var stickerPlacement = RunShareStickerPlacement()
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var exportStatusMessage: String?
    @State private var exportErrorMessage: String?
    @State private var weatherSnapshot: RunWeatherSnapshot?
    @State private var weatherErrorMessage: String?
    @State private var isLoadingWeather = false
    private let hiddenFields: Set<RunShareField> = [.environment, .shoe]

    private var availableFields: [RunShareField] {
        RunShareField.allCases.filter { !hiddenFields.contains($0) && isFieldAvailable($0) }
    }

    private var effectiveFields: Set<RunShareField> {
        enabledFields.intersection(Set(availableFields))
    }

    private var artworkStyle: RunShareArtworkStyle {
        stickerDebugSettings.artworkStyle
    }

    private var previewWidth: CGFloat {
        min(UIScreen.main.bounds.width - 32, selectedTemplate.composerPreviewWidth)
    }

    private var previewHeight: CGFloat {
        selectedTemplate.previewHeight(for: previewWidth)
    }

    private var previewCanvasSize: CGSize {
        guard selectedTemplate == .sticker, let previewImage = backgroundPreviewPhotoImage ?? backgroundPhotoImage else {
            return CGSize(width: previewWidth, height: previewHeight)
        }

        return fittedSize(
            for: previewImage.size,
            maxWidth: min(UIScreen.main.bounds.width - 32, 360),
            maxHeight: 480
        )
    }

    private var renderCanvasSize: CGSize {
        guard selectedTemplate == .sticker, let backgroundPhotoImage else {
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
        let weatherKey = weatherSnapshot?.shareText ?? "none"
        let photoKey = backgroundPhotoImage == nil ? "no-photo" : "photo"
        return [
            selectedTemplate.rawValue,
            fieldKey,
            weatherKey,
            stickerDebugSettings.fontChoice.rawValue,
            String(format: "%.3f", stickerDebugSettings.fontScale),
            photoKey
        ].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("미리보기")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(selectedTemplate.label)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.62))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                )
                        }

                        shareCanvasView(canvasSize: previewCanvasSize, interactive: true)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .frame(width: previewCanvasSize.width, height: previewCanvasSize.height)
                            .frame(maxWidth: .infinity)
                            .frame(height: previewCanvasSize.height)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("템플릿")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Picker("공유 템플릿", selection: $selectedTemplate) {
                                ForEach(RunShareTemplate.allCases) { template in
                                    Text(template.label).tag(template)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text(selectedTemplate.descriptionText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }

                        if selectedTemplate == .sticker {
                            Divider()
                                .overlay(Color.white.opacity(0.08))

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("스티커 디버그")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("초기화") {
                                        stickerDebugSettings = RunShareStickerDebugSettings()
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(runOnlyShareAccent)
                                }

                                Text("폰트와 크기를 손보면 스티커 프리뷰와 내보내기 결과에 바로 반영됩니다.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("폰트 크기")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text("\(Int(stickerDebugSettings.fontScale * 100))%")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }

                                    Slider(value: $stickerDebugSettings.fontScale, in: 0.75...1.6)
                                        .tint(artworkStyle.accentColor)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("폰트")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)

                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                                        ForEach(RunShareFontChoice.allCases) { choice in
                                            Button {
                                                stickerDebugSettings.fontChoice = choice
                                            } label: {
                                                Text(choice.label)
                                                    .font(choice.font(size: 16, weight: .heavy))
                                                    .foregroundStyle(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                            .fill(
                                                                stickerDebugSettings.fontChoice == choice
                                                                    ? artworkStyle.accentColor.opacity(0.22)
                                                                    : Color.white.opacity(0.06)
                                                            )
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                            .stroke(
                                                                stickerDebugSettings.fontChoice == choice
                                                                    ? artworkStyle.accentColor.opacity(0.36)
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
                        }

                        Divider()
                            .overlay(Color.white.opacity(0.08))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("포함 데이터")
                                .font(.headline)
                                .foregroundStyle(.white)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(availableFields) { field in
                                    Button {
                                        toggleField(field)
                                    } label: {
                                        HStack(spacing: 7) {
                                            Image(systemName: field.systemImage)
                                            Text(field.label)
                                                .lineLimit(1)
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(
                                                    effectiveFields.contains(field)
                                                        ? Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.22)
                                                        : Color.white.opacity(0.06)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(
                                                    effectiveFields.contains(field)
                                                        ? Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.32)
                                                        : Color.white.opacity(0.08),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if selectedTemplate == .sticker {
                            Divider()
                                .overlay(Color.white.opacity(0.08))

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
                                    Label(backgroundPhotoImage == nil ? "사진 불러오기" : "사진 다시 고르기", systemImage: "photo.on.rectangle.angled")
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
                                            Text("\(Int(stickerPlacement.scale * 100))%")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white.opacity(0.5))
                                        }

                                        Slider(
                                            value: Binding(
                                                get: { stickerPlacement.scale },
                                                set: { stickerPlacement.scale = $0 }
                                            ),
                                            in: 0.55...1.7
                                        )
                                        .tint(artworkStyle.accentColor)

                                        Button("위치/크기 초기화") {
                                            stickerPlacement = RunShareStickerPlacement()
                                        }
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(runOnlyShareAccent)
                                    }

                                    Text("미리보기에서 스티커를 직접 드래그해서 위치를 맞출 수 있습니다.")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.62))
                                } else {
                                    Text("배경 사진을 고르면 그 위에 스티커를 바로 올려 보고 저장하거나 공유할 수 있습니다.")
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
                        }

                        if let exportStatusMessage {
                            Text(exportStatusMessage)
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                        }

                        if let exportErrorMessage {
                            Text(exportErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if isLoadingWeather {
                            Text("러닝 시각 기준 날씨를 불러오는 중입니다.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                        } else if let weatherErrorMessage {
                            Text(weatherErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                        }

                        Text("투명 스티커는 앱마다 alpha 처리 방식이 다를 수 있어 실제 업로드 동작은 기기에서 확인하는 것이 가장 정확합니다.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle("공유 이미지")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: weatherLookupKey) {
                await loadWeatherIfNeeded()
            }
            .task(id: previewStickerRenderKey) {
                refreshPreviewStickerImageIfNeeded()
            }
            .onChange(of: selectedBackgroundPhotoItem) { _, newItem in
                Task {
                    await loadBackgroundPhoto(from: newItem)
                }
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
                            foregroundColor: .black,
                            backgroundColor: Color(red: 0.29, green: 0.88, blue: 0.63)
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

    private func toggleField(_ field: RunShareField) {
        if effectiveFields.contains(field) {
            enabledFields.remove(field)
        } else {
            enabledFields.insert(field)
        }
    }

    @ViewBuilder
    private func shareActionLabel(
        title: String,
        systemImage: String,
        foregroundColor: Color,
        backgroundColor: Color
    ) -> some View {
        Label(title, systemImage: systemImage)
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
            exportStatusMessage = "공유용 PNG를 준비했습니다."
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
            exportStatusMessage = "PNG를 클립보드에 복사했습니다."
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
                exportErrorMessage = "사진 앱 저장 권한이 필요합니다."
                return
            }

            try await PhotoLibraryPNGWriter.save(data)
            exportErrorMessage = nil
            exportStatusMessage = "카메라롤에 PNG를 저장했습니다."
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
            return !detail.route.isEmpty
        case .weather:
            return weatherSnapshot != nil
        case .heartRate:
            return averageHeartRateText != nil
        case .cadence:
            return averageCadenceText != nil
        case .shoe, .environment:
            return false
        case .date, .distance, .duration, .pace:
            return true
        }
    }

    private var averageHeartRateText: String? {
        guard !detail.heartRates.isEmpty else { return nil }
        let average = detail.heartRates.map(\.bpm).reduce(0, +) / Double(detail.heartRates.count)
        return average.formatted(.number.precision(.fractionLength(0))) + " bpm"
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

    private var weatherLookupPoint: RunRoutePoint? {
        guard !detail.route.isEmpty else { return nil }
        return detail.route[detail.route.count / 2]
    }

    private var weatherLookupKey: String {
        guard let weatherLookupPoint else { return "weather-unavailable" }
        return "\(run.id.uuidString)-\(weatherLookupPoint.latitude)-\(weatherLookupPoint.longitude)"
    }

    @MainActor
    private func loadWeatherIfNeeded() async {
        guard !isLoadingWeather else { return }
        guard weatherSnapshot == nil else { return }
        guard let weatherLookupPoint else { return }

        isLoadingWeather = true
        weatherErrorMessage = nil

        do {
            weatherSnapshot = try await RunWeatherService.shared.fetchWeather(
                latitude: weatherLookupPoint.latitude,
                longitude: weatherLookupPoint.longitude,
                referenceDate: run.startDate
            )
        } catch {
            weatherErrorMessage = error.localizedDescription
        }

        isLoadingWeather = false
    }

    @ViewBuilder
    private func shareCanvasView(canvasSize: CGSize, interactive: Bool) -> some View {
        if selectedTemplate == .sticker, let backgroundPhotoImage {
            RunSharePhotoCompositeView(
                run: run,
                detail: detail,
                template: selectedTemplate,
                enabledFields: effectiveFields,
                weatherSnapshot: weatherSnapshot,
                style: artworkStyle,
                backgroundImage: interactive ? (backgroundPreviewPhotoImage ?? backgroundPhotoImage) : backgroundPhotoImage,
                stickerPreviewImage: interactive ? previewStickerImage : nil,
                stickerPlacement: $stickerPlacement,
                interactive: interactive
            )
            .frame(width: canvasSize.width, height: canvasSize.height)
        } else {
            ZStack {
                if selectedTemplate == .sticker, interactive {
                    TransparentPreviewBackground()
                }

                RunShareArtworkView(
                    run: run,
                    detail: detail,
                    template: selectedTemplate,
                    enabledFields: effectiveFields,
                    weatherSnapshot: weatherSnapshot,
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
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                throw RunShareExportError.renderFailed
            }

            backgroundPhotoImage = image
            backgroundPreviewPhotoImage = resizedImage(image, maxDimension: 1400)
            stickerPlacement = RunShareStickerPlacement()
        } catch {
            backgroundPhotoErrorMessage = "사진을 불러오지 못했습니다."
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
        stickerPlacement = RunShareStickerPlacement()
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
    private func refreshPreviewStickerImageIfNeeded() {
        guard selectedTemplate == .sticker, backgroundPhotoImage != nil else {
            previewStickerImage = nil
            return
        }

        let content = RunShareArtworkView(
            run: run,
            detail: detail,
            template: selectedTemplate,
            enabledFields: effectiveFields,
            weatherSnapshot: weatherSnapshot,
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

    private func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return image }

        let scale = min(maxDimension / max(originalSize.width, originalSize.height), 1)
        guard scale < 1 else { return image }

        let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private enum RunShareExportError: LocalizedError {
    case renderFailed
    case photoSaveFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "공유 이미지를 렌더링하지 못했습니다."
        case .photoSaveFailed:
            return "사진 앱에 저장하지 못했습니다."
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
    let weatherSnapshot: RunWeatherSnapshot?
    let style: RunShareArtworkStyle

    private var metrics: [RunShareMetric] {
        var items: [RunShareMetric] = []

        if enabledFields.contains(.distance) {
            items.append(RunShareMetric(field: .distance, title: "거리", value: run.distanceText))
        }
        if enabledFields.contains(.duration) {
            items.append(RunShareMetric(field: .duration, title: "시간", value: run.durationText))
        }
        if enabledFields.contains(.pace) {
            items.append(RunShareMetric(field: .pace, title: "페이스", value: run.paceText))
        }
        if enabledFields.contains(.heartRate), let averageHeartRateText {
            items.append(RunShareMetric(field: .heartRate, title: "심박", value: averageHeartRateText))
        }
        if enabledFields.contains(.cadence), let averageCadenceText {
            items.append(RunShareMetric(field: .cadence, title: "케이던스", value: averageCadenceText))
        }

        return items
    }

    private var routeHeight: CGFloat {
        switch template {
        case .sticker:
            return 315
        case .square:
            return 230
        case .story:
            return 520
        }
    }

    private var contentPadding: CGFloat {
        switch template {
        case .sticker:
            return 24
        case .square:
            return 40
        case .story:
            return 48
        }
    }

    private var headerBrandFontSize: CGFloat {
        switch template {
        case .sticker:
            return 18
        case .square:
            return 20
        case .story:
            return 24
        }
    }

    private var metricColumns: [GridItem] {
        let spacing: CGFloat = template == .sticker ? 8 : 12
        return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .leading), count: 3)
    }

    private var stickerRouteWidth: CGFloat {
        472
    }

    private var metricSpacing: CGFloat {
        switch template {
        case .sticker:
            return 12
        case .square:
            return 12
        case .story:
            return 16
        }
    }

    var body: some View {
        Group {
            if template == .sticker {
                stickerLayout
            } else {
                standardLayout
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

    private var standardLayout: some View {
        ZStack(alignment: .topLeading) {
            RunShareTemplateBackground(template: template, style: style)
                .clipShape(
                    RoundedRectangle(cornerRadius: template.cornerRadius, style: .continuous)
                )

            VStack(alignment: .leading, spacing: template == .story ? 20 : 14) {
                header

                if enabledFields.contains(.route) {
                    RunShareRouteCanvas(route: detail.route, style: style)
                        .frame(maxWidth: .infinity)
                        .frame(height: routeHeight)
                }

                if !metrics.isEmpty {
                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: metricSpacing) {
                        ForEach(metrics) { metric in
                            RunShareMetricTile(metric: metric, template: template, centered: false, style: style)
                        }
                    }
                }

                if !metaPills.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: template == .story ? 220 : 132), alignment: .leading)], spacing: 10) {
                        ForEach(metaPills, id: \.self) { item in
                            ShareMetaPill(text: item, centered: false, style: style)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(contentPadding)
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

    private var metaPills: [String] {
        var items: [String] = []

        if enabledFields.contains(.date) {
            items.append(shareDateText)
        }

        if enabledFields.contains(.weather), let weatherSnapshot {
            items.append(weatherSnapshot.shareText)
        }

        return items
    }

    private var averageHeartRateText: String? {
        guard !detail.heartRates.isEmpty else { return nil }
        let average = detail.heartRates.map(\.bpm).reduce(0, +) / Double(detail.heartRates.count)
        return average.formatted(.number.precision(.fractionLength(0))) + " bpm"
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

    private var shareDateText: String {
        Self.shareDateFormatter.string(from: run.startDate)
    }

    private static let shareDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()
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
                .fill(style.accentColor.opacity(template == .story ? 0.22 : 0.14))
                .frame(width: template == .story ? 560 : 320)
                .blur(radius: 24)
                .offset(x: 180, y: -220)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: template == .story ? 420 : 260)
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
    let weatherSnapshot: RunWeatherSnapshot?
    let style: RunShareArtworkStyle
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
                    .shadow(color: .black.opacity(0.24), radius: 24, y: 12)
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
                weatherSnapshot: weatherSnapshot,
                style: style
            )
            .frame(width: size.width, height: size.height)
        }
    }

    private func stickerCanvasSize(in canvasSize: CGSize) -> CGSize {
        let aspectRatio = template.canvasSize.height / max(template.canvasSize.width, 1)
        let baseWidth = min(canvasSize.width * 0.46, canvasSize.height * 0.58)
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

private struct RunShareMetricTile: View {
    let metric: RunShareMetric
    let template: RunShareTemplate
    let centered: Bool
    let style: RunShareArtworkStyle

    private var valueFontSize: CGFloat {
        switch template {
        case .sticker:
            return 64
        case .square:
            return 38
        case .story:
            return 44
        }
    }

    private var labelFontSize: CGFloat {
        switch template {
        case .sticker:
            return 24
        case .square:
            return 18
        case .story:
            return 20
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
