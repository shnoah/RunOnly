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
                            DashboardHeader(
                                viewModel: viewModel,
                                summary: viewModel.summary,
                                runs: runs,
                                vo2MaxSamples: viewModel.vo2MaxSamples
                            )
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
                        .foregroundStyle(.white)
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
                                    RunDetailView(run: .demoSample)
                                } label: {
                                    DemoRunAccessCard()
                                }
                                .buttonStyle(.plain)

                                if viewModel.recordRuns.isEmpty {
                                    DetailSection(title: emptyRecordTitle, systemImage: "tray", tint: Color(red: 0.42, green: 0.76, blue: 1.0)) {
                                        Text(emptyRecordMessage)
                                            .foregroundStyle(.white.opacity(0.72))
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
