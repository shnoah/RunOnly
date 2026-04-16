import SwiftUI

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
                .foregroundStyle(.white)
            Text(LocalizedStringKey(message))
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
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
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(LocalizedStringKey(detail))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// 좁은 공간에서도 핵심 수치를 짧게 보여주기 위한 소형 칩이다.
struct CompactMetricChip: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(LocalizedStringKey(detail))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// 실내/실외 같은 짧은 상태를 눈에 띄게 붙이는 배지다.
struct RunEnvironmentBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.14))
            )
    }
}

// 상세/공유 화면에서 거리·시간 같은 값을 작은 타일 단위로 재사용한다.
struct RunMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

// 기록 리스트 한 행은 날짜, 신발, 핵심 3개 수치를 한 번에 읽히게 구성한다.
struct RunRowCard: View {
    let run: RunningWorkout
    let shoeDisplay: RunShoeAssignmentDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("\(run.recordCompactDateText) / \(run.environmentShortText)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                Text(shoeDisplay.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(shoeForegroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(shoeBackgroundColor))

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.42))
            }

            HStack(spacing: 0) {
                RunRowMetricColumn(title: "거리", value: run.distanceText)
                metricDivider
                RunRowMetricColumn(title: "시간", value: run.durationText)
                metricDivider
                RunRowMetricColumn(title: "페이스", value: run.paceText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 12, y: 6)
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
}

private struct RunRowMetricColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.54))
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
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
        VStack(alignment: .leading, spacing: 10) {
            if let systemImage {
                HStack(spacing: 7) {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint.opacity(0.92))

                    Text(LocalizedStringKey(title))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }
            } else {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.055),
                            tint.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 16, y: 8)
        )
    }
}

// 앱 전체 배경은 단색 대신 그라디언트와 광원 느낌을 섞어 러닝 앱 톤을 만든다.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.11, blue: 0.17),
                    Color(red: 0.05, green: 0.07, blue: 0.12),
                    Color(red: 0.03, green: 0.04, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.25, green: 0.78, blue: 0.92).opacity(0.16),
                    .clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 360
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color(red: 0.97, green: 0.61, blue: 0.35).opacity(0.12),
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
