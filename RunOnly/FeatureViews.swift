import Charts
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 홈 탭은 요약 카드와 최근 상태를 빠르게 보는 대시보드 역할을 맡는다.
struct HomeTabView: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("러닝 데이터를 불러오는 중")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .empty:
                    HomeEmptyStateView(
                        action: {
                            Task {
                                await viewModel.load()
                            }
                        }
                    )

                case .failed(let message):
                    RunReviewFallbackView(
                        title: "불러오기에 실패했습니다",
                        message: message,
                        buttonTitle: "다시 시도"
                    ) {
                        Task {
                            await viewModel.load()
                        }
                    }

                case .loaded(let runs):
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(AppMetadata.displayName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .tracking(0.2)
                                .padding(.horizontal, 20)

                            DashboardHeader(
                                viewModel: viewModel,
                                summary: viewModel.summary,
                                runs: runs,
                                vo2MaxSamples: viewModel.vo2MaxSamples,
                                showAppleWorkoutOnly: $viewModel.showAppleWorkoutOnly
                            ) {
                                viewModel.applyFilter()
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}

// 기록 탭은 월/일 기준으로 러닝 목록을 탐색할 수 있게 구성한다.
struct RecordTabView: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    @State private var showingCalendar = false
    @State private var showingPersonalRecords = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("러닝 데이터를 불러오는 중")
                        .tint(.white)
                        .foregroundStyle(.white)
                case .empty:
                    RunReviewFallbackView(
                        title: "러닝 기록이 없습니다",
                        message: "표시할 러닝 기록이 없습니다.",
                        buttonTitle: "새로고침"
                    ) {
                        Task {
                            await viewModel.load()
                        }
                    }
                case .failed(let message):
                    RunReviewFallbackView(
                        title: "불러오기에 실패했습니다",
                        message: message,
                        buttonTitle: "다시 시도"
                    ) {
                        Task {
                            await viewModel.load()
                        }
                    }
                case .loaded:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            RecordMonthHeader(
                                monthText: viewModel.selectedMonthLabelText,
                                selectedDateText: viewModel.selectedDateLabelText,
                                canMoveNext: viewModel.canMoveToNextRecordMonth,
                                isViewingCurrentMonth: viewModel.isViewingCurrentRecordMonth,
                                isLoading: viewModel.isLoadingMoreHistory,
                                pendingRecordCount: viewModel.pendingPersonalRecordCandidates.count,
                                onPreviousMonth: {
                                    Task {
                                        await viewModel.moveRecordMonth(by: -1)
                                    }
                                },
                                onNextMonth: {
                                    Task {
                                        await viewModel.moveRecordMonth(by: 1)
                                    }
                                },
                                onOpenCalendar: {
                                    showingCalendar = true
                                },
                                onOpenPersonalRecords: {
                                    showingPersonalRecords = true
                                },
                                onJumpToCurrentMonth: {
                                    Task {
                                        await viewModel.jumpToCurrentRecordMonth()
                                    }
                                },
                                onClearDate: {
                                    viewModel.clearRecordDateSelection()
                                }
                            )
                            .padding(.horizontal, 16)

                            RecordMonthSummaryCard(summary: viewModel.selectedMonthSummary)
                                .padding(.horizontal, 16)

                            VStack(spacing: 14) {
                                NavigationLink {
                                    RunDetailView(
                                        run: .demoSample,
                                        initialDebugScenario: .completeMetrics
                                    )
                                } label: {
                                    DemoRunAccessCard()
                                }
                                .buttonStyle(.plain)

                                if viewModel.recordRuns.isEmpty {
                                    DetailSection(title: emptyRecordTitle) {
                                        Text(emptyRecordMessage)
                                            .foregroundStyle(.white.opacity(0.72))
                                    }
                                } else {
                                    ForEach(viewModel.recordRuns) { run in
                                        NavigationLink {
                                            RunDetailView(run: run)
                                        } label: {
                                            RunRowCard(run: run)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)

                            if viewModel.isLoadingMoreHistory, viewModel.selectedMonthRuns.isEmpty {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("이전 기록을 불러오는 중")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.82))
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                    .sheet(isPresented: $showingCalendar) {
                        RecordCalendarSheet(viewModel: viewModel)
                    }
                    .sheet(isPresented: $showingPersonalRecords) {
                        NavigationStack {
                            PersonalRecordsManagementView(
                                currentRecords: viewModel.personalRecords,
                                pendingCandidates: viewModel.pendingPersonalRecordCandidates,
                                onApproveCandidate: viewModel.approvePersonalRecordCandidate,
                                onDismissCandidate: viewModel.dismissPersonalRecordCandidate
                            )
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var emptyRecordTitle: String {
        viewModel.selectedRecordDate != nil ? "선택한 날짜에 러닝이 없습니다" : "선택한 달에 러닝이 없습니다"
    }

    private var emptyRecordMessage: String {
        if let selectedDateText = viewModel.selectedDateLabelText {
            return L10n.format("%@에 기록된 러닝이 없습니다.", selectedDateText)
        }
        return L10n.format("%@에 기록된 러닝이 없습니다.", viewModel.selectedMonthLabelText)
    }
}

struct HealthKitOnboardingView: View {
    let showsDismissButton: Bool
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutsViewModel: RunningWorkoutsViewModel
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingSampleRun = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppMetadata.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .tracking(0.2)

                    Text("HealthKit 연결 전에 확인할 점")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text(AppMetadata.healthUsageSummary)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                DetailSection(title: "앱이 하는 일") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AppMetadata.onboardingFeatureHighlights, id: \.self) { item in
                            Text(item)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "개인정보와 저장 방식") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AppMetadata.privacyStorageHighlights, id: \.self) { item in
                            Text(item)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "고지") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AppMetadata.nonMedicalNoticeLines, id: \.self) { item in
                            Text(item)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "바로 확인하기") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("권한을 주기 전에 샘플 러닝으로 상세 차트와 공유 화면을 먼저 볼 수 있습니다.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))

                        Button {
                            showingSampleRun = true
                        } label: {
                            DemoRunAccessCard()
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        onContinue()
                        if showsDismissButton {
                            dismiss()
                        }
                    } label: {
                        Text("HealthKit 연결하고 시작")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.29, green: 0.88, blue: 0.63))
                            )
                    }
                    .buttonStyle(.plain)

                    Text(L10n.format("권한은 언제든 %@에서 변경할 수 있습니다.", AppMetadata.healthPermissionSettingsPath))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(AppBackground())
        .navigationTitle("HealthKit 안내")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingSampleRun) {
            NavigationStack {
                RunDetailView(
                    run: .demoSample,
                    initialDebugScenario: .completeMetrics
                )
                .environmentObject(workoutsViewModel)
                .environmentObject(shoeStore)
            }
        }
    }
}

private struct RunReviewFallbackView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RunReviewStatusCard(
                    title: title,
                    message: message,
                    buttonTitle: buttonTitle,
                    action: action
                )

                DetailSection(title: "샘플 러닝으로 둘러보기") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HealthKit 데이터가 없어도 샘플 러닝으로 상세 차트, 심박 존, 공유 화면을 바로 확인할 수 있습니다.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))

                        NavigationLink {
                            RunDetailView(
                                run: .demoSample,
                                initialDebugScenario: .completeMetrics
                            )
                        } label: {
                            DemoRunAccessCard()
                        }
                        .buttonStyle(.plain)

                        Text("상세 화면의 '다른 샘플 보기' 메뉴에서 pause 포함, 빈 경로 같은 다른 시나리오도 볼 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 104)
        }
    }
}

private struct HomeEmptyStateView: View {
    @State private var isExpanded = false
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(AppMetadata.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .tracking(0.2)
                    .padding(.horizontal, 4)

                RunReviewStatusCard(
                    title: "러닝 기록이 없습니다",
                    buttonTitle: "새로고침",
                    action: action
                )

                DetailSection(title: "RunOnly 소개") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(AppMetadata.homeIntroSummary)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(isExpanded ? nil : 2)

                        if isExpanded {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(AppMetadata.homeIntroDetails, id: \.self) { item in
                                    Text(item)
                                }
                            }
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.74))
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Text(isExpanded ? "접기" : "더 보기")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HomeEmptyDashboardPreview()
            }
            .padding(16)
            .padding(.bottom, 104)
        }
    }
}

private struct HomeEmptyDashboardPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardSectionHeader(title: "핵심 요약")

            HStack(spacing: 10) {
                DashboardCompactSummaryLink(
                    title: "거리",
                    value: "0 km",
                    detail: "이번 달 데이터 없음"
                )
                DashboardCompactSummaryLink(
                    title: "추세",
                    value: "기록 대기",
                    detail: "러닝 1회 이상 필요"
                )
                DashboardCompactSummaryLink(
                    title: "VO2 Max",
                    value: "--",
                    detail: "측정 데이터 없음"
                )
            }

            PredictionSummaryCard(
                predicted5KText: "--:--",
                predicted10KText: "--:--",
                predictedHalfText: "--:--:--",
                predictedMarathonText: "--:--:--"
            )
        }
    }
}

private struct RunReviewStatusCard: View {
    let title: String
    let message: String?
    let buttonTitle: String
    let action: () -> Void

    init(title: String, message: String? = nil, buttonTitle: String, action: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if let message {
                Text(LocalizedStringKey(message))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button(LocalizedStringKey(buttonTitle), action: action)
                .buttonStyle(.borderedProminent)

            Text(L10n.format("권한은 %@에서 다시 변경할 수 있습니다.", AppMetadata.healthPermissionSettingsPath))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

private struct DemoRunAccessCard: View {
    private var sampleDistanceText: String {
        RunDisplayFormatter.distance(
            meters: RunningWorkout.demoSample.distanceInMeters,
            fractionLength: 2
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("샘플 러닝 열기")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(L10n.format("기본 샘플 %@ · %@", sampleDistanceText, RunningWorkout.demoSample.durationText))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text("심박, 케이던스, 상승 고도, 스플릿, 지도, 공유 이미지를 한 번에 확인할 수 있습니다.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// 월 이동과 날짜 필터 진입 버튼을 담는 상단 헤더다.
private struct RecordMonthHeader: View {
    let monthText: String
    let selectedDateText: String?
    let canMoveNext: Bool
    let isViewingCurrentMonth: Bool
    let isLoading: Bool
    let pendingRecordCount: Int
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onOpenCalendar: () -> Void
    let onOpenPersonalRecords: () -> Void
    let onJumpToCurrentMonth: () -> Void
    let onClearDate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthText)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel(Text(L10n.format("현재 선택 월: %@", monthText)))

            ViewThatFits(in: .horizontal) {
                controlsRow(
                    buttonFont: .subheadline.weight(.semibold),
                    verticalPadding: 10,
                    horizontalPadding: 12,
                    arrowSize: 38
                )
                controlsRow(
                    buttonFont: .caption.weight(.semibold),
                    verticalPadding: 8,
                    horizontalPadding: 9,
                    arrowSize: 34
                )
            }

            if let selectedDateText {
                HStack(spacing: 8) {
                    Label(
                        L10n.format("%@만 보기", selectedDateText),
                        systemImage: "line.3.horizontal.decrease.circle.fill"
                    )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                    Spacer()
                    Button("전체 보기", action: onClearDate)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func controlsRow(
        buttonFont: Font,
        verticalPadding: CGFloat,
        horizontalPadding: CGFloat,
        arrowSize: CGFloat
    ) -> some View {
        HStack(spacing: 7) {
            navigationArrowButton(
                systemImage: "chevron.left",
                isEnabled: !isLoading,
                action: onPreviousMonth,
                size: arrowSize
            )

            if !isViewingCurrentMonth {
                capsuleButton(
                    title: L10n.tr("이번 달"),
                    systemImage: nil,
                    font: buttonFont,
                    verticalPadding: verticalPadding,
                    horizontalPadding: horizontalPadding,
                    foreground: .white,
                    action: onJumpToCurrentMonth
                )
                .accessibilityHint(Text(L10n.tr("이번 달로 이동")))
            }

            capsuleButton(
                title: L10n.tr("달력"),
                systemImage: "calendar",
                font: buttonFont,
                verticalPadding: verticalPadding,
                horizontalPadding: horizontalPadding,
                foreground: .white,
                action: onOpenCalendar
            )

            personalRecordsButton(
                font: buttonFont,
                verticalPadding: verticalPadding,
                horizontalPadding: horizontalPadding
            )

            navigationArrowButton(
                systemImage: "chevron.right",
                isEnabled: canMoveNext && !isLoading,
                action: onNextMonth,
                size: arrowSize
            )
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func capsuleButton(
        title: String,
        systemImage: String?,
        font: Font,
        verticalPadding: CGFloat,
        horizontalPadding: CGFloat,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(font)
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private func personalRecordsButton(
        font: Font,
        verticalPadding: CGFloat,
        horizontalPadding: CGFloat
    ) -> some View {
        Button(action: onOpenPersonalRecords) {
            HStack(spacing: 5) {
                Image(systemName: "flag.checkered")
                    .font(.caption.weight(.bold))
                Text(L10n.tr("최고 기록"))
                    .lineLimit(1)
            }
            .font(font)
            .foregroundStyle(pendingRecordCount > 0 ? Color(red: 0.29, green: 0.88, blue: 0.63) : .white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(alignment: .topTrailing) {
                if pendingRecordCount > 0 {
                    if pendingRecordCount <= 9 {
                        Text("\(pendingRecordCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Color(red: 0.29, green: 0.88, blue: 0.63)))
                            .offset(x: 5, y: -5)
                    } else {
                        Circle()
                            .fill(Color(red: 0.29, green: 0.88, blue: 0.63))
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -4)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.tr("최고 기록 열기")))
        .accessibilityHint(Text(L10n.tr("최고 기록과 검토 대기 기록을 확인합니다.")))
    }

    private func navigationArrowButton(
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void,
        size: CGFloat
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(isEnabled ? .white : .white.opacity(0.3))
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// 선택한 달의 거리/빈도/시간을 한눈에 보여주는 요약 카드다.
private struct RecordMonthSummaryCard: View {
    let summary: RecordMonthSummary

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 12) {
                CompactMetricChip(
                    title: "이번 달 거리",
                    value: formatKilometers(summary.totalDistanceKilometers),
                    detail: L10n.format("%d회 러닝", summary.runCount)
                )
                CompactMetricChip(
                    title: "러닝 빈도",
                    value: L10n.format("%d일", summary.runningDays),
                    detail: L10n.format("주 평균 %.1f회", summary.weeklyRunFrequency)
                )
                CompactMetricChip(
                    title: "총 시간",
                    value: formatDuration(summary.totalDuration),
                    detail: "월간 누적 시간"
                )
            }

            VStack(spacing: 10) {
                CompactMetricChip(
                    title: "이번 달 거리",
                    value: formatKilometers(summary.totalDistanceKilometers),
                    detail: L10n.format("%d회 러닝", summary.runCount)
                )
                CompactMetricChip(
                    title: "러닝 빈도",
                    value: L10n.format("%d일", summary.runningDays),
                    detail: L10n.format("주 평균 %.1f회", summary.weeklyRunFrequency)
                )
                CompactMetricChip(
                    title: "총 시간",
                    value: formatDuration(summary.totalDuration),
                    detail: "월간 누적 시간"
                )
            }
        }
    }
}

// 달력 시트는 특정 날짜 러닝만 빠르게 필터링할 때 사용한다.
private struct RecordCalendarSheet: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = Calendar.current.veryShortStandaloneWeekdaySymbols

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ViewThatFits(in: .horizontal) {
                        calendarHeaderRow(
                            monthFont: .title3.weight(.bold),
                            buttonFont: .subheadline.weight(.semibold),
                            verticalPadding: 10
                        )
                        calendarHeaderRow(
                            monthFont: .headline.weight(.bold),
                            buttonFont: .caption.weight(.semibold),
                            verticalPadding: 8
                        )
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(Array(calendarSlots.enumerated()), id: \.offset) { _, date in
                            if let date {
                                RecordCalendarDayCell(
                                    day: Calendar.current.component(.day, from: date),
                                    isSelected: isSelected(date),
                                    isToday: Calendar.current.isDateInToday(date),
                                    runCount: viewModel.runs(on: date).count
                                ) {
                                    viewModel.selectRecordDate(date)
                                    dismiss()
                                }
                            } else {
                                Color.clear
                                    .frame(height: 48)
                            }
                        }
                    }

                    DetailSection(title: "월간 체크") {
                        HStack(spacing: 12) {
                            CompactMetricChip(
                                title: "러닝한 날",
                                value: L10n.format("%d일", viewModel.selectedMonthSummary.runningDays),
                                detail: "뛴 날 / 안 뛴 날 확인"
                            )
                            CompactMetricChip(
                                title: "총 러닝",
                                value: L10n.format("%d회", viewModel.selectedMonthSummary.runCount),
                                detail: "선택 월 기준"
                            )
                        }
                    }
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("러닝 달력")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("전체 보기") {
                        viewModel.clearRecordDateSelection()
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private func calendarHeaderRow(
        monthFont: Font,
        buttonFont: Font,
        verticalPadding: CGFloat
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await viewModel.moveRecordMonth(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, verticalPadding)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoadingMoreHistory)

            Text(viewModel.selectedMonthLabelText)
                .font(monthFont)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityLabel(Text(L10n.format("현재 선택 월: %@", viewModel.selectedMonthLabelText)))

            Spacer(minLength: 8)

            if !viewModel.isViewingCurrentRecordMonth {
                Button(L10n.tr("이번 달")) {
                    Task {
                        await viewModel.jumpToCurrentRecordMonth()
                    }
                }
                .font(buttonFont)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, verticalPadding)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .buttonStyle(.plain)
                .accessibilityHint(Text(L10n.tr("이번 달로 이동")))
            }

            Button {
                Task {
                    await viewModel.moveRecordMonth(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(viewModel.canMoveToNextRecordMonth ? .white : .white.opacity(0.3))
                    .padding(.horizontal, 10)
                    .padding(.vertical, verticalPadding)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canMoveToNextRecordMonth || viewModel.isLoadingMoreHistory)
        }
    }

    private var calendarSlots: [Date?] {
        let calendar = Calendar.current
        let monthStart = viewModel.selectedRecordMonth
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<2
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7

        var slots = Array(repeating: Optional<Date>.none, count: leadingEmptyDays)
        slots.append(contentsOf: dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        })
        return slots
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let selectedRecordDate = viewModel.selectedRecordDate else { return false }
        return Calendar.current.isDate(date, inSameDayAs: selectedRecordDate)
    }
}

// 하루 셀은 러닝 유무와 선택 상태를 함께 표시한다.
private struct RecordCalendarDayCell: View {
    let day: Int
    let isSelected: Bool
    let isToday: Bool
    let runCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(foregroundColor)

                if runCount > 0 {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(red: 0.29, green: 0.88, blue: 0.63))
                            .frame(width: 6, height: 6)
                        if runCount > 1 {
                            Text("\(runCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(borderColor, lineWidth: isToday ? 1 : 0)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        isSelected ? .black : .white
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color(red: 0.29, green: 0.88, blue: 0.63)
        }
        return runCount > 0 ? Color.white.opacity(0.09) : Color.white.opacity(0.04)
    }

    private var borderColor: Color {
        isSelected ? .clear : .white.opacity(0.28)
    }
}

// 간단한 텍스트-값 쌍을 보여주는 범용 컴포넌트다.
// 홈 대시보드 상단의 핵심 요약 카드 묶음을 만든다.
private struct DashboardHeader: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    let summary: RunningSummary
    let runs: [RunningWorkout]
    let vo2MaxSamples: [VO2MaxSample]
    @Binding var showAppleWorkoutOnly: Bool
    let onToggle: () -> Void
    @EnvironmentObject private var mileageGoalStore: MileageGoalStore
    @State private var showingGoalEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardSectionHeader(title: "핵심 요약")

            DashboardQuickOverviewPanel(
                viewModel: viewModel,
                summary: summary,
                runs: runs,
                vo2MaxSamples: vo2MaxSamples
            )

            Button {
                showingGoalEditor = true
            } label: {
                GoalMileageCard(
                    currentDistanceKilometers: summary.monthDistanceKilometers,
                    goalKilometers: mileageGoalStore.monthlyGoalKilometers
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                PredictionTrendView(runs: runs)
            } label: {
                PredictionSummaryCard(
                    predicted5KText: summary.predicted5KText,
                    predicted10KText: summary.predicted10KText,
                    predictedHalfText: summary.predictedHalfText,
                    predictedMarathonText: summary.predictedMarathonText
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                Text("표시")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))

                Toggle(isOn: $showAppleWorkoutOnly) {
                    Text("Apple 운동 앱 기록만 보기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
            }
            .onChange(of: showAppleWorkoutOnly) {
                onToggle()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .sheet(isPresented: $showingGoalEditor) {
            MileageGoalEditorView(currentDistanceKilometers: summary.monthDistanceKilometers)
                .environmentObject(mileageGoalStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}

private struct DashboardSectionHeader: View {
    let title: String

    var body: some View {
        Text(LocalizedStringKey(title))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.62))
            .accessibilityAddTraits(.isHeader)
    }
}

private struct DashboardQuickOverviewPanel: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    let summary: RunningSummary
    let runs: [RunningWorkout]
    let vo2MaxSamples: [VO2MaxSample]

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink {
                MileageBreakdownView(viewModel: viewModel)
            } label: {
                DashboardCompactSummaryLink(
                    title: "거리",
                    value: summary.monthDistanceText,
                    detail: L10n.format("올해 %@", summary.yearDistanceText)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                TrainingTrendView(runs: runs, summary: summary)
            } label: {
                DashboardCompactSummaryLink(
                    title: "추세",
                    value: summary.trainingStatus,
                    detail: summary.trainingStatusDetail
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                VO2MaxTrendView(samples: vo2MaxSamples)
            } label: {
                DashboardCompactSummaryLink(
                    title: "VO2 Max",
                    value: summary.vo2MaxText,
                    detail: summary.vo2MaxDateText
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct DashboardCompactSummaryLink: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(title)))
        .accessibilityValue(Text(value))
        .accessibilityHint(Text(detail))
    }
}

// 공통 요약 카드는 대시보드 전반에서 같은 시각 규칙을 유지한다.
private struct GoalMileageCard: View {
    let currentDistanceKilometers: Double
    let goalKilometers: Double
    @EnvironmentObject private var appSettings: AppSettingsStore

    private var progress: Double {
        guard goalKilometers > 0 else { return 0 }
        return min(currentDistanceKilometers / goalKilometers, 1)
    }

    private var headlineText: String {
        let currentText = RunDisplayFormatter.distance(
            kilometers: currentDistanceKilometers,
            preference: appSettings.distanceUnitPreference,
            fractionLength: 1
        )
        let goalText = RunDisplayFormatter.distance(
            kilometers: goalKilometers,
            preference: appSettings.distanceUnitPreference,
            fractionLength: 0
        )
        return "\(currentText) / \(goalText)"
    }

    private var statusText: String {
        let remaining = goalKilometers - currentDistanceKilometers
        if remaining > 0 {
            let remainingText = RunDisplayFormatter.distance(
                kilometers: remaining,
                preference: appSettings.distanceUnitPreference,
                fractionLength: 1
            )
            return L10n.format("%@ 남음", remainingText)
        }
        if abs(remaining) < 0.05 {
            return L10n.tr("목표 달성")
        }
        let overText = RunDisplayFormatter.distance(
            kilometers: abs(remaining),
            preference: appSettings.distanceUnitPreference,
            fractionLength: 1
        )
        return L10n.format("%@ 초과 달성", overText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("목표 마일리지", systemImage: "target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text("탭해서 수정")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
            }

            Text(headlineText)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: progress)
                .tint(Color(red: 0.29, green: 0.88, blue: 0.63))

            HStack {
                Text(statusText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
                Spacer()
                Text(RunDisplayFormatter.monthOnly(Date()))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

private struct MileageGoalEditorView: View {
    let currentDistanceKilometers: Double
    @EnvironmentObject private var mileageGoalStore: MileageGoalStore
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var draftGoalKilometers: Double = 60
    @State private var didLoadInitialValue = false

    private let presetGoals: [Double] = [40, 60, 80, 100, 150]

    private var displayUnit: DisplayDistanceUnit {
        RunDisplayFormatter.resolvedDistanceUnit(for: appSettings.distanceUnitPreference)
    }

    private var displayedGoalBinding: Binding<Double> {
        Binding(
            get: {
                RunDisplayFormatter.displayedDistanceValue(
                    kilometers: draftGoalKilometers,
                    preference: appSettings.distanceUnitPreference
                )
            },
            set: { newValue in
                draftGoalKilometers = max(
                    RunDisplayFormatter.kilometers(
                        fromDisplayedDistance: newValue,
                        preference: appSettings.distanceUnitPreference
                    ),
                    1
                )
            }
        )
    }

    private var minimumGoalValue: Double {
        RunDisplayFormatter.displayedDistanceValue(
            kilometers: 10,
            preference: appSettings.distanceUnitPreference
        )
    }

    private var maximumGoalValue: Double {
        RunDisplayFormatter.displayedDistanceValue(
            kilometers: 500,
            preference: appSettings.distanceUnitPreference
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ViewThatFits(in: .vertical) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            SummaryCard(
                                title: "이번달 진행",
                                value: formatKilometers(currentDistanceKilometers),
                                detail: "현재 누적 거리"
                            )
                            SummaryCard(
                                title: "설정 목표",
                                value: formatKilometers(draftGoalKilometers),
                                detail: goalStatusText
                            )
                        }

                        VStack(spacing: 12) {
                            SummaryCard(
                                title: "이번달 진행",
                                value: formatKilometers(currentDistanceKilometers),
                                detail: "현재 누적 거리"
                            )
                            SummaryCard(
                                title: "설정 목표",
                                value: formatKilometers(draftGoalKilometers),
                                detail: goalStatusText
                            )
                        }
                    }

                    DetailSection(title: "월간 목표 설정") {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField(
                                L10n.format("월간 목표 거리 (%@)", displayUnit.distanceInputSuffix),
                                value: displayedGoalBinding,
                                format: .number.precision(.fractionLength(0...1))
                            )
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                            Stepper(
                                value: displayedGoalBinding,
                                in: minimumGoalValue...maximumGoalValue,
                                step: 5
                            ) {
                                Text(L10n.format("%d %@ 단위로 조정", 5, displayUnit.distanceInputSuffix))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                            .tint(Color(red: 0.29, green: 0.88, blue: 0.63))

                            Text("빠른 선택")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 10) {
                                ForEach(presetGoals, id: \.self) { goal in
                                    Button {
                                        draftGoalKilometers = goal
                                    } label: {
                                        Text(
                                            RunDisplayFormatter.distance(
                                                kilometers: goal,
                                                preference: appSettings.distanceUnitPreference,
                                                fractionLength: 0
                                            )
                                        )
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(goal == roundedGoal ? Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.22) : Color.white.opacity(0.06))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Text("목표는 현재 달 전체에 공통으로 적용됩니다. 나중에 월별 개별 목표나 연간 목표로 확장할 수 있습니다.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("목표 마일리지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        mileageGoalStore.monthlyGoalKilometers = max(draftGoalKilometers, 1)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            guard !didLoadInitialValue else { return }
            draftGoalKilometers = mileageGoalStore.monthlyGoalKilometers
            didLoadInitialValue = true
        }
    }

    private var roundedGoal: Double {
        draftGoalKilometers.rounded()
    }

    private var goalStatusText: String {
        let remaining = draftGoalKilometers - currentDistanceKilometers
        if remaining > 0 {
            let remainingText = RunDisplayFormatter.distance(
                kilometers: remaining,
                preference: appSettings.distanceUnitPreference,
                fractionLength: 1
            )
            return L10n.format("%@ 남음", remainingText)
        }
        return L10n.tr("이미 달성")
    }
}

// 레이스 거리별 예측 기록을 한 카드 안에 묶는다.
private struct PredictionSummaryCard: View {
    let predicted5KText: String
    let predicted10KText: String
    let predictedHalfText: String
    let predictedMarathonText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("예상 기록")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PredictionCell(title: "5K", value: predicted5KText)
                PredictionCell(title: "10K", value: predicted10KText)
                PredictionCell(title: PredictionDistance.half.label, value: predictedHalfText)
                PredictionCell(title: PredictionDistance.marathon.label, value: predictedMarathonText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// 예측 기록 카드의 개별 셀이다.
private struct PredictionCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

// PR 카드에는 현재 기록과 검토 대기 상태를 함께 보여준다.
private struct PersonalRecordsCard: View {
    let records: [PersonalRecordEntry]
    let pendingCandidates: [PersonalRecordCandidate]
    let isRefreshing: Bool
    let progress: Double?
    let onApproveCandidate: (PersonalRecordDistance) -> Void
    let onDismissCandidate: (PersonalRecordDistance) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("최고 기록")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if !pendingCandidates.isEmpty {
                    NavigationLink {
                        PersonalRecordsManagementView(
                            currentRecords: records,
                            pendingCandidates: pendingCandidates,
                            onApproveCandidate: onApproveCandidate,
                            onDismissCandidate: onDismissCandidate
                        )
                    } label: {
                        Text(L10n.format("검토 %d건", pendingCandidates.count))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(headerStatusText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(headerStatusColor)
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(records) { record in
                    if let workoutID = record.workoutID {
                        NavigationLink {
                            PersonalRecordRunDestinationView(
                                workoutID: workoutID,
                                highlightedDistances: [record.distance]
                            )
                        } label: {
                            PersonalRecordCell(record: record, showsDisclosureIndicator: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        PersonalRecordCell(record: record)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var statusText: String {
        guard isRefreshing else { return L10n.tr("최근 3년 기준") }
        let percent = Int(((progress ?? 0) * 100).rounded())
        return L10n.format("계산 중 %d%%", percent)
    }

    private var headerStatusText: String {
        if !pendingCandidates.isEmpty {
            return L10n.format("검토 %d건", pendingCandidates.count)
        }
        return statusText
    }

    private var headerStatusColor: Color {
        pendingCandidates.isEmpty ? .white.opacity(0.5) : Color(red: 0.29, green: 0.88, blue: 0.63)
    }
}

// PR 거리 한 칸을 렌더링한다.
private struct PersonalRecordCell: View {
    let record: PersonalRecordEntry
    var showsDisclosureIndicator = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(record.distance.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if showsDisclosureIndicator {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            Text(record.valueText)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(record.detailText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

@MainActor
private final class PersonalRecordRunLoaderViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(RunningWorkout)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let workoutID: UUID
    private let healthKitService = HealthKitService()

    init(workoutID: UUID) {
        self.workoutID = workoutID
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        state = .loading

        do {
            if let run = try await healthKitService.fetchRunningWorkout(with: workoutID) {
                state = .loaded(run)
            } else {
                state = .failed("해당 러닝 기록을 찾을 수 없습니다.")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private struct PersonalRecordRunDestinationView: View {
    let workoutID: UUID
    let highlightedDistances: [PersonalRecordDistance]
    @StateObject private var viewModel: PersonalRecordRunLoaderViewModel

    init(workoutID: UUID, highlightedDistances: [PersonalRecordDistance]) {
        self.workoutID = workoutID
        self.highlightedDistances = highlightedDistances
        _viewModel = StateObject(wrappedValue: PersonalRecordRunLoaderViewModel(workoutID: workoutID))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ZStack {
                    AppBackground()
                    ProgressView("러닝 기록을 불러오는 중")
                        .tint(.white)
                        .foregroundStyle(.white)
                }

            case .failed(let message):
                ZStack {
                    AppBackground()
                    StatusView(
                        title: "러닝 기록을 찾을 수 없습니다",
                        message: message,
                        buttonTitle: "다시 시도"
                    ) {
                        Task {
                            await viewModel.load()
                        }
                    }
                }

            case .loaded(let run):
                RunDetailView(
                    run: run,
                    personalRecordAchievements: highlightedDistances
                )
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}

// PR 후보를 승인/유지하는 검토 전용 화면이다.
private struct PersonalRecordsManagementView: View {
    let currentRecords: [PersonalRecordEntry]
    let pendingCandidates: [PersonalRecordCandidate]
    let onApproveCandidate: (PersonalRecordDistance) -> Void
    let onDismissCandidate: (PersonalRecordDistance) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var currentRecordMap: [PersonalRecordDistance: PersonalRecordEntry] {
        Dictionary(uniqueKeysWithValues: currentRecords.map { ($0.distance, $0) })
    }

    private var orderedCurrentRecords: [PersonalRecordEntry] {
        currentRecords.sorted { $0.distance.meters < $1.distance.meters }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "현재 최고 기록") {
                    VStack(alignment: .leading, spacing: 12) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(orderedCurrentRecords) { record in
                                if let workoutID = record.workoutID {
                                    NavigationLink {
                                        PersonalRecordRunDestinationView(
                                            workoutID: workoutID,
                                            highlightedDistances: [record.distance]
                                        )
                                    } label: {
                                        PersonalRecordCell(record: record, showsDisclosureIndicator: true)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    PersonalRecordCell(record: record)
                                }
                            }
                        }

                        Text("카드를 누르면 해당 러닝 상세를 열 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                if !pendingCandidates.isEmpty {
                    DetailSection(title: "검토 대기") {
                        VStack(spacing: 12) {
                            ForEach(pendingCandidates) { candidate in
                                PersonalRecordCandidateRow(
                                    currentRecord: currentRecordMap[candidate.distance],
                                    candidate: candidate,
                                    onApprove: { onApproveCandidate(candidate.distance) },
                                    onDismiss: { onDismissCandidate(candidate.distance) }
                                )
                            }
                        }
                    }
                } else {
                    DetailSection(title: "검토 대기 없음") {
                        Text("최근 3년보다 오래된 더 빠른 후보 기록이 없습니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("최고 기록")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 후보 기록과 현재 기록을 나란히 비교할 수 있게 만든다.
private struct PersonalRecordCandidateRow: View {
    let currentRecord: PersonalRecordEntry?
    let candidate: PersonalRecordCandidate
    let onApprove: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.distance.label)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("오래된 기록 후보")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Text(candidate.valueText)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                CompactMetricChip(
                    title: "현재 PR",
                    value: currentRecord?.valueText ?? "-",
                    detail: currentRecord?.detailText ?? "기록 없음"
                )
                CompactMetricChip(
                    title: "후보 기록",
                    value: candidate.valueText,
                    detail: candidate.detailText
                )
            }

            HStack(spacing: 10) {
                Button("현재 PR 유지", action: onDismiss)
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.8))
                Button("이 기록으로 교체", action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

// VO2 Max 추세는 기간별 변화와 최고치를 함께 보여준다.
private struct VO2MaxTrendView: View {
    let samples: [VO2MaxSample]
    @State private var selectedRange: VO2TrendRange = .oneYear

    private var filteredSamples: [VO2MaxSample] {
        selectedRange.filtered(samples)
    }

    private var latest: VO2MaxSample? { filteredSamples.last }
    private var best: VO2MaxSample? { filteredSamples.max(by: { $0.value < $1.value }) }
    private var changeText: String {
        guard let first = filteredSamples.first, let latest else { return "-" }
        return String(format: "%+.1f", latest.value - first.value)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("기간", selection: $selectedRange) {
                    ForEach(VO2TrendRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SummaryCard(title: "현재", value: latest.map { String(format: "%.1f", $0.value) } ?? "-", detail: latest.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? "데이터 없음")
                    SummaryCard(title: "최고", value: best.map { String(format: "%.1f", $0.value) } ?? "-", detail: best.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? "데이터 없음")
                    SummaryCard(title: "변화", value: changeText, detail: L10n.format("%@ 기준", selectedRange.label))
                }

                DetailSection(title: "VO2 Max 추세") {
                    if filteredSamples.isEmpty {
                        Text("VO2 Max 데이터가 없습니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        Chart(filteredSamples.indices, id: \.self) { index in
                            let sample = filteredSamples[index]
                            LineMark(
                                x: .value("날짜", sample.date),
                                y: .value("VO2 Max", sample.value)
                            )
                            .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("날짜", sample.date),
                                y: .value("VO2 Max", sample.value)
                            )
                            .foregroundStyle(Color.white)
                            .symbolSize(index == filteredSamples.count - 1 ? 46 : 18)
                        }
                        .frame(height: 220)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine().foregroundStyle(.white.opacity(0.12))
                                AxisValueLabel {
                                    if let number = value.as(Double.self) {
                                        Text(String(format: "%.1f", number))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) { _ in
                                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("VO2 Max")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// VO2 Max 차트에서 사용할 기간 필터다.
private enum VO2TrendRange: String, CaseIterable, Identifiable {
    case sixMonths
    case oneYear
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sixMonths: return L10n.tr("6개월")
        case .oneYear: return L10n.tr("1년")
        case .all: return L10n.tr("전체")
        }
    }

    func filtered(_ samples: [VO2MaxSample]) -> [VO2MaxSample] {
        guard self != .all else { return samples }

        let days = self == .sixMonths ? -180 : -365
        let startDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? .distantPast
        return samples.filter { $0.date >= startDate }
    }
}

private struct TrainingTrendView: View {
    let runs: [RunningWorkout]
    let summary: RunningSummary
    @State private var selectedWeekDate: Date?

    private var points: [TrainingTrendPoint] {
        TrainingTrendPoint.build(from: runs, weeks: 5)
    }

    private var latestPoint: TrainingTrendPoint? { points.last }
    private var previousPoint: TrainingTrendPoint? {
        guard points.count >= 2 else { return nil }
        return points[points.count - 2]
    }

    private var changeText: String {
        guard let latestPoint, let previousPoint else { return "-" }
        let delta = latestPoint.distanceKilometers - previousPoint.distanceKilometers
        let sign = delta > 0 ? "+" : delta < 0 ? "-" : ""
        let distanceText = RunDisplayFormatter.distance(kilometers: abs(delta), fractionLength: 1)
        return sign + distanceText
    }

    private var selectedPoint: TrainingTrendPoint? {
        guard let selectedWeekDate else { return nil }
        return points.min {
            abs($0.startDate.timeIntervalSince(selectedWeekDate)) < abs($1.startDate.timeIntervalSince(selectedWeekDate))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SummaryCard(title: "현재 상태", value: summary.trainingStatus, detail: summary.trainingStatusDetail)
                    SummaryCard(
                        title: "이번 주 거리",
                        value: latestPoint.map { formatKilometers($0.distanceKilometers) } ?? "-",
                        detail: latestPoint.map(\.label) ?? "데이터 없음"
                    )
                    SummaryCard(
                        title: "직전 주 거리",
                        value: previousPoint.map { formatKilometers($0.distanceKilometers) } ?? "-",
                        detail: previousPoint.map(\.label) ?? "데이터 없음"
                    )
                    SummaryCard(title: "주간 변화", value: changeText, detail: "이번 주 vs 직전 주")
                }

                DetailSection(title: "주간 훈련량") {
                    if points.isEmpty {
                        Text("훈련 추세를 계산할 러닝 데이터가 부족합니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Chart(points) { point in
                                BarMark(
                                    x: .value("주간", point.startDate),
                                    y: .value("거리", point.distanceKilometers),
                                    width: .fixed(20)
                                )
                                .foregroundStyle(
                                    (selectedPoint?.id == point.id ? Color.white : Color(red: 0.29, green: 0.88, blue: 0.63))
                                        .opacity(selectedPoint == nil || selectedPoint?.id == point.id ? 1 : 0.42)
                                )
                                .cornerRadius(6)
                                .annotation(position: .top, spacing: 8) {
                                    if selectedPoint?.id == point.id {
                                        Text(point.distanceText)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(Color.black.opacity(0.28))
                                            )
                                    }
                                }
                            }
                            .frame(height: 220)
                            .chartXSelection(value: $selectedWeekDate)
                            .chartYAxis {
                                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                        .foregroundStyle(.white.opacity(0.08))
                                    AxisValueLabel {
                                        if let distance = value.as(Double.self) {
                                            Text(RunDisplayFormatter.distance(kilometers: distance, fractionLength: 0))
                                                .foregroundStyle(.white.opacity(0.45))
                                        }
                                    }
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartPlotStyle { plotArea in
                                plotArea.background(.clear)
                            }

                            TrainingTrendAxisRow(
                                points: points,
                                selectedPointID: selectedPoint?.id
                            )
                            .padding(.leading, 46)
                            .padding(.trailing, 6)
                        }
                    }
                }

                DetailSection(title: "계산 방식") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("훈련 추세는 최근 7일 러닝 거리와 직전 7일 러닝 거리를 비교해 계산합니다.")
                        Text("아래 주간 그래프는 최근 5주를 달력 기준 주차별로 보여줍니다.")
                        Text("최근 7일 거리가 직전 7일보다 20% 이상 많으면 `빌드업`으로 표시합니다.")
                        Text("최근 7일에 러닝이 있고 20% 이상 차이가 나지 않으면 `유지`로 표시합니다.")
                        Text("최근 7일 러닝이 거의 없으면 `회복`으로 표시합니다.")
                        Text("지금은 거리 기반의 간단한 추세 지표라 강도, 심박, 파워는 반영하지 않습니다.")
                    }
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.82))
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("훈련 추세")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TrainingTrendAxisRow: View {
    let points: [TrainingTrendPoint]
    let selectedPointID: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(points) { point in
                Text(point.axisLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(point.id == selectedPointID ? .white : .white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct TrainingTrendPoint: Identifiable {
    let id: Date
    let startDate: Date
    let endDate: Date
    let distanceKilometers: Double

    var distanceText: String {
        RunDisplayFormatter.distance(kilometers: distanceKilometers, fractionLength: 1)
    }

    var label: String {
        "\(monthText) \(weekText)"
    }

    var axisLabel: String {
        label
    }

    var dateRangeText: String {
        let rangeEndDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        return "\(formattedMonthDay(startDate)) - \(formattedMonthDay(rangeEndDate))"
    }

    private var monthText: String {
        RunDisplayFormatter.monthOnly(startDate)
    }

    private var weekText: String {
        L10n.format("%d주차", Calendar.current.component(.weekOfMonth, from: startDate))
    }

    private func formattedMonthDay(_ date: Date) -> String {
        RunDisplayFormatter.shortMonthDay(date)
    }

    static func build(from runs: [RunningWorkout], weeks: Int = 8) -> [TrainingTrendPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today),
            let firstWeekStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeek.start)
        else {
            return []
        }

        return (0..<weeks).compactMap { offset in
            guard
                let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: firstWeekStart),
                let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart)
            else {
                return nil
            }

            let distanceKilometers = runs
                .filter { $0.startDate >= weekInterval.start && $0.startDate < weekInterval.end }
                .reduce(0) { $0 + $1.distanceInKilometers }

            return TrainingTrendPoint(
                id: weekInterval.start,
                startDate: weekInterval.start,
                endDate: weekInterval.end,
                distanceKilometers: distanceKilometers
            )
        }
    }
}

// 예상 기록 추세 화면은 거리별 최근 러닝 폼을 요약한다.
private struct PredictionTrendView: View {
    let runs: [RunningWorkout]
    @State private var selectedDistance: PredictionDistance = .fiveK
    @State private var showingMethod = false

    private var points: [PredictionTrendPoint] {
        PredictionTrendPoint.build(for: selectedDistance, runs: runs)
    }

    private var latestPoint: PredictionTrendPoint? { points.last }
    private var bestPoint: PredictionTrendPoint? { points.min(by: { $0.seconds < $1.seconds }) }
    private var deltaText: String {
        guard let first = points.first, let latestPoint else { return "-" }
        return formatSignedDuration(latestPoint.seconds - first.seconds)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("거리", selection: $selectedDistance) {
                    ForEach(PredictionDistance.allCases) { distance in
                        Text(distance.label).tag(distance)
                    }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SummaryCard(title: "현재 예상", value: latestPoint.map { formatDuration($0.seconds) } ?? "-", detail: selectedDistance.label)
                    SummaryCard(title: "최고 예상", value: bestPoint.map { formatDuration($0.seconds) } ?? "-", detail: bestPoint.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? "데이터 없음")
                    SummaryCard(title: "변화", value: deltaText, detail: "첫 포인트 대비")
                }

                DetailSection(title: "예상 기록 추세") {
                    if points.isEmpty {
                        Text("추세를 계산할 러닝 데이터가 부족합니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        Chart(points) { point in
                            LineMark(
                                x: .value("날짜", point.date),
                                y: .value("예상 기록", point.seconds)
                            )
                            .foregroundStyle(Color(red: 0.46, green: 0.66, blue: 0.98))
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("날짜", point.date),
                                y: .value("예상 기록", point.seconds)
                            )
                            .foregroundStyle(Color.white.opacity(0.9))
                            .symbolSize(point.id == latestPoint?.id ? 46 : 18)
                        }
                        .frame(height: 220)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine().foregroundStyle(.white.opacity(0.12))
                                AxisValueLabel {
                                    if let seconds = value.as(Double.self) {
                                        Text(formatDuration(seconds))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) { _ in
                                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                        }
                    }
                }

                Button {
                    showingMethod = true
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("예측 기록 계산 방식 보기")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("예상 기록")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMethod) {
            PredictionMethodView()
        }
    }
}

// 5K/10K/하프/풀 거리 필터를 정의한다.
private enum PredictionDistance: String, CaseIterable, Identifiable {
    case fiveK
    case tenK
    case half
    case marathon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fiveK: return "5K"
        case .tenK: return "10K"
        case .half: return L10n.tr("하프")
        case .marathon: return L10n.tr("풀")
        }
    }

    var targetMeters: Double {
        switch self {
        case .fiveK: return 5_000
        case .tenK: return 10_000
        case .half: return 21_097.5
        case .marathon: return 42_195
        }
    }
}

// 예측 추세 차트에서 한 점은 특정 날짜의 최적 예측값을 뜻한다.
private struct PredictionTrendPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let seconds: Double

    static func build(for distance: PredictionDistance, runs: [RunningWorkout]) -> [PredictionTrendPoint] {
        let sortedRuns = runs
            .filter { $0.distanceInMeters >= 1_000 }
            .sorted(by: { $0.startDate < $1.startDate })

        var points: [PredictionTrendPoint] = []
        for run in sortedRuns {
            let windowStart = Calendar.current.date(byAdding: .day, value: -120, to: run.startDate) ?? .distantPast
            let candidates = sortedRuns.filter { $0.startDate >= windowStart && $0.startDate <= run.startDate }
            guard let predictedSeconds = candidates
                .map({ $0.duration * pow(distance.targetMeters / $0.distanceInMeters, 1.06) })
                .min()
            else { continue }

            points.append(PredictionTrendPoint(date: run.startDate, seconds: predictedSeconds))
        }
        return points
    }
}

// 신발 탭은 등록된 러닝화와 누적 사용량을 관리한다.
struct ShoesTabView: View {
    let runs: [RunningWorkout]
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingAddShoe = false

    private var samplePreviewItems: [SampleShoePreview] {
        SampleShoePreview.items
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()

                        Button("추가") {
                            showingAddShoe = true
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                    .padding(.horizontal, 4)

                    if shoeStore.shoes.isEmpty {
                        DetailSection(title: "러닝화 추가하기") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("러닝화를 등록하면 신발별 누적 거리와 남은 수명을 볼 수 있습니다.")
                                    .foregroundStyle(.white.opacity(0.72))
                                Text("아래 샘플 카드에서 어떤 식으로 관리되는지 먼저 볼 수 있습니다.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                        }

                        DetailSection(title: "샘플 미리보기") {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(samplePreviewItems) { item in
                                    ShoeSummaryCard(
                                        shoe: item.shoe,
                                        distanceKilometers: item.distanceKilometers
                                    )
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 14) {
                            ForEach(shoeStore.shoes) { shoe in
                                NavigationLink {
                                    ShoeDetailView(shoe: shoe, runs: runs)
                                } label: {
                                    ShoeSummaryCard(
                                        shoe: shoe,
                                        distanceKilometers: shoeStore.distance(for: shoe.id, runs: runs)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 104)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddShoe) {
                AddShoeView()
                    .environmentObject(shoeStore)
            }
        }
    }
}

// 설정 탭은 실제 설정과 안내성 화면 진입점을 분리해 보여준다.
struct SettingsTabView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DetailSection(title: "표시") {
                        VStack(spacing: 14) {
                            NavigationLink {
                                AppLanguageSettingsView()
                            } label: {
                                SettingSelectionRow(
                                    title: "앱 언어",
                                    value: appSettings.appLanguagePreference.label,
                                    detail: "앱 화면 문구와 날짜 표시에 적용됩니다."
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                DistanceUnitSettingsView()
                            } label: {
                                SettingSelectionRow(
                                    title: "거리 단위",
                                    value: appSettings.distanceUnitPreference.label,
                                    detail: "거리, 페이스, 상승 고도, 공유 이미지에 함께 적용됩니다."
                                )
                            }
                            .buttonStyle(.plain)

                            Toggle(isOn: $appSettings.defaultAppleOnlyFilter) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Apple 운동 앱 기록 기본 표시")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("앱을 열었을 때 홈/기록 탭에서 기본으로 적용됩니다.")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.58))
                                }
                            }
                            .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
                        }
                    }

                    DetailSection(title: "정책 및 지원") {
                        VStack(spacing: 12) {
                            NavigationLink {
                                DataPermissionsView()
                            } label: {
                                SettingLinkRow(
                                    systemImage: "heart.text.square",
                                    title: "데이터 및 권한",
                                    detail: "HealthKit 권한과 저장 방식을 확인합니다."
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                PrivacyPolicyView()
                            } label: {
                                SettingLinkRow(
                                    systemImage: "lock.doc.fill",
                                    title: "개인정보처리방침",
                                    detail: "앱이 읽는 데이터와 저장 방식을 확인합니다."
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                SupportCenterView()
                            } label: {
                                SettingLinkRow(
                                    systemImage: "envelope.fill",
                                    title: "지원 및 문의",
                                    detail: "문의 메일과 저장소 링크를 확인합니다."
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    DetailSection(title: "데이터") {
                        VStack(spacing: 12) {
                            NavigationLink {
                                ShoeDataSettingsView()
                            } label: {
                                SettingLinkRow(
                                    systemImage: "shoeprints.fill",
                                    title: "신발 데이터",
                                    detail: "백업 파일을 준비하거나 가져옵니다."
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                DataManagementView()
                            } label: {
                                SettingLinkRow(
                                    systemImage: "externaldrive.fill.badge.xmark",
                                    title: "데이터 관리",
                                    detail: "신발 데이터 삭제와 분석 캐시 초기화를 관리합니다."
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    DetailSection(title: "고지") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(AppMetadata.nonMedicalNoticeLines, id: \.self) { item in
                                Text(item)
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.66))
                    }

                    DetailSection(title: "앱 정보") {
                        VStack(spacing: 14) {
                            SettingInfoRow(title: "앱 이름", value: AppMetadata.displayName)
                            SettingInfoRow(title: "버전", value: AppMetadata.versionText)
                            SettingInfoRow(title: "지원 메일", value: AppMetadata.supportEmail)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 104)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// 개인정보처리방침은 앱 안에서도 바로 읽을 수 있게 별도 화면으로 제공한다.
private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "개요") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.format("%@은 Apple 건강의 러닝 데이터를 iPhone에서 보기 쉽게 정리하는 앱입니다.", AppMetadata.displayName))
                        Text(AppMetadata.healthUsageSummary)
                        Text("계정 생성, 광고 추적, 외부 분석 SDK 없이 동작하며, 현재는 서버로 데이터를 업로드하지 않습니다.")
                        Text(L10n.format("HealthKit 권한은 언제든 %@에서 다시 변경할 수 있습니다.", AppMetadata.healthPermissionSettingsPath))
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "읽는 건강 데이터") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(AppMetadata.healthDataSummaryItems, id: \.self) { item in
                            Text("• \(item)")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "저장 및 보호") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AppMetadata.privacyStorageHighlights, id: \.self) { item in
                            Text(item)
                        }
                        Text("신발 데이터, 설정값, PR 계산 결과와 평균 심박/평균 케이던스/상승 고도 같은 보조 분석 데이터는 기기 내부 저장소에만 저장됩니다.")
                        Text("신발 백업 파일은 사용자가 직접 공유 버튼을 눌렀을 때만 외부 앱으로 전달됩니다.")
                        Text("앱을 삭제하면 앱 내부에 저장한 보조 데이터와 설정도 함께 제거됩니다.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "고지") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AppMetadata.nonMedicalNoticeLines, id: \.self) { item in
                            Text(item)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "문의") {
                    VStack(alignment: .leading, spacing: 12) {
                        Link("지원 메일 보내기", destination: AppMetadata.supportMailURL)
                            .font(.subheadline.weight(.semibold))
                        Link("웹 개인정보처리방침 열기", destination: AppMetadata.privacyPolicyURL)
                            .font(.subheadline.weight(.semibold))
                        Link("프로젝트 저장소 열기", destination: AppMetadata.repositoryURL)
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("개인정보처리방침")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 지원 화면은 문의 방법과 전달하면 좋은 정보를 함께 안내한다.
private struct SupportCenterView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "문의 방법") {
                    VStack(alignment: .leading, spacing: 12) {
                        Link("메일로 문의하기", destination: AppMetadata.supportMailURL)
                            .font(.subheadline.weight(.semibold))
                        Link("웹 개인정보처리방침 열기", destination: AppMetadata.privacyPolicyURL)
                            .font(.subheadline.weight(.semibold))
                        Link("앱 리뷰 노트 초안 열기", destination: AppMetadata.reviewNotesURL)
                            .font(.subheadline.weight(.semibold))
                        Link("프로젝트 저장소 열기", destination: AppMetadata.repositoryURL)
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
                }

                DetailSection(title: "함께 보내주면 좋은 정보") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("• 사용 중인 iPhone 모델과 iOS 버전")
                        Text("• 문제가 발생한 러닝 날짜와 화면")
                        Text("• 재현 순서와 스크린샷")
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("지원 및 문의")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DataPermissionsView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "데이터 및 권한") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppMetadata.healthUsageSummary)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.78))

                        SettingInfoRow(title: "권한", value: "HealthKit 읽기")
                        SettingInfoRow(title: "네트워크 업로드", value: "없음")
                        SettingInfoRow(title: "파생 분석 캐시", value: "기기 내부 전용 저장소")
                        SettingInfoRow(title: "권한 변경", value: AppMetadata.healthPermissionSettingsPath)
                        SettingInfoRow(title: "앱 삭제 시", value: "로컬 보조 데이터 함께 제거")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("읽는 데이터")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                            ForEach(AppMetadata.healthDataSummaryItems, id: \.self) { item in
                                Text("• \(item)")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        }

                        Text("이 앱은 Apple 건강 데이터 중 러닝과 관련된 항목만 읽습니다. 평균 심박, 평균 케이던스, 상승 고도 같은 요약값은 상세 화면을 더 빠르게 보여주기 위해 기기 내부에만 저장하며 서버로 업로드하지 않습니다.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.62))

                        Button {
                            appSettings.presentHealthKitIntro()
                        } label: {
                            HStack {
                                Image(systemName: "heart.text.square")
                                Text("HealthKit 안내 다시 보기")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                DetailSection(title: "고지") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(AppMetadata.nonMedicalNoticeLines, id: \.self) { item in
                            Text(item)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.66))
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("데이터 및 권한")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShoeDataSettingsView: View {
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var backupURL: URL?
    @State private var backupErrorMessage: String?
    @State private var backupStatusMessage: String?
    @State private var showingImportOptions = false
    @State private var showingBackupImporter = false
    @State private var selectedImportStrategy: ShoeImportStrategy = .merge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "신발 백업 및 복원") {
                    VStack(spacing: 14) {
                        SettingInfoRow(title: "저장 위치", value: "iPhone 내부 전용 저장소")
                        SettingInfoRow(title: "자동 백업", value: "자동 iCloud/Finder 백업 제외")
                        SettingInfoRow(title: "기기 간 자동 동기화", value: "현재 지원 안 함")
                        SettingInfoRow(title: "백업 포함 범위", value: "신발 정보 + 러닝 UUID 연결")

                        Text("백업 파일에는 신발 이름, 브랜드/모델, 시작 거리, 목표 수명, 생성일과 러닝 UUID 연결만 들어갑니다. 심박, 경로, 페이스 같은 HealthKit 원본 데이터는 포함되지 않습니다. 러닝 연결은 같은 HealthKit workout UUID가 있는 기기에서 가장 잘 복원됩니다.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.62))

                        Button {
                            do {
                                backupURL = try shoeStore.exportBackupFile()
                                backupErrorMessage = nil
                                backupStatusMessage = L10n.tr("백업 파일을 준비했습니다.")
                            } catch {
                                backupErrorMessage = error.localizedDescription
                            }
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("신발 데이터 백업 파일 준비")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingImportOptions = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("신발 데이터 가져오기")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)

                        if let backupURL {
                            ShareLink(item: backupURL) {
                                HStack {
                                    Image(systemName: "paperplane")
                                    Text("백업 파일 공유")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        }

                        if let backupStatusMessage {
                            Text(backupStatusMessage)
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                        }

                        if let backupErrorMessage {
                            Text(backupErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("신발 데이터")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("가져오기 방식", isPresented: $showingImportOptions, titleVisibility: .visible) {
            Button("병합 가져오기") {
                selectedImportStrategy = .merge
                showingBackupImporter = true
            }
            Button("기존 데이터로 교체", role: .destructive) {
                selectedImportStrategy = .replace
                showingBackupImporter = true
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("병합은 같은 ID만 갱신하고 나머지는 유지합니다. 교체는 현재 신발 데이터와 연결 정보를 백업 파일 내용으로 바꿉니다.")
        }
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let summary = try shoeStore.importBackupFile(from: url, strategy: selectedImportStrategy)
                backupErrorMessage = nil
                backupStatusMessage = summary.message
                backupURL = nil
            } catch {
                backupErrorMessage = error.localizedDescription
            }
        }
    }
}

private struct DataManagementView: View {
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingDeleteShoeDataConfirmation = false
    @State private var showingDeleteAnalysisCacheConfirmation = false
    @State private var analysisCacheStatusMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "데이터 관리") {
                    VStack(spacing: 14) {
                        Button(role: .destructive) {
                            showingDeleteShoeDataConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("기존 신발데이터 삭제")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.red.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            showingDeleteAnalysisCacheConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("분석 캐시 초기화")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.red.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)

                        if let statusMessage {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                        }

                        if let analysisCacheStatusMessage {
                            Text(analysisCacheStatusMessage)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("데이터 관리")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("기존 신발데이터 삭제", isPresented: $showingDeleteShoeDataConfirmation, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                shoeStore.clearAllData()
                statusMessage = L10n.tr("기존 신발데이터를 삭제했습니다.")
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("등록한 신발 정보와 러닝 연결 정보가 모두 삭제됩니다. HealthKit 원본 러닝 데이터는 삭제되지 않습니다.")
        }
        .confirmationDialog("분석 캐시 초기화", isPresented: $showingDeleteAnalysisCacheConfirmation, titleVisibility: .visible) {
            Button("초기화", role: .destructive) {
                RunSummaryCacheStore.shared.clearAllData()
                analysisCacheStatusMessage = L10n.tr("평균 심박, 케이던스, 상승 고도 캐시를 삭제했습니다.")
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("상세 화면을 빠르게 보여주기 위해 저장한 파생 요약값만 삭제합니다. HealthKit 원본 러닝 데이터와 신발 데이터는 그대로 유지됩니다.")
        }
    }
}

// 설정 화면의 링크 행은 텍스트와 방향 표시를 함께 그린다.
private struct SettingLinkRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(LocalizedStringKey(detail))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.38))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SettingSelectionRow: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 12)

                Text(LocalizedStringKey(value))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.38))
            }

            Text(LocalizedStringKey(detail))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// 설정 정보의 제목/값 행은 긴 값도 줄바꿈해서 표시할 수 있게 만든다.
private struct SettingInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(LocalizedStringKey(value))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text(LocalizedStringKey(value))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SettingOptionRow: View {
    let title: String
    let detail: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(LocalizedStringKey(detail))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.headline)
                .foregroundStyle(isSelected ? Color(red: 0.29, green: 0.88, blue: 0.63) : .white.opacity(0.22))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct AppLanguageSettingsView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore

    private func detail(for option: AppLanguagePreference) -> String {
        switch option {
        case .korean:
            return "앱 화면 문구와 날짜를 한국어 기준으로 표시합니다."
        case .english:
            return "앱 화면 문구와 날짜를 영어 기준으로 표시합니다."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "앱 언어") {
                    VStack(spacing: 12) {
                        ForEach(AppLanguagePreference.allCases) { option in
                            Button {
                                appSettings.appLanguagePreference = option
                            } label: {
                                SettingOptionRow(
                                    title: option.label,
                                    detail: detail(for: option),
                                    isSelected: appSettings.appLanguagePreference == option
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("앱 언어")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DistanceUnitSettingsView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore

    private func detail(for option: DistanceUnitPreference) -> String {
        switch option {
        case .system:
            return "기기 설정에 맞춰 km 또는 mi를 자동으로 사용합니다."
        case .kilometers:
            return "거리와 페이스를 km 기준으로 고정합니다."
        case .miles:
            return "거리와 페이스를 mi 기준으로 고정합니다."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "거리 단위") {
                    VStack(spacing: 12) {
                        ForEach(DistanceUnitPreference.allCases) { option in
                            Button {
                                appSettings.distanceUnitPreference = option
                            } label: {
                                SettingOptionRow(
                                    title: option.label,
                                    detail: detail(for: option),
                                    isSelected: appSettings.distanceUnitPreference == option
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("거리 단위")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SampleShoePreview: Identifiable {
    let id = UUID()
    let shoe: RunningShoe
    let distanceKilometers: Double

    static let items: [SampleShoePreview] = [
        SampleShoePreview(
            shoe: RunningShoe(
                nickname: "데일리 러너",
                brand: "브랜드 A",
                model: "트레이너 01",
                startMileageKilometers: 552.0,
                retirementKilometers: 600
            ),
            distanceKilometers: 7.6
        ),
        SampleShoePreview(
            shoe: RunningShoe(
                nickname: "스피드 페어",
                brand: "브랜드 B",
                model: "레이서 02",
                startMileageKilometers: 220.0,
                retirementKilometers: 600
            ),
            distanceKilometers: 35.8
        )
    ]
}

// 신발 목록 카드 하나는 누적 거리와 교체까지 남은 거리를 요약한다.
private struct ShoeSummaryCard: View {
    let shoe: RunningShoe
    let distanceKilometers: Double

    private var totalKilometers: Double {
        shoe.startMileageKilometers + distanceKilometers
    }

    private var usageRatio: Double {
        min(totalKilometers / max(shoe.retirementKilometers, 1), 1)
    }

    private var usagePercentText: String {
        "\(Int((usageRatio * 100).rounded()))%"
    }

    private var usageColor: Color {
        usageRatio >= 0.85 ? .orange : Color(red: 0.29, green: 0.88, blue: 0.63)
    }

    private var distanceSummaryText: String {
        L10n.format(
            "누적 %@ / 총 %@",
            formatKilometers(totalKilometers),
            formatKilometers(shoe.retirementKilometers)
        )
    }

    private var compactMetricsText: String {
        L10n.format(
            "누적 %@ · 총 %@ · 사용률 %@",
            formatKilometers(totalKilometers),
            formatKilometers(shoe.retirementKilometers),
            usagePercentText
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.32),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "shoeprints.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(shoe.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(distanceSummaryText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                Text(usagePercentText)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(usageColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.38))
        }
        .frame(minHeight: 74)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
        .accessibilityLabel(Text(shoe.displayName))
        .accessibilityValue(Text(compactMetricsText))
        .accessibilityHint(Text("탭하면 신발 상세 정보를 볼 수 있습니다."))
    }
}

// 신발 상세 화면은 연결된 러닝 목록과 현재 사용량을 보여준다.
private struct ShoeDetailView: View {
    let shoe: RunningShoe
    let runs: [RunningWorkout]
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingEditSheet = false

    private var currentShoe: RunningShoe {
        shoeStore.shoes.first(where: { $0.id == shoe.id }) ?? shoe
    }

    private var assignedRuns: [RunningWorkout] {
        shoeStore.runs(for: currentShoe.id, in: runs)
    }

    private var totalKilometers: Double {
        currentShoe.startMileageKilometers + assignedRuns.reduce(0) { $0 + $1.distanceInKilometers }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ViewThatFits(in: .vertical) {
                    HStack(spacing: 12) {
                        SummaryCard(title: "누적 거리", value: formatKilometers(totalKilometers), detail: "시작 거리 포함")
                        SummaryCard(title: "목표 수명", value: formatKilometers(currentShoe.retirementKilometers), detail: currentShoe.brandModelText)
                    }

                    VStack(spacing: 12) {
                        SummaryCard(title: "누적 거리", value: formatKilometers(totalKilometers), detail: "시작 거리 포함")
                        SummaryCard(title: "목표 수명", value: formatKilometers(currentShoe.retirementKilometers), detail: currentShoe.brandModelText)
                    }
                }

                ViewThatFits(in: .vertical) {
                    HStack(spacing: 12) {
                        SummaryCard(title: "남은 거리", value: formatKilometers(max(currentShoe.retirementKilometers - totalKilometers, 0)), detail: "교체까지 남은 거리")
                        SummaryCard(title: "착용 러닝", value: L10n.format("%d회", assignedRuns.count), detail: "현재 불러온 러닝 기준")
                    }

                    VStack(spacing: 12) {
                        SummaryCard(title: "남은 거리", value: formatKilometers(max(currentShoe.retirementKilometers - totalKilometers, 0)), detail: "교체까지 남은 거리")
                        SummaryCard(title: "착용 러닝", value: L10n.format("%d회", assignedRuns.count), detail: "현재 불러온 러닝 기준")
                    }
                }

                DetailSection(title: "최근 착용 러닝") {
                    if assignedRuns.isEmpty {
                        Text("이 신발에 연결된 러닝이 없습니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(assignedRuns.prefix(10)) { run in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(run.titleText)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text(run.distanceText)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.55))
                                    }
                                    Spacer()
                                    Text(run.paceText)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle(currentShoe.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("수정") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddShoeView(existingShoe: currentShoe)
                .environmentObject(shoeStore)
        }
    }
}

// 신발 추가/수정 폼은 최소 정보만 받아 빠르게 관리할 수 있게 한다.
private struct AddShoeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var shoeStore: ShoeStore
    @EnvironmentObject private var appSettings: AppSettingsStore

    let existingShoe: RunningShoe?

    @State private var nickname: String
    @State private var brand: String
    @State private var model: String
    @State private var startMileage: Double
    @State private var retirementMileage: Double

    init(existingShoe: RunningShoe? = nil) {
        self.existingShoe = existingShoe
        _nickname = State(initialValue: existingShoe?.nickname ?? "")
        _brand = State(initialValue: existingShoe?.brand ?? "")
        _model = State(initialValue: existingShoe?.model ?? "")
        _startMileage = State(initialValue: existingShoe?.startMileageKilometers ?? 0)
        _retirementMileage = State(initialValue: existingShoe?.retirementKilometers ?? 600)
    }

    private var displayUnit: DisplayDistanceUnit {
        RunDisplayFormatter.resolvedDistanceUnit(for: appSettings.distanceUnitPreference)
    }

    private var startMileageBinding: Binding<Double> {
        Binding(
            get: {
                RunDisplayFormatter.displayedDistanceValue(
                    kilometers: startMileage,
                    preference: appSettings.distanceUnitPreference
                )
            },
            set: { newValue in
                startMileage = max(
                    RunDisplayFormatter.kilometers(
                        fromDisplayedDistance: newValue,
                        preference: appSettings.distanceUnitPreference
                    ),
                    0
                )
            }
        )
    }

    private var retirementMileageBinding: Binding<Double> {
        Binding(
            get: {
                RunDisplayFormatter.displayedDistanceValue(
                    kilometers: retirementMileage,
                    preference: appSettings.distanceUnitPreference
                )
            },
            set: { newValue in
                retirementMileage = max(
                    RunDisplayFormatter.kilometers(
                        fromDisplayedDistance: newValue,
                        preference: appSettings.distanceUnitPreference
                    ),
                    1
                )
            }
        )
    }

    private var recommendedRetirementRangeText: String {
        let lower = RunDisplayFormatter.distance(
            kilometers: 500,
            preference: appSettings.distanceUnitPreference,
            fractionLength: 0
        )
        let upper = RunDisplayFormatter.distance(
            kilometers: 800,
            preference: appSettings.distanceUnitPreference,
            fractionLength: 0
        )
        return "\(lower) - \(upper)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("별칭", text: $nickname)
                    TextField("브랜드", text: $brand)
                    TextField("모델", text: $model)
                }

                Section("마일리지") {
                    TextField(
                        L10n.format("시작 거리 (%@)", displayUnit.distanceInputSuffix),
                        value: startMileageBinding,
                        format: .number
                    )
                        .keyboardType(.decimalPad)
                    Text(L10n.format("단위는 %@입니다. 이미 다른 앱이나 실제 사용으로 누적된 거리가 있다면 입력하고, 새 신발이면 0으로 두면 됩니다.", displayUnit.distanceInputSuffix))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField(
                        L10n.format("목표 수명 거리 (%@)", displayUnit.distanceInputSuffix),
                        value: retirementMileageBinding,
                        format: .number
                    )
                        .keyboardType(.decimalPad)
                    Text(L10n.format("단위는 %@입니다. 교체를 고려할 기준 거리이며, 보통 %@ 범위에서 잡습니다.", displayUnit.distanceInputSuffix, recommendedRetirementRangeText))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(existingShoe == nil ? L10n.tr("신발 추가") : L10n.tr("신발 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(existingShoe == nil ? L10n.tr("저장") : L10n.tr("완료")) {
                        let updatedShoe = RunningShoe(
                            id: existingShoe?.id ?? UUID(),
                            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                            startMileageKilometers: max(startMileage, 0),
                            retirementKilometers: max(retirementMileage, 1),
                            createdAt: existingShoe?.createdAt ?? .now
                        )

                        if existingShoe == nil {
                            shoeStore.addShoe(updatedShoe)
                        } else {
                            shoeStore.updateShoe(updatedShoe)
                        }
                        dismiss()
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// 마일리지 화면은 월별/연별 누적 거리를 한곳에 모아 보여준다.
private struct MileageBreakdownView: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    @State private var selectedRange: MileageHistoryRange = .currentYear

    private var summary: MileageRangeSummary {
        viewModel.mileageSummary(for: selectedRange)
    }

    private var monthlyMileage: [MileagePeriod] {
        viewModel.mileageMonthlyPeriods(for: selectedRange)
    }

    private var yearlyMileage: [MileagePeriod] {
        viewModel.mileageYearlyPeriods(for: selectedRange)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("범위")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))

                    Picker("마일리지 범위", selection: $selectedRange) {
                        ForEach(MileageHistoryRange.allCases) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SummaryCard(
                        title: "누적 거리",
                        value: formatKilometers(summary.totalDistanceKilometers),
                        detail: L10n.format("%d회 러닝", summary.runCount)
                    )
                    SummaryCard(
                        title: "데이터 범위",
                        value: selectedRange.label,
                        detail: summary.isFullyLoaded ? "선택 범위 반영 완료" : "선택 범위 확장 중"
                    )
                }

                DetailSection(title: "불러오는 범위") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(summary.helperText)
                            .foregroundStyle(.white.opacity(0.78))

                        if selectedRange != .currentYear && viewModel.isPreparingMileageHistory {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(.white)
                                Text("과거 마일리지 데이터를 불러오는 중")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                            }
                        }
                    }
                }

                MileageSection(title: "월별 마일리지", periods: monthlyMileage)
                MileageSection(title: "연별 마일리지", periods: yearlyMileage)
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.14, blue: 0.20),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("마일리지")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedRange) {
            await viewModel.prepareMileageHistory(for: selectedRange)
        }
    }
}

// 월간/연간 기간 카드 목록을 같은 컴포넌트로 재사용한다.
private struct MileageSection: View {
    let title: String
    let periods: [MileagePeriod]

    var body: some View {
        DetailSection(title: title) {
            if periods.isEmpty {
                Text("불러온 러닝 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(spacing: 10) {
                    ForEach(periods) { period in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(period.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(period.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            Text(period.distanceText)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
