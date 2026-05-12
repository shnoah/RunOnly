import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct RunShareStickerPlacement: Equatable {
    var centerX: CGFloat
    var centerY: CGFloat
    var scale: CGFloat
}

struct RunShareTemplateLayoutSpec {
    let previewPreferredWidth: CGFloat
    let photoBaseWidthRatio: CGFloat
    let photoBaseHeightRatio: CGFloat
    let defaultPlacement: RunShareStickerPlacement
    let fontScaleRange: ClosedRange<Double>
}

struct RunShareBackgroundPhotoAssets {
    let renderImage: UIImage
    let previewImage: UIImage
}

enum RunShareTemplate: String, CaseIterable, Identifiable {
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

enum RunShareField: String, CaseIterable, Identifiable {
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

struct RunShareMetric: Identifiable {
    let field: RunShareField
    let title: String
    let value: String

    var id: RunShareField { field }
}

let runShareBasicInfoFields: [RunShareField] = [.logo, .route, .date]
let runShareMetricPriority: [RunShareField] = [.distance, .duration, .pace, .elevationGain, .heartRate, .cadence]

let runOnlyShareAccent = Color(red: 0.29, green: 0.88, blue: 0.63)
let runOnlyShareAccentDark = Color(red: 0.15, green: 0.71, blue: 0.49)

enum RunShareFontChoice: String, CaseIterable, Identifiable {
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

struct RunShareArtworkStyle {
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

struct RunShareTemplatePolicy {
    let routeRequired: Bool
    let metricCandidates: [RunShareField]
    let requiredMetrics: [RunShareField]
    let metricMin: Int
    let metricMax: Int
    let supportsFontDebug: Bool
    let supportsColorDebug: Bool
}

struct RunShareRGBA: Equatable, Hashable {
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

enum RunShareAccentPreset: String, CaseIterable, Identifiable {
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

enum RunShareAccentColorSource: Equatable {
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

struct RunShareAdvancedStyle: Equatable {
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
