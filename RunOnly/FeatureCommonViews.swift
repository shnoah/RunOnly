import Charts
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 홈 탭은 요약 카드와 최근 상태를 빠르게 보는 대시보드 역할을 맡는다.
struct FeatureToneBadge: View {
    let text: String
    let tint: Color
    let foreground: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.18))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.28), lineWidth: 1)
                    )
            )
    }
}

struct MetricDetailHeroCard<Content: View>: View {
    let primaryBadge: String
    let secondaryBadge: String?
    let title: String
    let subtitle: String
    let tint: Color
    let secondaryTint: Color
    let titleFont: Font
    @ViewBuilder let content: Content

    init(
        primaryBadge: String,
        secondaryBadge: String? = nil,
        title: String,
        subtitle: String,
        tint: Color = PNR2026.track,
        secondaryTint: Color = PNR2026.water,
        titleFont: Font = .system(size: 30, weight: .bold, design: .rounded),
        @ViewBuilder content: () -> Content
    ) {
        self.primaryBadge = primaryBadge
        self.secondaryBadge = secondaryBadge
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.secondaryTint = secondaryTint
        self.titleFont = titleFont
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                FeatureToneBadge(
                    text: primaryBadge,
                    tint: tint,
                    foreground: PNR2026.ink.opacity(0.92)
                )

                Spacer(minLength: 8)

                if let secondaryBadge, !secondaryBadge.isEmpty {
                    FeatureToneBadge(
                        text: secondaryBadge,
                        tint: secondaryTint,
                        foreground: PNR2026.ink.opacity(0.88)
                    )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(title))
                    .font(titleFont)
                    .foregroundStyle(PNR2026.ink)
                    .monospacedDigit()
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(LocalizedStringKey(subtitle))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PNR2026.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(PNR2026.surfaceHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .stroke(PNR2026.line, lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 3)
                        .padding(.vertical, 18)
                }
        )
    }
}

struct FeatureMiniStatCard: View {
    let title: String
    let value: String
    let detail: String?
    let tint: Color

    init(title: String, value: String, detail: String? = nil, tint: Color) {
        self.title = title
        self.value = value
        self.detail = detail
        self.tint = tint
    }

    var body: some View {
        PNRMetricBlock(title: title, value: value, detail: detail, tint: tint)
    }
}

struct FeatureFormFieldCard<Content: View>: View {
    let title: String
    let caption: String?
    let tint: Color
    @ViewBuilder let content: Content

    init(
        title: String,
        caption: String? = nil,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.caption = caption
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            content

            if let caption, !caption.isEmpty {
                Text(LocalizedStringKey(caption))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(PNR2026.surfaceHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .stroke(PNR2026.line, lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 3)
                        .padding(.vertical, 12)
                }
        )
    }
}

struct FeatureChartPlotBackground: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
            .fill(PNR2026.surfaceHigh)
            .overlay(
                RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                    .stroke(PNR2026.line, lineWidth: 1)
            )
    }
}

struct FeatureChartCallout: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))

            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PNR2026.surfaceHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.26), lineWidth: 1)
                )
        )
        .fixedSize()
    }
}

// PR 카드에는 현재 기록과 검토 대기 상태를 함께 보여준다.
