import SwiftUI

enum PNR2026 {
    static let canvas = Color(red: 0.08, green: 0.11, blue: 0.17)
    static let canvasLift = Color(red: 0.05, green: 0.07, blue: 0.12)
    static let surface = Color.white.opacity(0.07)
    static let surfaceHigh = Color.white.opacity(0.10)
    static let ink = Color.white
    static let muted = Color.white.opacity(0.64)
    static let line = Color.white.opacity(0.10)
    static let track = Color(red: 0.29, green: 0.88, blue: 0.63)
    static let water = Color(red: 0.42, green: 0.76, blue: 1.0)
    static let heat = Color(red: 0.95, green: 0.59, blue: 0.32)
    static let rose = Color(red: 0.94, green: 0.41, blue: 0.45)
    static let radius: CGFloat = 20
    static let inset: CGFloat = 16
}

struct PNRPageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String?
    var actionTitle: String? = nil
    var actionSystemImage: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(eyebrow))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PNR2026.track)
                    .textCase(.uppercase)

                Text(LocalizedStringKey(title))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(PNR2026.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                if let subtitle, !subtitle.isEmpty {
                    Text(LocalizedStringKey(subtitle))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PNR2026.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 10)

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage ?? "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PNR2026.track)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.18))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(PNR2026.line, lineWidth: 1)
                                )
                        )
                        .accessibilityLabel(Text(LocalizedStringKey(actionTitle)))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PNRSection<Content: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder let content: Content

    init(title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(title))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PNR2026.ink)
                Spacer()
                if let detail, !detail.isEmpty {
                    Text(LocalizedStringKey(detail))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PNR2026.muted)
                }
            }

            content
        }
    }
}

struct PNRMetricBlock: View {
    let title: String
    let value: String
    let detail: String?
    var tint: Color = PNR2026.track

    init(title: String, value: String, detail: String? = nil, tint: Color = PNR2026.track) {
        self.title = title
        self.value = value
        self.detail = detail
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(tint)
                    .frame(width: 16, height: 3)
                Text(LocalizedStringKey(title))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let detail, !detail.isEmpty {
                Text(LocalizedStringKey(detail))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(labelColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .stroke(PNR2026.line, lineWidth: 1)
                )
        )
    }

    private var valueColor: Color { PNR2026.ink }

    private var labelColor: Color { PNR2026.muted }
}

struct PNRPlainRow<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leading
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(PNR2026.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .stroke(PNR2026.line, lineWidth: 1)
                )
        )
    }
}

// 제목과 값을 한 줄 묶음으로 보여주는 가장 작은 공용 메트릭 컴포넌트다.
struct MetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// 로딩 실패/빈 상태처럼 화면 전체를 안내 문구 하나로 대체할 때 사용한다.
struct StatusView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(.title3.weight(.semibold))
                .foregroundStyle(PNR2026.ink)
            Text(LocalizedStringKey(message))
                .font(.body)
                .foregroundStyle(PNR2026.muted)
                .multilineTextAlignment(.center)
            Button(LocalizedStringKey(buttonTitle), action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 홈과 설정 계열에서 반복되는 큰 요약 카드를 같은 스타일로 맞춘다.
struct SummaryCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        PNRMetricBlock(title: title, value: value, detail: detail, tint: PNR2026.water)
            .frame(minHeight: 108)
    }
}

// 좁은 공간에서도 핵심 수치를 짧게 보여주기 위한 소형 칩이다.
struct CompactMetricChip: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        PNRMetricBlock(title: title, value: value, detail: detail, tint: PNR2026.track)
    }
}

// 실내/실외 같은 짧은 상태를 눈에 띄게 붙이는 배지다.
struct RunEnvironmentBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(PNR2026.track)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(PNR2026.track.opacity(0.14))
            )
    }
}

// 상세/공유 화면에서 거리·시간 같은 값을 작은 타일 단위로 재사용한다.
struct RunMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        PNRMetricBlock(title: title, value: value, tint: PNR2026.track)
    }
}

// 기록 리스트 한 행은 날짜, 신발, 핵심 3개 수치를 한 번에 읽히게 구성한다.
struct RunRowCard: View {
    let run: RunningWorkout
    let shoeDisplay: RunShoeAssignmentDisplay

    var body: some View {
        PNRPlainRow {
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text(monthDayText)
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                        .foregroundStyle(PNR2026.ink)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(timeText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PNR2026.muted)
                }
                .frame(width: 48)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(run.environmentShortText)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PNR2026.track)
                        Text(shoeDisplay.name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PNR2026.muted)
                            .lineLimit(1)
                    }

                    Text(run.distanceText)
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(PNR2026.ink)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("\(run.durationText) / \(run.paceText)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PNR2026.muted)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
        } trailing: {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PNR2026.muted)
        }
        .background(
            HStack {
                Rectangle()
                    .fill(PNR2026.track)
                    .frame(width: 3)
                    .padding(.vertical, 8)
                Spacer()
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(run.recordCompactDateText), \(run.environmentShortText)"))
        // 시각 카드 구성을 VoiceOver에서도 같은 의미 순서로 읽도록 합친다.
        .accessibilityValue(Text("\(L10n.tr("거리")) \(run.distanceText), \(L10n.tr("시간")) \(run.durationText), \(L10n.tr("페이스")) \(run.paceText), \(shoeDisplay.name)"))
    }

    private var shoeForegroundColor: Color {
        shoeDisplay.isAssigned ? Color(red: 0.29, green: 0.88, blue: 0.63) : .white.opacity(0.7)
    }

    private var shoeBackgroundColor: Color {
        shoeDisplay.isAssigned
            ? Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.14)
            : Color.white.opacity(0.08)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 34)
            .padding(.horizontal, 10)
    }

    private var monthDayText: String {
        let formatter = DateFormatter()
        formatter.locale = RunDisplayFormatter.currentAppLocale
        formatter.timeZone = .current
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: run.startDate)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = RunDisplayFormatter.currentAppLocale
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: run.startDate)
    }
}

private struct RunRowMetricColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PNR2026.muted)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(PNR2026.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// 상세 화면 섹션은 아이콘/색/카드 배경 규칙을 공통으로 맞춰 시각 언어를 통일한다.
struct DetailSection<Content: View>: View {
    let title: String
    let systemImage: String?
    let tint: Color
    @ViewBuilder let content: Content

    init(
        title: String,
        systemImage: String? = nil,
        tint: Color = Color(red: 0.37, green: 0.58, blue: 0.88),
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let systemImage {
                HStack(spacing: 7) {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)

                    Text(LocalizedStringKey(title))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PNR2026.ink)
                }
            } else {
                Text(LocalizedStringKey(title))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PNR2026.ink)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(PNR2026.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .stroke(PNR2026.line, lineWidth: 1)
                )
        )
    }
}

// 앱 전체 배경은 main의 다크 컬러웨이를 유지한다.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PNR2026.canvas,
                    PNR2026.canvasLift,
                    Color(red: 0.03, green: 0.04, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    PNR2026.water.opacity(0.16),
                    .clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 360
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    PNR2026.heat.opacity(0.12),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 320
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

// 아래 helper는 오래된 화면 코드에서도 같은 표시 규칙을 바로 재사용하려는 얇은 래퍼다.
func formatKilometers(_ kilometers: Double) -> String {
    RunDisplayFormatter.distance(kilometers: kilometers, fractionLength: 1)
}

func formatDuration(_ seconds: Double) -> String {
    RunDisplayFormatter.duration(seconds)
}

func formatSignedDuration(_ seconds: Double) -> String {
    RunDisplayFormatter.signedDuration(seconds)
}
