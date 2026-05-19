import SwiftUI
import UIKit

struct RunShareTemplateLayoutSpec {
    let previewPreferredWidth: CGFloat
    let fontScaleRange: ClosedRange<Double>
}

enum RunShareTemplate: String, CaseIterable, Identifiable {
    case sticker
    case style1
    case microInline
    case minimalStack
    case glassPills
    case serifCaption
    case raceLabel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sticker:
            return L10n.tr("스티커")
        case .style1:
            return L10n.tr("스타일 1")
        case .microInline:
            return L10n.tr("한 줄")
        case .minimalStack:
            return L10n.tr("스택")
        case .glassPills:
            return L10n.tr("글래스")
        case .serifCaption:
            return L10n.tr("세리프")
        case .raceLabel:
            return L10n.tr("레이스")
        }
    }

    var descriptionText: String {
        switch self {
        case .sticker:
            return L10n.tr("투명 배경 PNG라 메신저, 노트, 스토리 편집 앱에 붙여 넣기 좋습니다.")
        case .style1:
            return L10n.tr("인스타 스토리 상단 오버레이 느낌의 반투명 스티커입니다.")
        case .microInline:
            return L10n.tr("거리, 시간, 페이스를 한 줄로 붙이는 가장 작은 타이포 스티커입니다.")
        case .minimalStack:
            return L10n.tr("DIST, TIME, PACE를 세로로 쌓은 미니 스탯 스티커입니다.")
        case .glassPills:
            return L10n.tr("작은 유리 pill 세 개로 핵심 지표만 보여줍니다.")
        case .serifCaption:
            return L10n.tr("짧은 문구와 작은 기록을 세리프 타이포로 남깁니다.")
        case .raceLabel:
            return L10n.tr("작은 레이스 태그처럼 러닝 번호와 기록을 보여줍니다.")
        }
    }

    var quickStartTitle: String {
        switch self {
        case .sticker:
            return L10n.tr("클립보드 스티커")
        case .style1:
            return L10n.tr("상단 오버레이")
        case .microInline:
            return L10n.tr("마이크로 한 줄")
        case .minimalStack:
            return L10n.tr("미니 스택")
        case .glassPills:
            return L10n.tr("글래스 pill")
        case .serifCaption:
            return L10n.tr("세리프 캡션")
        case .raceLabel:
            return L10n.tr("레이스 라벨")
        }
    }

    var useCaseLabel: String {
        switch self {
        case .sticker:
            return L10n.tr("클립보드")
        case .style1:
            return L10n.tr("스토리")
        case .microInline, .minimalStack, .glassPills:
            return L10n.tr("미니")
        case .serifCaption:
            return L10n.tr("캡션")
        case .raceLabel:
            return L10n.tr("레이스")
        }
    }

    var canvasSize: CGSize {
        switch self {
        case .sticker:
            return CGSize(width: 520, height: 860)
        case .style1:
            return CGSize(width: 1080, height: 300)
        case .microInline:
            return CGSize(width: 900, height: 120)
        case .minimalStack:
            return CGSize(width: 360, height: 250)
        case .glassPills:
            return CGSize(width: 720, height: 180)
        case .serifCaption:
            return CGSize(width: 620, height: 220)
        case .raceLabel:
            return CGSize(width: 440, height: 200)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .sticker:
            return 0
        case .style1:
            return 0
        case .microInline, .minimalStack, .glassPills, .serifCaption, .raceLabel:
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

    var edgeSafeInset: CGFloat {
        switch self {
        case .style1:
            return 18
        case .microInline, .glassPills:
            return 12
        case .sticker, .minimalStack, .serifCaption, .raceLabel:
            return 0
        }
    }

    var defaultEnabledFields: Set<RunShareField> {
        switch self {
        case .sticker:
            return [.logo, .route, .distance, .duration, .pace]
        case .style1:
            return [.route, .distance, .duration]
        case .microInline, .minimalStack, .glassPills:
            return [.distance, .duration, .pace]
        case .serifCaption, .raceLabel:
            return [.distance, .duration]
        }
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
                supportsFieldSelection: true,
                supportsFontDebug: true,
                supportsColorDebug: true
            )
        case .microInline:
            return RunShareTemplatePolicy(
                routeRequired: false,
                metricCandidates: [.distance, .duration, .pace],
                requiredMetrics: [.distance, .duration, .pace],
                metricMin: 3,
                metricMax: 3,
                supportsFieldSelection: false,
                supportsFontDebug: false,
                supportsColorDebug: false
            )
        case .minimalStack:
            return RunShareTemplatePolicy(
                routeRequired: false,
                metricCandidates: [.distance, .duration, .pace],
                requiredMetrics: [.distance, .duration, .pace],
                metricMin: 3,
                metricMax: 3,
                supportsFieldSelection: false,
                supportsFontDebug: false,
                supportsColorDebug: false
            )
        case .glassPills:
            return RunShareTemplatePolicy(
                routeRequired: false,
                metricCandidates: [.distance, .duration, .pace],
                requiredMetrics: [.distance, .duration, .pace],
                metricMin: 3,
                metricMax: 3,
                supportsFieldSelection: false,
                supportsFontDebug: false,
                supportsColorDebug: false
            )
        case .serifCaption:
            return RunShareTemplatePolicy(
                routeRequired: false,
                metricCandidates: [.distance, .duration],
                requiredMetrics: [.distance, .duration],
                metricMin: 2,
                metricMax: 2,
                supportsFieldSelection: false,
                supportsFontDebug: false,
                supportsColorDebug: false
            )
        case .raceLabel:
            return RunShareTemplatePolicy(
                routeRequired: false,
                metricCandidates: [.distance, .duration],
                requiredMetrics: [.distance, .duration],
                metricMin: 2,
                metricMax: 2,
                supportsFieldSelection: false,
                supportsFontDebug: false,
                supportsColorDebug: false
            )
        case .sticker:
            return RunShareTemplatePolicy(
                routeRequired: true,
                metricCandidates: [.distance, .duration, .pace, .elevationGain, .heartRate, .cadence],
                requiredMetrics: [],
                metricMin: 0,
                metricMax: 4,
                supportsFieldSelection: true,
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
                fontScaleRange: 0.75...1.45
            )
        case .style1:
            return RunShareTemplateLayoutSpec(
                previewPreferredWidth: 440,
                fontScaleRange: 0.92...1.22
            )
        case .microInline:
            return RunShareTemplateLayoutSpec(
                previewPreferredWidth: 340,
                fontScaleRange: 1...1
            )
        case .minimalStack:
            return RunShareTemplateLayoutSpec(
                previewPreferredWidth: 172,
                fontScaleRange: 1...1
            )
        case .glassPills:
            return RunShareTemplateLayoutSpec(
                previewPreferredWidth: 320,
                fontScaleRange: 1...1
            )
        case .serifCaption:
            return RunShareTemplateLayoutSpec(
                previewPreferredWidth: 280,
                fontScaleRange: 1...1
            )
        case .raceLabel:
            return RunShareTemplateLayoutSpec(
                previewPreferredWidth: 220,
                fontScaleRange: 1...1
            )
        }
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
            return "PNR"
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
    let supportsFieldSelection: Bool
    let supportsFontDebug: Bool
    let supportsColorDebug: Bool

    var supportsEditorControls: Bool {
        supportsFieldSelection || supportsFontDebug || supportsColorDebug
    }
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
            return RunShareAdvancedStyle(fontChoice: .rounded, fontScale: 1.08, accentColorSource: .preset(.sky))
        case .style1:
            return RunShareAdvancedStyle(fontChoice: .serif, fontScale: 1.12, accentColorSource: .preset(.coral))
        case .microInline:
            return RunShareAdvancedStyle(fontChoice: .condensed, fontScale: 1, accentColorSource: .preset(.mint))
        case .minimalStack:
            return RunShareAdvancedStyle(fontChoice: .monospaced, fontScale: 1, accentColorSource: .preset(.sky))
        case .glassPills:
            return RunShareAdvancedStyle(fontChoice: .system, fontScale: 1, accentColorSource: .preset(.slate))
        case .serifCaption:
            return RunShareAdvancedStyle(fontChoice: .serif, fontScale: 1, accentColorSource: .preset(.amber))
        case .raceLabel:
            return RunShareAdvancedStyle(fontChoice: .condensed, fontScale: 1, accentColorSource: .preset(.mint))
        }
    }

    static var defaultsByTemplate: [RunShareTemplate: RunShareAdvancedStyle] {
        Dictionary(uniqueKeysWithValues: RunShareTemplate.allCases.map { ($0, defaultStyle(for: $0)) })
    }
}
