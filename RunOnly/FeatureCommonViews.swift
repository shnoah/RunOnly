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
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.18))
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.18),
                            tint.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
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
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.24),
                            tint.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .fixedSize()
    }
}

// PR 카드에는 현재 기록과 검토 대기 상태를 함께 보여준다.
