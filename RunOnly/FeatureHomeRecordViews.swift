import Charts
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 홈은 기존 카드형 대시보드 대신 오늘의 판단, 최근 러닝 로그, 다음 행동을 한 흐름으로 묶는다.
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
                        .foregroundStyle(PNR2026.ink)
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
                        HomeRunDesk(
                            viewModel: viewModel,
                            summary: viewModel.summary,
                            runs: runs,
                            vo2MaxSamples: viewModel.vo2MaxSamples
                        )
                        .padding(16)
                        .padding(.bottom, 104)
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

private struct HomeRunDesk: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    let summary: RunningSummary
    let runs: [RunningWorkout]
    let vo2MaxSamples: [VO2MaxSample]
    @EnvironmentObject private var shoeStore: ShoeStore
    @EnvironmentObject private var mileageGoalStore: MileageGoalStore
    @State private var showingGoalEditor = false

    private var recentRuns: [RunningWorkout] {
        Array(runs.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DashboardBrandHeader()

            Button {
                showingGoalEditor = true
            } label: {
                GoalMileageCard(
                    currentDistanceKilometers: summary.monthDistanceKilometers,
                    goalKilometers: mileageGoalStore.monthlyGoalKilometers
                )
            }
            .buttonStyle(.plain)

            DashboardQuickOverviewPanel(
                viewModel: viewModel,
                summary: summary,
                runs: runs,
                vo2MaxSamples: vo2MaxSamples
            )

            HomeRecentLogSection(
                runs: recentRuns,
                allRuns: runs,
                shoeStore: shoeStore
            )

            HomeRaceAndGearSection(
                summary: summary,
                runs: runs,
                shoeStore: shoeStore
            )
        }
        .sheet(isPresented: $showingGoalEditor) {
            MileageGoalEditorView(currentDistanceKilometers: summary.monthDistanceKilometers)
                .environmentObject(mileageGoalStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct HomeRecentLogSection: View {
    let runs: [RunningWorkout]
    let allRuns: [RunningWorkout]
    let shoeStore: ShoeStore

    var body: some View {
        PNRSection(title: "최근 러닝", detail: runs.isEmpty ? nil : "최근 \(runs.count)개") {
            if runs.isEmpty {
                Text("최근 러닝이 쌓이면 날짜순 로그로 표시됩니다.")
                    .font(.subheadline)
                    .foregroundStyle(PNR2026.muted)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(runs) { run in
                        NavigationLink {
                            RunDetailView(run: run)
                        } label: {
                            RecentRunCompactRow(run: run)
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink {
                        RecentRunsListView(runs: allRuns, shoeStore: shoeStore)
                    } label: {
                        HStack {
                            Text("전체 러닝 보기")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(PNR2026.ink)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                                .stroke(PNR2026.line, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct HomeRaceAndGearSection: View {
    let summary: RunningSummary
    let runs: [RunningWorkout]
    let shoeStore: ShoeStore

    private var latestShoeUsage: RecentShoeUsage? {
        for run in runs {
            guard let shoe = shoeStore.shoe(for: run.id) else { continue }
            return RecentShoeUsage(
                shoe: shoe,
                trackedDistanceKilometers: shoeStore.distance(for: shoe.id, runs: runs)
            )
        }
        return nil
    }

    var body: some View {
        PNRSection(title: "다음 확인") {
            VStack(spacing: 8) {
                NavigationLink {
                    PredictionTrendView(runs: runs)
                } label: {
                    PNRPlainRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("예상 완주 기록")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(PNR2026.ink)
                            Text("5K \(summary.predicted5KText) · 10K \(summary.predicted10KText) · 하프 \(summary.predictedHalfText) · 풀 \(summary.predictedMarathonText)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PNR2026.muted)
                                .lineLimit(2)
                        }
                    } trailing: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(PNR2026.heat)
                    }
                }
                .buttonStyle(.plain)

                if let latestShoeUsage {
                    NavigationLink {
                        ShoeDetailView(shoe: latestShoeUsage.shoe, runs: runs)
                    } label: {
                        PNRPlainRow {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("최근 착용 신발")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(PNR2026.ink)
                                Text("\(latestShoeUsage.shoe.displayName) · \(latestShoeUsage.distanceText)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PNR2026.muted)
                                    .lineLimit(1)
                            }
                        } trailing: {
                            Text(latestShoeUsage.usagePercentText)
                                .font(.headline.weight(.black))
                                .foregroundStyle(latestShoeUsage.usageColor)
                                .monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// 기록 탭은 월별 탐색보다 러닝 로그의 스캔과 필터 동선을 우선한다.
struct RecordTabView: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    @EnvironmentObject private var shoeStore: ShoeStore
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
                        .foregroundStyle(PNR2026.ink)
                case .empty:
                    RunReviewFallbackView(
                        title: "러닝 기록이 없습니다",
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
                        VStack(alignment: .leading, spacing: 22) {
                            PNRPageHeader(
                                eyebrow: "Records",
                                title: viewModel.selectedMonthLabelText,
                                subtitle: recordSubtitle
                            )

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

                            RecordMonthSummaryCard(summary: viewModel.selectedMonthSummary)

                            VStack(spacing: 8) {
                                if viewModel.recordRuns.isEmpty {
                                    DetailSection(title: emptyRecordTitle, systemImage: "tray", tint: PNR2026.water) {
                                        Text(emptyRecordMessage)
                                            .foregroundStyle(PNR2026.muted)
                                    }
                                } else {
                                    ForEach(viewModel.recordRuns) { run in
                                        NavigationLink {
                                            RunDetailView(run: run)
                                        } label: {
                                            RunRowCard(
                                                run: run,
                                                shoeDisplay: shoeStore.shoeAssignmentDisplay(for: run.id)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            NavigationLink {
                                RunDetailView(run: .demoSample)
                            } label: {
                                DemoRunAccessCard()
                            }
                            .buttonStyle(.plain)

                            if viewModel.isLoadingMoreHistory, viewModel.selectedMonthRuns.isEmpty {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("이전 기록을 불러오는 중")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(PNR2026.ink)
                                }
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 104)
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
                                isRefreshingRecords: viewModel.isRefreshingPersonalRecords,
                                personalRecordProgress: viewModel.personalRecordProgress,
                                onApproveCandidate: viewModel.approvePersonalRecordCandidate,
                                onDismissCandidate: viewModel.dismissPersonalRecordCandidate,
                                onResetAndReloadRecords: viewModel.resetAndReloadPersonalRecords
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

    private var recordSubtitle: String {
        if let selectedDateText = viewModel.selectedDateLabelText {
            return L10n.format("%@ 기록만 보는 중", selectedDateText)
        }
        return L10n.format("%d회 · %@", viewModel.selectedMonthSummary.runCount, formatKilometers(viewModel.selectedMonthSummary.totalDistanceKilometers))
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
