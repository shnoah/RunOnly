import SwiftUI

struct ShareTabView: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    @State private var templateSelection: PreparedRunShareContext?
    @State private var isPreparingShare = false
    @State private var preparationErrorMessage: String?

    private var recentRuns: [RunningWorkout] {
        guard case .loaded(let runs) = viewModel.state else { return [] }
        return Array(runs.prefix(8))
    }

    private var heroRun: RunningWorkout? {
        recentRuns.first
    }

    private var secondaryRuns: [RunningWorkout] {
        Array(recentRuns.dropFirst())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PNRPageHeader(
                        eyebrow: "CREATE",
                        title: "공유",
                        subtitle: "최근 러닝을 골라 바로 스티커로 만듭니다."
                    )

                    switch viewModel.state {
                    case .idle, .loading:
                        ShareLoadingPanel()
                    case .failed(let message):
                        StatusView(
                            title: "공유할 기록을 불러오지 못했습니다",
                            message: message,
                            buttonTitle: "다시 시도"
                        ) {
                            Task {
                                await viewModel.load()
                            }
                        }
                    case .empty:
                        ShareEmptyPanel {
                            openDemoTemplates()
                        }
                    case .loaded:
                        if let heroRun {
                            ShareHeroRunCard(
                                run: heroRun,
                                isPreparing: isPreparingShare,
                                action: {
                                    prepareTemplates(for: heroRun)
                                }
                            )
                        }

                        if !secondaryRuns.isEmpty {
                            recentRunsSection
                        }
                    }

                    if isPreparingShare {
                        SharePreparingPanel()
                    }

                    if let preparationErrorMessage {
                        ShareErrorPanel(message: preparationErrorMessage)
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadIfNeeded()
            }
            .sheet(item: $templateSelection) { context in
                TemplatePickerView(context: context)
            }
        }
    }

    private var recentRunsSection: some View {
        PNRSection(title: "최근 러닝", detail: "기록 선택") {
            VStack(spacing: 8) {
                ForEach(secondaryRuns) { run in
                    Button {
                        prepareTemplates(for: run)
                    } label: {
                        ShareRunRow(run: run)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreparingShare)
                }
            }
        }
    }

    private func prepareTemplates(for run: RunningWorkout) {
        guard !isPreparingShare else { return }

        preparationErrorMessage = nil
        isPreparingShare = true

        Task {
            let loader = RunDetailViewModel(run: run)
            await loader.loadIfNeeded()

            switch loader.state {
            case .loaded(let detail):
                templateSelection = PreparedRunShareContext(
                    run: run,
                    detail: detail,
                    summary: detail.summaryMetrics.mergingMissingValues(from: loader.cachedSummary)
                )
            case .failed(let message):
                preparationErrorMessage = message
            case .idle, .loading:
                preparationErrorMessage = L10n.tr("공유 이미지를 준비하지 못했습니다.")
            }

            isPreparingShare = false
        }
    }

    private func openDemoTemplates() {
        templateSelection = PreparedRunShareContext(
            run: .demoSample,
            detail: .mockCompleteMetrics,
            summary: RunDetail.mockCompleteMetrics.summaryMetrics
        )
    }
}

private struct PreparedRunShareContext: Identifiable {
    let id = UUID()
    let run: RunningWorkout
    let detail: RunDetail
    let summary: RunSummaryMetrics?
}

private struct PreparedRunShare: Identifiable {
    let id = UUID()
    let context: PreparedRunShareContext
    let template: RunShareTemplate
}

private struct TemplatePickerView: View {
    let context: PreparedRunShareContext
    @State private var selectedShare: PreparedRunShare?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PNRPageHeader(
                        eyebrow: "TEMPLATE",
                        title: "템플릿",
                        subtitle: "\(context.run.distanceText) 러닝을 어떤 무드로 남길까요."
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 164), spacing: 12)], spacing: 12) {
                        ForEach(RunShareTemplate.allCases) { template in
                            Button {
                                selectedShare = PreparedRunShare(context: context, template: template)
                            } label: {
                                ShareTemplatePreviewCard(
                                    context: context,
                                    template: template
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedShare) { share in
                RunShareComposerView(
                    run: share.context.run,
                    detail: share.context.detail,
                    summary: share.context.summary,
                    initialTemplate: share.template,
                    showsTemplateSelector: false
                )
            }
        }
    }
}

private struct ShareHeroRunCard: View {
    let run: RunningWorkout
    let isPreparing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("최근 러닝")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PNR2026.track)
                        Text(run.distanceText)
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(PNR2026.ink)
                            .monospacedDigit()
                    }

                    Spacer()

                    Label(isPreparing ? "준비 중" : "템플릿", systemImage: "square.grid.2x2")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(PNR2026.track)
                        )
                }

                HStack(spacing: 10) {
                    PNRMetricBlock(title: "시간", value: run.durationText, tint: PNR2026.water)
                    PNRMetricBlock(title: "페이스", value: run.paceText, tint: PNR2026.heat)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                    .fill(PNR2026.surfaceHigh)
                    .overlay(
                        RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                            .stroke(PNR2026.line, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isPreparing)
    }
}

private struct ShareTemplatePreviewCard: View {
    let context: PreparedRunShareContext
    let template: RunShareTemplate

    private let previewLimit = CGSize(width: 154, height: 146)

    private var previewSize: CGSize {
        let scale = min(
            previewLimit.width / max(template.canvasSize.width, 1),
            previewLimit.height / max(template.canvasSize.height, 1)
        )
        return CGSize(
            width: template.canvasSize.width * scale,
            height: template.canvasSize.height * scale
        )
    }

    private var style: RunShareArtworkStyle {
        RunShareAdvancedStyle.defaultStyle(for: template).artworkStyle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                TransparentPreviewBackground()
                    .clipShape(RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous))

                RunShareArtworkView(
                    run: context.run,
                    detail: context.detail,
                    template: template,
                    enabledFields: template.defaultEnabledFields,
                    summary: context.summary,
                    style: style
                )
                .frame(width: template.canvasSize.width, height: template.canvasSize.height)
                .scaleEffect(previewSize.width / template.canvasSize.width, anchor: .topLeading)
                .frame(width: previewSize.width, height: previewSize.height, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 148)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.quickStartTitle)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(PNR2026.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(template.descriptionText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PNR2026.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 4)

                Text(template.useCaseLabel)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PNR2026.track)
                    )
            }
        }
        .padding(12)
        .frame(minHeight: 218, alignment: .topLeading)
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

private struct ShareRunRow: View {
    let run: RunningWorkout

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(run.startDate, format: .dateTime.month().day().hour().minute())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PNR2026.muted)
                Text(run.distanceText)
                    .font(.title3.weight(.black))
                    .foregroundStyle(PNR2026.ink)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(run.paceText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PNR2026.ink)
                Text(run.durationText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PNR2026.muted)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PNR2026.muted)
        }
        .padding(12)
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

private struct ShareLoadingPanel: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(PNR2026.track)
            Text("공유할 러닝 기록을 불러오는 중")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PNR2026.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(PNR2026.surface)
        )
    }
}

private struct SharePreparingPanel: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(PNR2026.track)
            Text("템플릿 준비 중")
                .font(.caption.weight(.bold))
                .foregroundStyle(PNR2026.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(PNR2026.surface)
        )
    }
}

private struct ShareErrorPanel: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
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

private struct ShareEmptyPanel: View {
    let openDemo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("공유할 러닝이 아직 없습니다")
                .font(.title3.weight(.black))
                .foregroundStyle(PNR2026.ink)
            Text("Apple 건강 러닝을 불러오면 최근 기록으로 바로 스티커를 만들 수 있습니다.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PNR2026.muted)

            Button(action: openDemo) {
                Label("샘플로 열기", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PNR2026.track)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
