import Charts
import MapKit
import Photos
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 앱의 메인 탭 구조를 구성하고 공통 상태 객체를 각 탭에 주입한다.
struct ContentView: View {
    @StateObject private var viewModel = RunningWorkoutsViewModel()
    @StateObject private var shoeStore = ShoeStore()
    @StateObject private var appSettings = AppSettingsStore()
    @StateObject private var mileageGoalStore = MileageGoalStore()

    var body: some View {
        TabView {
            HomeTabView(viewModel: viewModel)
                .environmentObject(shoeStore)
                .environmentObject(mileageGoalStore)
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            RecordTabView(viewModel: viewModel)
                .environmentObject(shoeStore)
                .tabItem {
                    Label("기록", systemImage: "list.bullet.rectangle")
                }

            ShoesTabView(runs: viewModel.allRuns)
                .environmentObject(shoeStore)
                .tabItem {
                    Label("신발", systemImage: "shoeprints.fill")
                }

            SettingsTabView()
                .environmentObject(shoeStore)
                .environmentObject(appSettings)
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
        }
        .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
        .onAppear {
            viewModel.showAppleWorkoutOnly = appSettings.defaultAppleOnlyFilter
        }
        .onChange(of: appSettings.defaultAppleOnlyFilter) {
            viewModel.showAppleWorkoutOnly = appSettings.defaultAppleOnlyFilter
            viewModel.applyFilter()
        }
    }
}

// 홈 탭은 요약 카드와 최근 상태를 빠르게 보는 대시보드 역할을 맡는다.
private struct HomeTabView: View {
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
                    StatusView(
                        title: "러닝 기록이 없습니다",
                        message: viewModel.showAppleWorkoutOnly
                            ? "Apple 운동 앱에서 기록된 러닝이 아직 보이지 않습니다."
                            : "애플워치나 iPhone의 Workout 앱에서 기록한 러닝이 아직 보이지 않습니다.",
                        buttonTitle: "새로고침"
                    ) {
                        Task {
                            await viewModel.load()
                        }
                    }

                case .failed(let message):
                    StatusView(
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
                                personalRecords: viewModel.personalRecords,
                                pendingCandidates: viewModel.pendingPersonalRecordCandidates,
                                isRefreshingPersonalRecords: viewModel.isRefreshingPersonalRecords,
                                personalRecordProgress: viewModel.personalRecordProgress,
                                onApproveCandidate: viewModel.approvePersonalRecordCandidate,
                                onDismissCandidate: viewModel.dismissPersonalRecordCandidate,
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
            await viewModel.load()
        }
    }
}

// 기록 탭은 월/일 기준으로 러닝 목록을 탐색할 수 있게 구성한다.
private struct RecordTabView: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    @State private var showingCalendar = false

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
                    StatusView(
                        title: "러닝 기록이 없습니다",
                        message: "표시할 러닝 기록이 없습니다.",
                        buttonTitle: "새로고침"
                    ) {
                        Task {
                            await viewModel.load()
                        }
                    }
                case .failed(let message):
                    StatusView(
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
                                isLoading: viewModel.isLoadingMoreHistory,
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
                                onClearDate: {
                                    viewModel.clearRecordDateSelection()
                                }
                            )
                            .padding(.horizontal, 16)

                            RecordMonthSummaryCard(summary: viewModel.selectedMonthSummary)
                                .padding(.horizontal, 16)

                            Group {
                                if viewModel.recordRuns.isEmpty {
                                    DetailSection(title: emptyRecordTitle) {
                                        Text(emptyRecordMessage)
                                            .foregroundStyle(.white.opacity(0.72))
                                    }
                                } else {
                                    VStack(spacing: 14) {
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
                }
            }
            .navigationTitle("기록")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await viewModel.load()
        }
    }

    private var emptyRecordTitle: String {
        viewModel.selectedRecordDate != nil ? "선택한 날짜에 러닝이 없습니다" : "선택한 달에 러닝이 없습니다"
    }

    private var emptyRecordMessage: String {
        if let selectedDateText = viewModel.selectedDateLabelText {
            return "\(selectedDateText)에 기록된 러닝이 없습니다."
        }
        return "\(viewModel.selectedMonthLabelText)에 기록된 러닝이 없습니다."
    }
}

// 월 이동과 날짜 필터 진입 버튼을 담는 상단 헤더다.
private struct RecordMonthHeader: View {
    let monthText: String
    let selectedDateText: String?
    let canMoveNext: Bool
    let isLoading: Bool
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onOpenCalendar: () -> Void
    let onClearDate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("선택 월")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(monthText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button(action: onOpenCalendar) {
                    Label("달력", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(canMoveNext ? .white : .white.opacity(0.3))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .disabled(!canMoveNext || isLoading)
            }

            if let selectedDateText {
                HStack(spacing: 8) {
                    Label("\(selectedDateText)만 보기", systemImage: "line.3.horizontal.decrease.circle.fill")
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
}

// 선택한 달의 거리/빈도/시간을 한눈에 보여주는 요약 카드다.
private struct RecordMonthSummaryCard: View {
    let summary: RecordMonthSummary

    var body: some View {
        HStack(spacing: 12) {
            CompactMetricChip(
                title: "이번 달 거리",
                value: formatKilometers(summary.totalDistanceKilometers),
                detail: "\(summary.runCount)회 러닝"
            )
            CompactMetricChip(
                title: "러닝 빈도",
                value: "\(summary.runningDays)일",
                detail: "주 평균 \(summary.weeklyRunFrequency.formatted(.number.precision(.fractionLength(1))))회"
            )
            CompactMetricChip(
                title: "총 시간",
                value: formatDuration(summary.totalDuration),
                detail: "월간 누적 시간"
            )
        }
    }
}

// 달력 시트는 특정 날짜 러닝만 빠르게 필터링할 때 사용한다.
private struct RecordCalendarSheet: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button {
                            Task {
                                await viewModel.moveRecordMonth(by: -1)
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoadingMoreHistory)

                        Spacer()

                        Text(viewModel.selectedMonthLabelText)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            Task {
                                await viewModel.moveRecordMonth(by: 1)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(viewModel.canMoveToNextRecordMonth ? .white : .white.opacity(0.3))
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canMoveToNextRecordMonth || viewModel.isLoadingMoreHistory)
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
                                value: "\(viewModel.selectedMonthSummary.runningDays)일",
                                detail: "뛴 날 / 안 뛴 날 확인"
                            )
                            CompactMetricChip(
                                title: "총 러닝",
                                value: "\(viewModel.selectedMonthSummary.runCount)회",
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
private struct MetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// 빈 상태와 오류 상태에서 재시도 버튼까지 함께 제공한다.
private struct StatusView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 홈 대시보드 상단의 핵심 요약 카드 묶음을 만든다.
private struct DashboardHeader: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    let summary: RunningSummary
    let runs: [RunningWorkout]
    let vo2MaxSamples: [VO2MaxSample]
    let personalRecords: [PersonalRecordEntry]
    let pendingCandidates: [PersonalRecordCandidate]
    let isRefreshingPersonalRecords: Bool
    let personalRecordProgress: Double?
    let onApproveCandidate: (PersonalRecordDistance) -> Void
    let onDismissCandidate: (PersonalRecordDistance) -> Void
    @Binding var showAppleWorkoutOnly: Bool
    let onToggle: () -> Void
    @EnvironmentObject private var mileageGoalStore: MileageGoalStore
    @State private var showingGoalEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink {
                MileageBreakdownView(viewModel: viewModel)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("이번달")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(summary.monthDistanceText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Label("올해 \(summary.yearDistanceText)", systemImage: "figure.run")
                        Label(summary.trainingStatus, systemImage: "chart.line.uptrend.xyaxis")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                }
            }
            .buttonStyle(.plain)

            Button {
                showingGoalEditor = true
            } label: {
                GoalMileageCard(
                    currentDistanceKilometers: summary.monthDistanceKilometers,
                    goalKilometers: mileageGoalStore.monthlyGoalKilometers
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                NavigationLink {
                    TrainingTrendView(runs: runs, summary: summary)
                } label: {
                    SummaryCard(title: "훈련 추세", value: summary.trainingStatus, detail: summary.trainingStatusDetail)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    VO2MaxTrendView(samples: vo2MaxSamples)
                } label: {
                    SummaryCard(title: "VO2 Max", value: summary.vo2MaxText, detail: summary.vo2MaxDateText)
                }
                .buttonStyle(.plain)
            }

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

            PersonalRecordsCard(
                records: personalRecords,
                pendingCandidates: pendingCandidates,
                isRefreshing: isRefreshingPersonalRecords,
                progress: personalRecordProgress,
                onApproveCandidate: onApproveCandidate,
                onDismissCandidate: onDismissCandidate
            )

            Toggle(isOn: $showAppleWorkoutOnly) {
                Text("Apple 운동 앱 기록만 보기")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
            .onChange(of: showAppleWorkoutOnly) {
                onToggle()
            }
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

// 공통 요약 카드는 대시보드 전반에서 같은 시각 규칙을 유지한다.
private struct SummaryCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

private struct GoalMileageCard: View {
    let currentDistanceKilometers: Double
    let goalKilometers: Double

    private var progress: Double {
        guard goalKilometers > 0 else { return 0 }
        return min(currentDistanceKilometers / goalKilometers, 1)
    }

    private var headlineText: String {
        "\(currentDistanceKilometers.formatted(.number.precision(.fractionLength(1)))) / \(goalKilometers.formatted(.number.precision(.fractionLength(0)))) km"
    }

    private var statusText: String {
        let remaining = goalKilometers - currentDistanceKilometers
        if remaining > 0 {
            return "\(remaining.formatted(.number.precision(.fractionLength(1)))) km 남음"
        }
        return "\(abs(remaining).formatted(.number.precision(.fractionLength(1)))) km 초과 달성"
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
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            ProgressView(value: progress)
                .tint(Color(red: 0.29, green: 0.88, blue: 0.63))

            HStack {
                Text(statusText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
                Spacer()
                Text(Date().formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month(.wide)))
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
    @Environment(\.dismiss) private var dismiss
    @State private var draftGoalKilometers: Double = 60
    @State private var didLoadInitialValue = false

    private let presetGoals: [Double] = [40, 60, 80, 100, 150]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
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

                    DetailSection(title: "월간 목표 설정") {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField(
                                "월간 목표 거리 (km)",
                                value: $draftGoalKilometers,
                                format: .number.precision(.fractionLength(0...1))
                            )
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                            Stepper(
                                value: $draftGoalKilometers,
                                in: 10...500,
                                step: 5
                            ) {
                                Text("5 km 단위로 조정")
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
                                        Text("\(Int(goal)) km")
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
            return "\(remaining.formatted(.number.precision(.fractionLength(1)))) km 남음"
        }
        return "이미 달성"
    }
}

// 차트에서 선택한 지점의 즉시 값을 두 줄 그리드로 보여준다.
private struct CompactSelectionRow: View {
    let metrics: SelectedMetrics

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            CompactMetricChip(title: "거리", value: metrics.distanceText, detail: metrics.elapsedText)
            CompactMetricChip(title: "페이스", value: metrics.paceText, detail: "선택 구간")
            CompactMetricChip(title: "심박", value: metrics.heartRateText, detail: "선택 시점")
            if let cadenceText = metrics.cadenceText {
                CompactMetricChip(title: "케이던스", value: cadenceText, detail: "선택 시점")
            }
            if let altitudeText = metrics.altitudeText {
                CompactMetricChip(title: "고도", value: altitudeText, detail: "선택 지점")
            }
        }
    }
}

// 선택값이 없을 때는 전체 평균값을 대신 노출한다.
private struct CompactAverageRow: View {
    let averagePaceText: String
    let averageHeartRateText: String
    let averageCadenceText: String?

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            CompactMetricChip(title: "평균 페이스", value: averagePaceText, detail: "러닝 전체")
            CompactMetricChip(title: "평균 심박", value: averageHeartRateText, detail: "러닝 전체")
            if let averageCadenceText {
                CompactMetricChip(title: "평균 케이던스", value: averageCadenceText, detail: "러닝 전체")
            }
        }
    }
}

// 여러 화면에서 재사용하는 작은 메트릭 배지다.
private struct CompactMetricChip: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
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
                PredictionCell(title: "하프", value: predictedHalfText)
                PredictionCell(title: "풀", value: predictedMarathonText)
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
            Text(title)
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
                        Text("검토 \(pendingCandidates.count)건")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(statusText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(records) { record in
                    PersonalRecordCell(record: record)
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
        guard isRefreshing else { return "전체 러닝 기준" }
        let percent = Int(((progress ?? 0) * 100).rounded())
        return "계산 중 \(percent)%"
    }
}

// PR 거리 한 칸을 렌더링한다.
private struct PersonalRecordCell: View {
    let record: PersonalRecordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.distance.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
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

// PR 후보를 승인/유지하는 검토 전용 화면이다.
private struct PersonalRecordsManagementView: View {
    let currentRecords: [PersonalRecordEntry]
    let pendingCandidates: [PersonalRecordCandidate]
    let onApproveCandidate: (PersonalRecordDistance) -> Void
    let onDismissCandidate: (PersonalRecordDistance) -> Void

    private var currentRecordMap: [PersonalRecordDistance: PersonalRecordEntry] {
        Dictionary(uniqueKeysWithValues: currentRecords.map { ($0.distance, $0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if pendingCandidates.isEmpty {
                    DetailSection(title: "검토 대기 없음") {
                        Text("최근 3년보다 오래된 더 빠른 후보 기록이 없습니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                } else {
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
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("PR 검토")
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

// 목록 셀 하나에 날짜/거리/페이스/신발 정보를 압축해 담는다.
private struct RunRowCard: View {
    let run: RunningWorkout
    @EnvironmentObject private var shoeStore: ShoeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(run.recordDateText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        RunEnvironmentBadge(text: run.environmentShortText)
                        Text(run.sourceName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 10) {
                RunMetricPill(title: "거리", value: run.distanceText)
                RunMetricPill(title: "시간", value: run.durationText)
                RunMetricPill(title: "페이스", value: run.paceText)
            }

            if let shoe = shoeStore.shoe(for: run.id) {
                Label(shoe.displayName, systemImage: "shoeprints.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// 실내/실외 여부를 한눈에 보이도록 만든 작은 배지다.
private struct RunEnvironmentBadge: View {
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

// 러닝 핵심 수치를 가볍게 보여주는 작은 카드다.
private struct RunMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
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

// 러닝 상세 화면은 route, split, 차트, 장비 정보를 순서대로 보여준다.
private struct RunDetailView: View {
    let run: RunningWorkout
    @StateObject private var viewModel: RunDetailViewModel
    @State private var showingShareComposer = false

    init(run: RunningWorkout) {
        self.run = run
        _viewModel = StateObject(wrappedValue: RunDetailViewModel(run: run))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(run.detailDateText)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        RunEnvironmentBadge(text: run.environmentText)
                        Text(run.sourceName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                DebugScenarioPanel(viewModel: viewModel)

                switch viewModel.state {
                case .idle, .loading:
                    DetailSection(title: "러닝 경로") {
                        ProgressView("상세 데이터를 불러오는 중")
                            .tint(.white)
                            .foregroundStyle(.white)
                    }

                case .failed(let message):
                    DetailSection(title: "상세 데이터를 불러오지 못했습니다") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(message)
                                .foregroundStyle(.white.opacity(0.72))
                            Button("다시 시도") {
                                Task {
                                    await viewModel.load()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                case .loaded(let detail):
                    RunOverviewMetricsSection(run: run, detail: detail)
                    RunSplitSection(detail: detail)
                    PerformanceChartSection(run: run, detail: detail)
                    HeartRateZoneSection(detail: detail)
                    RunGearSection(run: run)
                    RunRouteSection(detail: detail)
                    RunDataSourceSection(run: run)
                }
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if loadedDetail != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingShareComposer = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .sheet(isPresented: $showingShareComposer) {
            if let loadedDetail {
                RunShareComposerView(
                    run: run,
                    detail: loadedDetail
                )
            }
        }
    }

    private var loadedDetail: RunDetail? {
        guard case .loaded(let detail) = viewModel.state else { return nil }
        return detail
    }
}

// 경로 데이터가 있으면 지도를, 없으면 안내 문구를 보여준다.
private struct RunRouteSection: View {
    let detail: RunDetail

    var body: some View {
        DetailSection(title: "러닝 경로") {
            if detail.route.isEmpty {
                Text("이 러닝에는 경로 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                RouteMapView(points: detail.route)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

// 페이스/심박/케이던스/고도를 동기화해 보는 핵심 차트 섹션이다.
private struct PerformanceChartSection: View {
    let run: RunningWorkout
    let detail: RunDetail
    @State private var selectedDistance: Double?

    var body: some View {
        DetailSection(title: "퍼포먼스 차트") {
            if heartSeries.isEmpty && paceSeries.isEmpty && cadenceSeries.isEmpty && altitudeSeries.isEmpty {
                Text("그래프를 그릴 경로 또는 심박 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if let selectedMetrics {
                        CompactSelectionRow(metrics: selectedMetrics)
                    } else {
                        CompactAverageRow(
                            averagePaceText: averagePaceText,
                            averageHeartRateText: averageHeartRateText,
                            averageCadenceText: averageCadenceText
                        )
                    }

                    VStack(spacing: 0) {
                        if !paceSeries.isEmpty {
                            metricHeader(title: "페이스", systemImage: "speedometer", tint: .orange)
                                .padding(.bottom, 6)

                            PaceChartPlot(
                                selectedMetrics: selectedMetrics,
                                selectedPacePoint: selectedPacePoint,
                                selectedDistance: $selectedDistance,
                                paceSeries: paceSeries,
                                paceRange: paceRange,
                                strideValues: strideValues,
                                maxDistance: maxDistance,
                                showsXAxis: false
                            )
                            .frame(height: 144)
                        }

                        if !heartSeries.isEmpty {
                            sectionDivider
                            metricHeader(
                                title: "심박",
                                systemImage: "heart.fill",
                                tint: Color(red: 0.45, green: 0.95, blue: 0.76)
                            )
                            .padding(.bottom, 6)

                            HeartRateChartPlot(
                                selectedMetrics: selectedMetrics,
                                selectedHeartPoint: selectedHeartPoint,
                                selectedDistance: $selectedDistance,
                                heartSeries: heartSeries,
                                heartRateRange: heartRateRange,
                                strideValues: strideValues,
                                maxDistance: maxDistance,
                                showsXAxis: cadenceSeries.isEmpty && altitudeSeries.isEmpty
                            )
                            .frame(height: 144)
                        }

                        if !cadenceSeries.isEmpty {
                            sectionDivider
                            metricHeader(
                                title: "케이던스",
                                systemImage: "metronome",
                                tint: Color(red: 0.42, green: 0.76, blue: 1.0)
                            )
                            .padding(.bottom, 6)

                            SyncedMetricChartPlot(
                                selectedDistance: $selectedDistance,
                                selectedPoint: selectedCadencePoint,
                                points: cadenceSeries,
                                valueRange: cadenceRange,
                                strideValues: strideValues,
                                maxDistance: maxDistance,
                                tint: Color(red: 0.42, green: 0.76, blue: 1.0),
                                showsXAxis: altitudeSeries.isEmpty
                            )
                            .frame(height: 144)
                        }

                        if !altitudeSeries.isEmpty {
                            sectionDivider
                            metricHeader(
                                title: "고도",
                                systemImage: "mountain.2.fill",
                                tint: Color(red: 0.68, green: 0.60, blue: 0.96)
                            )
                            .padding(.bottom, 6)

                            SyncedMetricChartPlot(
                                selectedDistance: $selectedDistance,
                                selectedPoint: selectedAltitudePoint,
                                points: altitudeSeries,
                                valueRange: altitudeRange,
                                strideValues: strideValues,
                                maxDistance: maxDistance,
                                tint: Color(red: 0.68, green: 0.60, blue: 0.96),
                                showsXAxis: true
                            )
                            .frame(height: 144)
                        }
                    }
                }
            }
        }
    }

    private var averageHeartRateText: String {
        guard !detail.heartRates.isEmpty else { return "-" }
        let avg = detail.heartRates.map(\.bpm).reduce(0, +) / Double(detail.heartRates.count)
        return avg.formatted(.number.precision(.fractionLength(0))) + " bpm"
    }

    private var averagePaceText: String {
        run.paceText
    }

    private var averageCadenceText: String? {
        let weightedCadence = detail.splits.reduce(into: (weighted: 0.0, duration: 0.0)) { partial, split in
            guard let cadence = split.averageCadence else { return }
            partial.weighted += cadence * split.duration
            partial.duration += split.duration
        }

        if weightedCadence.duration > 0 {
            let average = weightedCadence.weighted / weightedCadence.duration
            return average.formatted(.number.precision(.fractionLength(0))) + " spm"
        }

        guard !detail.runningMetrics.cadence.isEmpty else { return nil }
        let average = detail.runningMetrics.cadence.map(\.value).reduce(0, +) / Double(detail.runningMetrics.cadence.count)
        return average.formatted(.number.precision(.fractionLength(0))) + " spm"
    }

    private var heartSeries: [HeartRateChartPoint] {
        HeartRateChartPoint.build(from: detail.heartRates)
    }

    private var paceSeries: [PaceChartPoint] {
        PaceChartPoint.build(from: detail.paceSamples)
    }

    private var cadenceSeries: [SimpleMetricChartPoint] {
        detail.runningMetrics.cadence.compactMap { sample in
            guard let distanceMeters = sample.distanceMeters else { return nil }
            return SimpleMetricChartPoint(
                distanceKilometers: distanceMeters / 1_000,
                value: sample.value,
                segmentIndex: sample.segmentIndex
            )
        }
    }

    private var altitudeSeries: [SimpleMetricChartPoint] {
        detail.route.map { point in
            SimpleMetricChartPoint(
                distanceKilometers: point.distanceMeters / 1_000,
                value: point.altitudeMeters ?? .nan,
                segmentIndex: nil
            )
        }
        .filter { $0.value.isFinite }
    }

    private var selectedMetrics: SelectedMetrics? {
        guard let resolvedDistanceKilometers = snappedDistanceKilometers else { return nil }

        let resolvedDistanceMeters = resolvedDistanceKilometers * 1_000
        let nearestDistancePoint = detail.distanceTimeline.min(by: {
            abs($0.distanceMeters - resolvedDistanceMeters) < abs($1.distanceMeters - resolvedDistanceMeters)
        })

        return SelectedMetrics(
            distanceMeters: resolvedDistanceMeters,
            elapsed: nearestDistancePoint?.elapsed ?? 0,
            paceSecondsPerKilometer: selectedPacePoint?.secondsPerKilometer,
            heartRate: selectedHeartPoint?.bpm,
            cadence: selectedCadencePoint?.value,
            altitudeMeters: selectedAltitudePoint?.value
        )
    }

    private var snappedDistanceKilometers: Double? {
        guard let selectedDistance else { return nil }
        return min(max(selectedDistance, 0), maxDistance)
    }

    private var selectedPacePoint: PaceChartPoint? {
        guard let snappedDistanceKilometers else { return nil }
        return paceSeries.min(by: {
            abs($0.distanceKilometers - snappedDistanceKilometers) < abs($1.distanceKilometers - snappedDistanceKilometers)
        })
    }

    private var selectedHeartPoint: HeartRateChartPoint? {
        guard let snappedDistanceKilometers else { return nil }
        return heartSeries.min(by: {
            abs($0.distanceKilometers - snappedDistanceKilometers) < abs($1.distanceKilometers - snappedDistanceKilometers)
        })
    }

    private var selectedCadencePoint: SimpleMetricChartPoint? {
        guard let snappedDistanceKilometers else { return nil }
        return cadenceSeries.min(by: {
            abs($0.distanceKilometers - snappedDistanceKilometers) < abs($1.distanceKilometers - snappedDistanceKilometers)
        })
    }

    private var selectedAltitudePoint: SimpleMetricChartPoint? {
        guard let snappedDistanceKilometers else { return nil }
        return altitudeSeries.min(by: {
            abs($0.distanceKilometers - snappedDistanceKilometers) < abs($1.distanceKilometers - snappedDistanceKilometers)
        })
    }

    private var heartRateRange: ClosedRange<Double> {
        let values = heartSeries.map(\.bpm)
        let minValue = max((values.min() ?? 110) - 12, 60)
        let maxValue = max((values.max() ?? 180) + 12, minValue + 20)
        return minValue...maxValue
    }

    private var paceRange: ClosedRange<Double> {
        let values = paceSeries.map(\.secondsPerKilometer)
        let minValue = values.min() ?? 300
        let maxValue = max(values.max() ?? 420, minValue + 1)
        return minValue...max(maxValue, minValue + 1)
    }

    private var cadenceRange: ClosedRange<Double> {
        metricRange(for: cadenceSeries.map(\.value), minimumPadding: 6)
    }

    private var altitudeRange: ClosedRange<Double> {
        metricRange(for: altitudeSeries.map(\.value), minimumPadding: 4)
    }

    private var strideValues: [Double] {
        guard maxDistance > 0 else { return [] }

        let stride: Double
        switch maxDistance {
        case ..<3: stride = 0.5
        case ..<10: stride = 1
        case ..<20: stride = 2
        default: stride = 5
        }

        let count = Int(ceil(maxDistance / stride))
        var values = Array(0...count).map { Double($0) * stride }
        if let last = values.last, abs(last - maxDistance) > 0.001 {
            values.append(maxDistance)
        }
        return values
    }

    private var maxDistance: Double {
        max(
            run.distanceInKilometers,
            (detail.distanceTimeline.last?.distanceMeters ?? 0) / 1_000,
            paceSeries.last?.distanceKilometers ?? 0,
            heartSeries.last?.distanceKilometers ?? 0
        )
    }

    private func formatPace(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return (formatter.string(from: seconds) ?? "-") + "/km"
    }

    private func metricHeader(title: String, systemImage: String, tint: Color) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Spacer()
        }
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.vertical, 10)
    }

    private func metricRange(for values: [Double], minimumPadding: Double) -> ClosedRange<Double> {
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? minValue + minimumPadding
        let padding = max((maxValue - minValue) * 0.12, minimumPadding)
        return (minValue - padding)...(maxValue + padding)
    }
}

// 선택 거리를 기준으로 페이스 선 그래프를 그린다.
private struct PaceChartPlot: View {
    let selectedMetrics: SelectedMetrics?
    let selectedPacePoint: PaceChartPoint?
    @Binding var selectedDistance: Double?
    let paceSeries: [PaceChartPoint]
    let paceRange: ClosedRange<Double>
    let strideValues: [Double]
    let maxDistance: Double
    let showsXAxis: Bool

    var body: some View {
        Chart {
            ForEach(paceSeries) { sample in
                LineMark(
                    x: .value("거리", sample.distanceKilometers),
                    y: .value("페이스", displayedPace(sample.secondsPerKilometer)),
                    series: .value("세그먼트", sample.segmentIndex)
                )
                .foregroundStyle(Color.orange.opacity(0.95))
                .lineStyle(StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            if let selectedMetrics {
                RuleMark(x: .value("선택", selectedPacePoint?.distanceKilometers ?? selectedMetrics.distanceKilometers))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.2))

                if let selectedPacePoint {
                    PointMark(
                        x: .value("선택 페이스", selectedPacePoint.distanceKilometers),
                        y: .value("선택 페이스값", displayedPace(selectedPacePoint.secondsPerKilometer))
                    )
                    .foregroundStyle(Color.orange)
                    .symbolSize(24)
                }
            }
        }
        .chartXSelection(value: $selectedDistance)
        .chartXScale(domain: 0...max(maxDistance, 0.1))
        .chartYScale(domain: 0...max(paceRange.upperBound - paceRange.lowerBound, 0.1))
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
        .chartXAxis {
            AxisMarks(values: showsXAxis ? strideValues : []) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.12))
                if showsXAxis {
                    AxisTick()
                        .foregroundStyle(.white.opacity(0.4))
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text(formatAxisDistance(distance))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
        .chartYAxis(.hidden)
    }

    private func displayedPace(_ seconds: Double) -> Double {
        paceRange.upperBound - seconds
    }
}

// 심박 그래프도 같은 거리 축을 공유해 상호 비교를 쉽게 만든다.
private struct HeartRateChartPlot: View {
    let selectedMetrics: SelectedMetrics?
    let selectedHeartPoint: HeartRateChartPoint?
    @Binding var selectedDistance: Double?
    let heartSeries: [HeartRateChartPoint]
    let heartRateRange: ClosedRange<Double>
    let strideValues: [Double]
    let maxDistance: Double
    let showsXAxis: Bool

    var body: some View {
        Chart {
            ForEach(heartSeries) { sample in
                LineMark(
                    x: .value("거리", sample.distanceKilometers),
                    y: .value("심박", sample.bpm),
                    series: .value("세그먼트", sample.segmentIndex)
                )
                .foregroundStyle(Color(red: 0.45, green: 0.95, blue: 0.76))
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            if let selectedMetrics {
                RuleMark(x: .value("선택", selectedHeartPoint?.distanceKilometers ?? selectedMetrics.distanceKilometers))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.2))

                if let selectedHeartPoint {
                    PointMark(
                        x: .value("선택 심박", selectedHeartPoint.distanceKilometers),
                        y: .value("선택 심박값", selectedHeartPoint.bpm)
                    )
                    .foregroundStyle(Color(red: 0.45, green: 0.95, blue: 0.76))
                    .symbolSize(24)
                }
            }
        }
        .chartXSelection(value: $selectedDistance)
        .chartXScale(domain: 0...max(maxDistance, 0.1))
        .chartYScale(domain: heartRateRange.lowerBound...heartRateRange.upperBound)
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
        .chartXAxis {
            AxisMarks(values: showsXAxis ? strideValues : []) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.12))
                if showsXAxis {
                    AxisTick()
                        .foregroundStyle(.white.opacity(0.4))
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text(formatAxisDistance(distance))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
        .chartYAxis(.hidden)
    }
}

private func formatAxisDistance(_ distance: Double) -> String {
    let hasFraction = abs(distance.rounded() - distance) > 0.001
    let fractionLength = hasFraction ? 2 : 1
    return distance.formatted(.number.precision(.fractionLength(fractionLength)))
}

// km 단위 스플릿 표를 렌더링한다.
private struct RunSplitSection: View {
    let detail: RunDetail

    var body: some View {
        DetailSection(title: "km 스플릿") {
            if detail.splits.isEmpty {
                Text("스플릿을 계산할 경로 데이터가 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(spacing: 0) {
                    SplitTableHeader()
                    ForEach(detail.splits) { split in
                        SplitTableRow(split: split)
                        if split.id != detail.splits.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                                .padding(.leading, 4)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

// 러닝 전체 평균값을 요약해서 상세 상단에 배치한다.
private struct RunOverviewMetricsSection: View {
    let run: RunningWorkout
    let detail: RunDetail

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            CompactMetricChip(title: "거리", value: run.distanceText, detail: "총 거리")
            CompactMetricChip(title: "시간", value: run.durationText, detail: "총 운동 시간")
            CompactMetricChip(title: "평균 페이스", value: run.paceText, detail: "러닝 전체")
            CompactMetricChip(title: "평균 심박", value: averageHeartRateText, detail: "러닝 전체")
            CompactMetricChip(title: "평균 케이던스", value: averageCadenceText, detail: "러닝 전체")
        }
    }

    private var averageHeartRateText: String {
        guard !detail.heartRates.isEmpty else { return "-" }
        let avg = detail.heartRates.map(\.bpm).reduce(0, +) / Double(detail.heartRates.count)
        return avg.formatted(.number.precision(.fractionLength(0))) + " bpm"
    }

    private var averageCadenceText: String {
        let weightedCadence = detail.splits.reduce(into: (weighted: 0.0, duration: 0.0)) { partial, split in
            guard let cadence = split.averageCadence else { return }
            partial.weighted += cadence * split.duration
            partial.duration += split.duration
        }

        if weightedCadence.duration > 0 {
            let average = weightedCadence.weighted / weightedCadence.duration
            return average.formatted(.number.precision(.fractionLength(0))) + " spm"
        }

        guard !detail.runningMetrics.cadence.isEmpty else { return "-" }
        let avg = detail.runningMetrics.cadence.map(\.value).reduce(0, +) / Double(detail.runningMetrics.cadence.count)
        return avg.formatted(.number.precision(.fractionLength(0))) + " spm"
    }
}

// 심박 존은 현재 러닝에서 어느 강도로 뛰었는지 빠르게 확인하는 영역이다.
private struct HeartRateZoneSection: View {
    let detail: RunDetail

    var body: some View {
        DetailSection(title: "심박 존 1-5") {
            if zoneRows.isEmpty {
                Text("심박 데이터가 부족해 존 분포를 계산할 수 없습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(detail.heartRateZoneProfile?.method.descriptionText ?? "심박 존 기준 없음")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))

                    ForEach(zoneRows) { zone in
                        HeartRateZoneRow(zone: zone)
                    }
                }
            }
        }
    }

    private var zoneRows: [HeartRateZoneRowModel] {
        guard detail.heartRates.count >= 2 else { return [] }
        guard let zoneProfile = detail.heartRateZoneProfile else { return [] }

        let boundaries: [(label: String, lower: Double, upper: Double, color: Color)] = [
            ("존 1", 0.50, 0.60, Color.blue),
            ("존 2", 0.60, 0.70, Color.green),
            ("존 3", 0.70, 0.80, Color.yellow),
            ("존 4", 0.80, 0.90, Color.orange),
            ("존 5", 0.90, 1.01, Color.red)
        ]

        let sortedHeartRates = detail.heartRates.sorted {
            ($0.elapsed ?? .greatestFiniteMagnitude) < ($1.elapsed ?? .greatestFiniteMagnitude)
        }
        let totalDuration = max(detail.activeDuration, 1)
        var durations = Array(repeating: 0.0, count: boundaries.count)

        for index in sortedHeartRates.indices {
            let current = sortedHeartRates[index]
            guard let currentElapsed = current.elapsed else { continue }
            let nextElapsed = sortedHeartRates.indices.contains(index + 1)
                ? (sortedHeartRates[index + 1].elapsed ?? detail.activeDuration)
                : detail.activeDuration
            let sampleDuration = max(nextElapsed - currentElapsed, 0)
            guard sampleDuration > 0 else { continue }

            if let zoneIndex = boundaries.firstIndex(where: {
                let bpmRange = zoneProfile.bpmRange(lowerFraction: $0.lower, upperFraction: min($0.upper, 1.0))
                return current.bpm >= Double(bpmRange.lowerBound) && current.bpm < Double(bpmRange.upperBound + 1)
            }) {
                durations[zoneIndex] += sampleDuration
            }
        }

        return boundaries.enumerated().map { index, boundary in
            let bpmRange = zoneProfile.bpmRange(
                lowerFraction: boundary.lower,
                upperFraction: min(boundary.upper, 1.0)
            )
            return HeartRateZoneRowModel(
                title: boundary.label,
                rangeText: "\(bpmRange.lowerBound)-\(bpmRange.upperBound) bpm",
                intensityText: "\(Int(boundary.lower * 100))-\(Int(min(boundary.upper, 1.0) * 100))%",
                duration: durations[index],
                percentage: durations[index] / totalDuration,
                color: boundary.color
            )
        }
    }
}

// 데이터 출처를 노출해 사용자가 어떤 앱에서 기록된 운동인지 확인할 수 있다.
private struct RunDataSourceSection: View {
    let run: RunningWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("데이터 소스")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(run.sourceName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text(run.sourceBundleIdentifier)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }
}

// 심박 존 UI에 필요한 가공 데이터를 묶어둔다.
private struct HeartRateZoneRowModel: Identifiable {
    let id = UUID()
    let title: String
    let rangeText: String
    let intensityText: String
    let duration: TimeInterval
    let percentage: Double
    let color: Color
}

// 심박 존 한 줄은 범위/시간/비율을 동시에 표현한다.
private struct HeartRateZoneRow: View {
    let zone: HeartRateZoneRowModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(zone.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(zone.rangeText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                Text(zone.intensityText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .frame(width: 64, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(zone.color)
                        .frame(width: max(proxy.size.width * max(zone.percentage, 0.02), zone.duration > 0 ? 10 : 0))
                }
            }
            .frame(height: 14)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(zone.duration))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("\((zone.percentage * 100).formatted(.number.precision(.fractionLength(0))))%")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .monospacedDigit()
            }
            .frame(width: 64, alignment: .trailing)
        }
    }
}

// 단일 값 시계열 차트를 그릴 때 사용하는 공통 포인트 모델이다.
private struct SimpleMetricChartPoint: Identifiable {
    let id: String
    let distanceKilometers: Double
    let value: Double
    let segmentIndex: Int?

    init(distanceKilometers: Double, value: Double, segmentIndex: Int?) {
        self.id = "\(distanceKilometers)-\(segmentIndex ?? -1)"
        self.distanceKilometers = distanceKilometers
        self.value = value
        self.segmentIndex = segmentIndex
    }
}

// 케이던스/고도처럼 단순 수치 차트는 이 컴포넌트를 재사용한다.
private struct SyncedMetricChartPlot: View {
    @Binding var selectedDistance: Double?
    let selectedPoint: SimpleMetricChartPoint?
    let points: [SimpleMetricChartPoint]
    let valueRange: ClosedRange<Double>
    let strideValues: [Double]
    let maxDistance: Double
    let tint: Color
    let showsXAxis: Bool

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("거리", point.distanceKilometers),
                    y: .value("값", point.value),
                    series: .value("세그먼트", point.segmentIndex ?? -1)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            if let selectedPoint {
                RuleMark(x: .value("선택", selectedPoint.distanceKilometers))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.2))

                PointMark(
                    x: .value("선택값", selectedPoint.distanceKilometers),
                    y: .value("선택값Y", selectedPoint.value)
                )
                .foregroundStyle(tint)
                .symbolSize(24)
            }
        }
        .chartXSelection(value: $selectedDistance)
        .chartXScale(domain: 0...max(maxDistance, 0.1))
        .chartYScale(domain: valueRange.lowerBound...valueRange.upperBound)
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
        .chartXAxis {
            AxisMarks(values: showsXAxis ? strideValues : []) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.12))
                if showsXAxis {
                    AxisTick()
                        .foregroundStyle(.white.opacity(0.35))
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text(formatAxisDistance(distance))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }
                }
            }
        }
        .chartYAxis(.hidden)
    }
}

// 추가 보조 차트가 필요할 때 재사용하는 일반 라인 차트다.
private struct AdditionalMetricChart: View {
    let title: String
    let tint: Color
    let yLabel: String
    let points: [SimpleMetricChartPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(yLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Chart(points) { point in
                LineMark(
                    x: .value("거리", point.distanceKilometers),
                    y: .value(title, point.value)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 140)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.white.opacity(0.12))
                    AxisTick()
                        .foregroundStyle(.white.opacity(0.35))
                    AxisValueLabel {
                        if let distance = value.as(Double.self) {
                            Text(formatAxisDistance(distance))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel {
                        if let raw = value.as(Double.self) {
                            Text(raw.formatted(.number.precision(.fractionLength(0))))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.background(.clear)
            }
        }
    }
}

// 화면 곳곳에 쓰는 공통 섹션 카드 래퍼다.
private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// 스플릿 표 헤더는 거리/페이스/심박/케이던스 열을 고정 폭으로 맞춘다.
private struct SplitTableHeader: View {
    var body: some View {
        HStack(spacing: SplitColumnLayout.spacing) {
            splitColumnTitle("거리", width: SplitColumnLayout.distanceWidth, alignment: .leading)
            splitColumnTitle("페이스", width: SplitColumnLayout.paceWidth, alignment: .trailing)
            splitColumnTitle("심박", width: SplitColumnLayout.heartWidth, alignment: .trailing)
            splitColumnTitle("케이던스", width: SplitColumnLayout.cadenceWidth, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
    }

    private func splitColumnTitle(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.45))
            .frame(width: width, alignment: alignment)
    }
}

// 스플릿 한 줄은 열 폭을 유지해 가독성을 확보한다.
private struct SplitTableRow: View {
    let split: RunSplit

    var body: some View {
        HStack(spacing: SplitColumnLayout.spacing) {
            Text(split.titleText)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: SplitColumnLayout.distanceWidth, alignment: .leading)

            Text(split.paceText)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .frame(width: SplitColumnLayout.paceWidth, alignment: .trailing)
                .monospacedDigit()

            Text(split.heartRateText)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(split.averageHeartRate == nil ? .white.opacity(0.45) : .white.opacity(0.78))
                .frame(width: SplitColumnLayout.heartWidth, alignment: .trailing)
                .monospacedDigit()

            Text(split.cadenceText)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(split.averageCadence == nil ? .white.opacity(0.45) : .white.opacity(0.78))
                .frame(width: SplitColumnLayout.cadenceWidth, alignment: .trailing)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// 표 레이아웃 상수는 숫자 열 정렬이 흔들리지 않도록 분리했다.
private enum SplitColumnLayout {
    static let spacing: CGFloat = 10
    static let distanceWidth: CGFloat = 68
    static let paceWidth: CGFloat = 88
    static let heartWidth: CGFloat = 72
    static let cadenceWidth: CGFloat = 82
}

// 지도는 시작/종료 지점과 경로 폴리라인만 단순하게 보여준다.
private struct RouteMapView: View {
    let points: [RunRoutePoint]
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if let start = points.first {
                Annotation("Start", coordinate: start.coordinate) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                }
            }

            if let end = points.last {
                Annotation("End", coordinate: end.coordinate) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                }
            }

            MapPolyline(coordinates: points.map(\.coordinate))
                .stroke(Color(red: 0.29, green: 0.88, blue: 0.63), lineWidth: 5)
        }
        .mapStyle(.standard(elevation: .flat))
        .onAppear {
            position = .rect(mapRect)
        }
    }

    private var mapRect: MKMapRect {
        let mapPoints = points.map { MKMapPoint($0.coordinate) }
        guard let first = mapPoints.first else { return .world }

        return mapPoints.dropFirst().reduce(
            MKMapRect(origin: first, size: MKMapSize(width: 0, height: 0))
        ) { partialResult, point in
            partialResult.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
    }
}

private extension RunRoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// 페이스 샘플을 화면 친화적인 포인트로 바꾼다.
private struct PaceChartPoint: Identifiable {
    let id: Double
    let distanceMeters: Double
    let distanceKilometers: Double
    let secondsPerKilometer: Double
    let segmentIndex: Int

    init(distanceMeters: Double, secondsPerKilometer: Double, segmentIndex: Int) {
        self.id = distanceMeters
        self.distanceMeters = distanceMeters
        self.distanceKilometers = distanceMeters / 1_000
        self.secondsPerKilometer = secondsPerKilometer
        self.segmentIndex = segmentIndex
    }

    static func build(from samples: [PaceSample]) -> [PaceChartPoint] {
        let sorted = samples.sorted { $0.distanceMeters < $1.distanceMeters }
        let points = sorted.map {
            PaceChartPoint(
                distanceMeters: $0.distanceMeters,
                secondsPerKilometer: $0.secondsPerKilometer,
                segmentIndex: $0.segmentIndex
            )
        }
        return movingAverage(points: points, radius: 2)
    }

    private static func movingAverage(points: [PaceChartPoint], radius: Int) -> [PaceChartPoint] {
        guard !points.isEmpty else { return [] }

        return points.indices.map { index in
            let segmentIndex = points[index].segmentIndex
            let window = points[max(0, index - radius)...min(points.count - 1, index + radius)]
                .filter { $0.segmentIndex == segmentIndex }
            let averagePace = window.map(\.secondsPerKilometer).reduce(0, +) / Double(window.count)
            return PaceChartPoint(
                distanceMeters: points[index].distanceMeters,
                secondsPerKilometer: averagePace,
                segmentIndex: points[index].segmentIndex
            )
        }
    }
}

// 심박 샘플도 거리 기준 포인트로 정규화해 차트에 쓴다.
private struct HeartRateChartPoint: Identifiable {
    let id: Double
    let distanceMeters: Double
    let distanceKilometers: Double
    let bpm: Double
    let segmentIndex: Int

    init(distanceMeters: Double, bpm: Double, segmentIndex: Int) {
        self.id = distanceMeters
        self.distanceMeters = distanceMeters
        self.distanceKilometers = distanceMeters / 1_000
        self.bpm = bpm
        self.segmentIndex = segmentIndex
    }

    static func build(from samples: [HeartRateSample]) -> [HeartRateChartPoint] {
        let normalized = samples.compactMap { sample -> HeartRateChartPoint? in
            guard let distanceMeters = sample.distanceMeters, let segmentIndex = sample.segmentIndex else { return nil }
            return HeartRateChartPoint(distanceMeters: distanceMeters, bpm: sample.bpm, segmentIndex: segmentIndex)
        }
        let sorted = normalized.sorted { $0.distanceMeters < $1.distanceMeters }
        return movingAverage(points: sorted, radius: 1)
    }

    private static func movingAverage(points: [HeartRateChartPoint], radius: Int) -> [HeartRateChartPoint] {
        guard !points.isEmpty else { return [] }

        return points.indices.map { index in
            let segmentIndex = points[index].segmentIndex
            let window = points[max(0, index - radius)...min(points.count - 1, index + radius)]
                .filter { $0.segmentIndex == segmentIndex }
            let averageHeartRate = window.map(\.bpm).reduce(0, +) / Double(window.count)
            return HeartRateChartPoint(
                distanceMeters: points[index].distanceMeters,
                bpm: averageHeartRate,
                segmentIndex: points[index].segmentIndex
            )
        }
    }
}

// 디버그 메뉴는 개발 중에 상세 화면 레이아웃을 빠르게 점검할 때 쓴다.
private struct DebugScenarioPanel: View {
    @ObservedObject var viewModel: RunDetailViewModel

    var body: some View {
        Menu {
            Button("실데이터") {
                Task {
                    await viewModel.applyDebugScenario(.live)
                }
            }
            Button("정상 메트릭") {
                Task {
                    await viewModel.applyDebugScenario(.completeMetrics)
                }
            }
            Button("pause 포함") {
                Task {
                    await viewModel.applyDebugScenario(.pausedWorkout)
                }
            }
            Button("빈 경로") {
                Task {
                    await viewModel.applyDebugScenario(.missingRoute)
                }
            }
            Button("빈 심박") {
                Task {
                    await viewModel.applyDebugScenario(.missingHeartRate)
                }
            }
            Button("고급 메트릭 없음") {
                Task {
                    await viewModel.applyDebugScenario(.missingAdvancedMetrics)
                }
            }
            Button("빈 상세") {
                Task {
                    await viewModel.applyDebugScenario(.empty)
                }
            }
        } label: {
            Label("테스트 데이터", systemImage: "ladybug")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
        }
    }
}

// 차트에서 선택한 위치의 여러 메트릭을 한 번에 묶는다.
private struct SelectedMetrics {
    let distanceMeters: Double
    let elapsed: TimeInterval
    let paceSecondsPerKilometer: Double?
    let heartRate: Double?
    let cadence: Double?
    let altitudeMeters: Double?

    var distanceKilometers: Double {
        distanceMeters / 1_000
    }

    var distanceText: String {
        distanceKilometers.formatted(.number.precision(.fractionLength(2))) + " km"
    }

    var elapsedText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: elapsed) ?? "-"
    }

    var paceText: String {
        guard let paceSecondsPerKilometer else { return "-" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return (formatter.string(from: paceSecondsPerKilometer) ?? "-") + "/km"
    }

    var heartRateText: String {
        guard let heartRate else { return "-" }
        return heartRate.formatted(.number.precision(.fractionLength(0))) + " bpm"
    }

    var cadenceText: String? {
        guard let cadence else { return nil }
        return cadence.formatted(.number.precision(.fractionLength(0))) + " spm"
    }

    var altitudeText: String? {
        guard let altitudeMeters else { return nil }
        return altitudeMeters.formatted(.number.precision(.fractionLength(0))) + " m"
    }

    func paceScaledForChart(heartRateRange: ClosedRange<Double>, paceRange: ClosedRange<Double>) -> Double? {
        guard let paceSecondsPerKilometer else {
            return nil
        }

        let paceSpan = max(paceRange.upperBound - paceRange.lowerBound, 0.1)
        let ratio = (paceRange.upperBound - paceSecondsPerKilometer) / paceSpan
        return heartRateRange.lowerBound + ratio * (heartRateRange.upperBound - heartRateRange.lowerBound)
    }
}

// 예상 기록 계산 공식을 사용자에게 설명하는 보조 화면이다.
private struct PredictionMethodView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("현재 예측 기록은 최근 120일 러닝 중 1km 이상 기록들을 기준으로 계산합니다.")
                    Text("각 러닝에 Riegel 공식을 적용합니다.")
                    Text("공식: 예측시간 = 기록시간 × (목표거리 / 기록거리)^1.06")
                    Text("5K, 10K, 하프, 풀 각각에 대해 계산한 뒤 가장 빠른 예측값을 보여줍니다.")
                    Text("정확한 레이스 예측이라기보다, 최근 러닝 폼을 빠르게 보는 참고값으로 보는 편이 맞습니다.")
                }
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))
                .padding(20)
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
            .navigationTitle("예측 방식")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 신발 연결 섹션은 러닝과 장비를 매칭하는 역할을 맡는다.
private struct RunGearSection: View {
    let run: RunningWorkout
    @EnvironmentObject private var shoeStore: ShoeStore

    var body: some View {
        DetailSection(title: "착용 신발") {
            if shoeStore.shoes.isEmpty {
                Text("신발 탭에서 러닝화를 추가하면 이 러닝에 연결할 수 있습니다.")
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(shoeStore.shoe(for: run.id)?.displayName ?? "신발 미선택")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(shoeStore.shoe(for: run.id)?.brandModelText ?? "이 러닝에 어떤 신발을 신었는지 기록해두세요.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Menu {
                        Button("선택 해제") {
                            shoeStore.assign(nil, to: run.id)
                        }
                        ForEach(shoeStore.shoes) { shoe in
                            Button(shoe.displayName) {
                                shoeStore.assign(shoe.id, to: run.id)
                            }
                        }
                    } label: {
                        Text("선택")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                }
            }
        }
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
                    SummaryCard(title: "변화", value: changeText, detail: "\(selectedRange.label) 기준")
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
        case .sixMonths: return "6개월"
        case .oneYear: return "1년"
        case .all: return "전체"
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

    private var points: [TrainingTrendPoint] {
        TrainingTrendPoint.build(from: runs)
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
        return sign + abs(delta).formatted(.number.precision(.fractionLength(1))) + " km"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SummaryCard(title: "현재 상태", value: summary.trainingStatus, detail: summary.trainingStatusDetail)
                    SummaryCard(
                        title: "최근 7일 거리",
                        value: latestPoint.map { formatKilometers($0.distanceKilometers) } ?? "-",
                        detail: latestPoint.map(\.label) ?? "데이터 없음"
                    )
                    SummaryCard(
                        title: "직전 7일 거리",
                        value: previousPoint.map { formatKilometers($0.distanceKilometers) } ?? "-",
                        detail: previousPoint.map(\.label) ?? "데이터 없음"
                    )
                    SummaryCard(title: "주간 변화", value: changeText, detail: "최근 7일 vs 직전 7일")
                }

                DetailSection(title: "주간 훈련량") {
                    if points.isEmpty {
                        Text("훈련 추세를 계산할 러닝 데이터가 부족합니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        Chart(points) { point in
                            BarMark(
                                x: .value("주간", point.label),
                                y: .value("거리", point.distanceKilometers)
                            )
                            .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                            .cornerRadius(6)
                        }
                        .frame(height: 220)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(.white.opacity(0.08))
                                AxisValueLabel {
                                    if let distance = value.as(Double.self) {
                                        Text(distance.formatted(.number.precision(.fractionLength(0))) + " km")
                                            .foregroundStyle(.white.opacity(0.45))
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisTick()
                                    .foregroundStyle(.white.opacity(0.35))
                                AxisValueLabel {
                                    if let label = value.as(String.self) {
                                        Text(label)
                                            .foregroundStyle(.white.opacity(0.68))
                                    }
                                }
                            }
                        }
                        .chartPlotStyle { plotArea in
                            plotArea.background(.clear)
                        }
                    }
                }

                DetailSection(title: "계산 방식") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("훈련 추세는 최근 7일 러닝 거리와 직전 7일 러닝 거리를 비교해 계산합니다.")
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

private struct TrainingTrendPoint: Identifiable {
    let id: Date
    let startDate: Date
    let endDate: Date
    let distanceKilometers: Double

    var label: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter.string(from: startDate)
    }

    static func build(from runs: [RunningWorkout], weeks: Int = 8) -> [TrainingTrendPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let firstWeekStart = calendar.date(byAdding: .day, value: -(weeks * 7) + 1, to: today) else { return [] }

        return (0..<weeks).compactMap { offset in
            guard
                let startDate = calendar.date(byAdding: .day, value: offset * 7, to: firstWeekStart),
                let endDate = calendar.date(byAdding: .day, value: 7, to: startDate)
            else {
                return nil
            }

            let distanceKilometers = runs
                .filter { $0.startDate >= startDate && $0.startDate < endDate }
                .reduce(0) { $0 + $1.distanceInKilometers }

            return TrainingTrendPoint(
                id: startDate,
                startDate: startDate,
                endDate: endDate,
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
        case .half: return "하프"
        case .marathon: return "풀"
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

private enum RunShareTemplate: String, CaseIterable, Identifiable {
    case sticker
    case square
    case story

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sticker:
            return "스티커"
        case .square:
            return "정사각형"
        case .story:
            return "스토리"
        }
    }

    var descriptionText: String {
        switch self {
        case .sticker:
            return "투명 배경 PNG로 복사/공유하기 좋습니다."
        case .square:
            return "피드용 카드에 가까운 정사각형 이미지입니다."
        case .story:
            return "세로 비율이 긴 스토리형 포스터입니다."
        }
    }

    var canvasSize: CGSize {
        switch self {
        case .sticker:
            return CGSize(width: 520, height: 860)
        case .square:
            return CGSize(width: 1080, height: 1080)
        case .story:
            return CGSize(width: 1080, height: 1680)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .sticker:
            return 0
        case .square:
            return 34
        case .story:
            return 0
        }
    }

    func previewHeight(for width: CGFloat) -> CGFloat {
        width * (canvasSize.height / canvasSize.width)
    }

    var composerPreviewWidth: CGFloat {
        switch self {
        case .sticker:
            return 190
        case .square:
            return 208
        case .story:
            return 164
        }
    }
}

private enum RunShareField: String, CaseIterable, Identifiable {
    case route
    case date
    case environment
    case distance
    case duration
    case pace
    case heartRate
    case cadence
    case shoe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .route:
            return "경로"
        case .date:
            return "날짜"
        case .environment:
            return "실내/실외"
        case .distance:
            return "거리"
        case .duration:
            return "시간"
        case .pace:
            return "페이스"
        case .heartRate:
            return "심박"
        case .cadence:
            return "케이던스"
        case .shoe:
            return "신발"
        }
    }

    var systemImage: String {
        switch self {
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
        case .heartRate:
            return "heart.fill"
        case .cadence:
            return "metronome"
        case .shoe:
            return "shoeprints.fill"
        }
    }
}

private struct RunShareMetric: Identifiable {
    let field: RunShareField
    let title: String
    let value: String

    var id: RunShareField { field }
}

private let runOnlyShareAccent = Color(red: 0.29, green: 0.88, blue: 0.63)
private let runOnlyShareAccentDark = Color(red: 0.15, green: 0.71, blue: 0.49)

private struct RunShareComposerView: View {
    let run: RunningWorkout
    let detail: RunDetail

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: RunShareTemplate = .sticker
    @State private var enabledFields: Set<RunShareField> = [.route, .distance, .duration, .pace]
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var exportStatusMessage: String?
    @State private var exportErrorMessage: String?
    private let hiddenFields: Set<RunShareField> = [.environment, .shoe]

    private var availableFields: [RunShareField] {
        RunShareField.allCases.filter { !hiddenFields.contains($0) && isFieldAvailable($0) }
    }

    private var effectiveFields: Set<RunShareField> {
        enabledFields.intersection(Set(availableFields))
    }

    private var previewWidth: CGFloat {
        min(UIScreen.main.bounds.width - 32, selectedTemplate.composerPreviewWidth)
    }

    private var previewHeight: CGFloat {
        selectedTemplate.previewHeight(for: previewWidth)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("미리보기")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(selectedTemplate.label)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.62))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                )
                        }

                        ZStack {
                            if selectedTemplate == .sticker {
                                TransparentPreviewBackground()
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            }

                            RunShareArtworkView(
                                run: run,
                                detail: detail,
                                template: selectedTemplate,
                                enabledFields: effectiveFields
                            )
                            .frame(
                                width: selectedTemplate.canvasSize.width,
                                height: selectedTemplate.canvasSize.height
                            )
                            .scaleEffect(previewWidth / selectedTemplate.canvasSize.width, anchor: .topLeading)
                            .frame(
                                width: previewWidth,
                                height: previewHeight,
                                alignment: .topLeading
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: previewHeight)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("템플릿")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Picker("공유 템플릿", selection: $selectedTemplate) {
                                ForEach(RunShareTemplate.allCases) { template in
                                    Text(template.label).tag(template)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text(selectedTemplate.descriptionText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }

                        Divider()
                            .overlay(Color.white.opacity(0.08))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("포함 데이터")
                                .font(.headline)
                                .foregroundStyle(.white)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(availableFields) { field in
                                    Button {
                                        toggleField(field)
                                    } label: {
                                        HStack(spacing: 7) {
                                            Image(systemName: field.systemImage)
                                            Text(field.label)
                                                .lineLimit(1)
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(
                                                    effectiveFields.contains(field)
                                                        ? Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.22)
                                                        : Color.white.opacity(0.06)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(
                                                    effectiveFields.contains(field)
                                                        ? Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.32)
                                                        : Color.white.opacity(0.08),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if let exportStatusMessage {
                            Text(exportStatusMessage)
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                        }

                        if let exportErrorMessage {
                            Text(exportErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        Text("투명 스티커는 앱마다 alpha 처리 방식이 다를 수 있어 실제 업로드 동작은 기기에서 확인하는 것이 가장 정확합니다.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle("공유 이미지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await saveToPhotoLibrary()
                        }
                    } label: {
                        shareActionLabel(
                            title: "저장",
                            systemImage: "square.and.arrow.down",
                            foregroundColor: .white,
                            backgroundColor: Color.white.opacity(0.08)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        copyPNGToPasteboard()
                    } label: {
                        shareActionLabel(
                            title: "복사",
                            systemImage: "doc.on.doc",
                            foregroundColor: .white,
                            backgroundColor: Color.white.opacity(0.08)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        shareImage()
                    } label: {
                        shareActionLabel(
                            title: "공유",
                            systemImage: "square.and.arrow.up",
                            foregroundColor: .black,
                            backgroundColor: Color(red: 0.29, green: 0.88, blue: 0.63)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
        }
    }

    private func toggleField(_ field: RunShareField) {
        if effectiveFields.contains(field) {
            enabledFields.remove(field)
        } else {
            enabledFields.insert(field)
        }
    }

    @ViewBuilder
    private func shareActionLabel(
        title: String,
        systemImage: String,
        foregroundColor: Color,
        backgroundColor: Color
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor)
            )
    }

    private func shareImage() {
        do {
            let url = try exportShareImageFile()
            shareItems = [url]
            exportErrorMessage = nil
            exportStatusMessage = "공유용 PNG를 준비했습니다."
            showingShareSheet = true
        } catch {
            exportStatusMessage = nil
            exportErrorMessage = error.localizedDescription
        }
    }

    private func copyPNGToPasteboard() {
        do {
            let data = try renderPNGData()
            UIPasteboard.general.setItems([[UTType.png.identifier: data]])
            exportErrorMessage = nil
            exportStatusMessage = "PNG를 클립보드에 복사했습니다."
        } catch {
            exportStatusMessage = nil
            exportErrorMessage = error.localizedDescription
        }
    }

    private func saveToPhotoLibrary() async {
        do {
            let data = try renderPNGData()
            let authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard authorizationStatus == .authorized || authorizationStatus == .limited else {
                exportStatusMessage = nil
                exportErrorMessage = "사진 앱 저장 권한이 필요합니다."
                return
            }

            try await PhotoLibraryPNGWriter.save(data)
            exportErrorMessage = nil
            exportStatusMessage = "카메라롤에 PNG를 저장했습니다."
        } catch {
            exportStatusMessage = nil
            exportErrorMessage = error.localizedDescription
        }
    }

    private func exportShareImageFile() throws -> URL {
        let data = try renderPNGData()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let filename = "RunOnly-Share-\(formatter.string(from: run.startDate))-\(selectedTemplate.rawValue).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func renderPNGData() throws -> Data {
        let size = selectedTemplate.canvasSize
        let content = RunShareArtworkView(
            run: run,
            detail: detail,
            template: selectedTemplate,
            enabledFields: effectiveFields
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw RunShareExportError.renderFailed
        }

        return data
    }

    private func isFieldAvailable(_ field: RunShareField) -> Bool {
        switch field {
        case .route:
            return !detail.route.isEmpty
        case .heartRate:
            return averageHeartRateText != nil
        case .cadence:
            return averageCadenceText != nil
        case .shoe, .environment:
            return false
        case .date, .distance, .duration, .pace:
            return true
        }
    }

    private var averageHeartRateText: String? {
        guard !detail.heartRates.isEmpty else { return nil }
        let average = detail.heartRates.map(\.bpm).reduce(0, +) / Double(detail.heartRates.count)
        return average.formatted(.number.precision(.fractionLength(0))) + " bpm"
    }

    private var averageCadenceText: String? {
        let weightedCadence = detail.splits.reduce(into: (weighted: 0.0, duration: 0.0)) { partial, split in
            guard let cadence = split.averageCadence else { return }
            partial.weighted += cadence * split.duration
            partial.duration += split.duration
        }

        if weightedCadence.duration > 0 {
            let average = weightedCadence.weighted / weightedCadence.duration
            return average.formatted(.number.precision(.fractionLength(0))) + " spm"
        }

        guard !detail.runningMetrics.cadence.isEmpty else { return nil }
        let average = detail.runningMetrics.cadence.map(\.value).reduce(0, +) / Double(detail.runningMetrics.cadence.count)
        return average.formatted(.number.precision(.fractionLength(0))) + " spm"
    }
}

private enum RunShareExportError: LocalizedError {
    case renderFailed
    case photoSaveFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "공유 이미지를 렌더링하지 못했습니다."
        case .photoSaveFailed:
            return "사진 앱에 저장하지 못했습니다."
        }
    }
}

private enum PhotoLibraryPNGWriter {
    static func save(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: RunShareExportError.photoSaveFailed)
                }
            })
        }
    }
}

private struct RunShareArtworkView: View {
    let run: RunningWorkout
    let detail: RunDetail
    let template: RunShareTemplate
    let enabledFields: Set<RunShareField>

    private var metrics: [RunShareMetric] {
        var items: [RunShareMetric] = []

        if enabledFields.contains(.distance) {
            items.append(RunShareMetric(field: .distance, title: "거리", value: run.distanceText))
        }
        if enabledFields.contains(.duration) {
            items.append(RunShareMetric(field: .duration, title: "시간", value: run.durationText))
        }
        if enabledFields.contains(.pace) {
            items.append(RunShareMetric(field: .pace, title: "페이스", value: run.paceText))
        }
        if enabledFields.contains(.heartRate), let averageHeartRateText {
            items.append(RunShareMetric(field: .heartRate, title: "평균 심박", value: averageHeartRateText))
        }
        if enabledFields.contains(.cadence), let averageCadenceText {
            items.append(RunShareMetric(field: .cadence, title: "평균 케이던스", value: averageCadenceText))
        }

        return items
    }

    private var routeHeight: CGFloat {
        switch template {
        case .sticker:
            return 315
        case .square:
            return 230
        case .story:
            return 520
        }
    }

    private var contentPadding: CGFloat {
        switch template {
        case .sticker:
            return 24
        case .square:
            return 40
        case .story:
            return 48
        }
    }

    private var headerBrandFontSize: CGFloat {
        switch template {
        case .sticker:
            return 18
        case .square:
            return 20
        case .story:
            return 24
        }
    }

    private var metricColumns: [GridItem] {
        let spacing: CGFloat = template == .sticker ? 8 : 12
        return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .leading), count: 3)
    }

    private var stickerRouteWidth: CGFloat {
        472
    }

    private var metricSpacing: CGFloat {
        switch template {
        case .sticker:
            return 12
        case .square:
            return 12
        case .story:
            return 16
        }
    }

    private var fallbackMetricFontSize: CGFloat {
        switch template {
        case .sticker:
            return 36
        case .square:
            return 34
        case .story:
            return 40
        }
    }

    var body: some View {
        Group {
            if template == .sticker {
                stickerLayout
            } else {
                standardLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var header: some View {
        if template == .sticker {
            Text("RUNONLY")
                .font(.system(size: headerBrandFontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(runOnlyShareAccent)
                .tracking(1.2)
                .shadow(color: runOnlyShareAccent.opacity(0.26), radius: 10, y: 2)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            HStack {
                Text("RUNONLY")
                    .font(.system(size: headerBrandFontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(runOnlyShareAccent)
                    .tracking(0.8)
                    .shadow(color: runOnlyShareAccent.opacity(0.26), radius: 10, y: 2)
                Spacer()
            }
        }
    }

    private var standardLayout: some View {
        ZStack(alignment: .topLeading) {
            RunShareTemplateBackground(template: template)
                .clipShape(
                    RoundedRectangle(cornerRadius: template.cornerRadius, style: .continuous)
                )

            VStack(alignment: .leading, spacing: template == .story ? 20 : 14) {
                header

                if enabledFields.contains(.route) {
                    RunShareRouteCanvas(route: detail.route)
                        .frame(maxWidth: .infinity)
                        .frame(height: routeHeight)
                }

                if !metrics.isEmpty {
                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: metricSpacing) {
                        ForEach(metrics) { metric in
                            RunShareMetricTile(metric: metric, template: template, centered: false)
                        }
                    }
                }

                if !metaPills.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: template == .story ? 220 : 132), alignment: .leading)], spacing: 10) {
                        ForEach(metaPills, id: \.self) { item in
                            ShareMetaPill(text: item, centered: false)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(contentPadding)
        }
    }

    private var stickerLayout: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)
                .padding(.bottom, 6)

            if enabledFields.contains(.route) {
                RunShareRouteCanvas(route: detail.route)
                    .frame(width: stickerRouteWidth, height: routeHeight)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 18)
            }

            if !metrics.isEmpty {
                VStack(spacing: 4) {
                    ForEach(metrics) { metric in
                        RunShareMetricTile(metric: metric, template: template, centered: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, metaPills.isEmpty ? 0 : 10)
            }

            if !metaPills.isEmpty {
                VStack(spacing: 4) {
                    ForEach(metaPills, id: \.self) { item in
                        ShareMetaPill(text: item, centered: true)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
        }
        .padding(contentPadding)
    }

    private var metaPills: [String] {
        var items: [String] = []

        if enabledFields.contains(.date) {
            items.append(run.detailDateText)
        }

        return items
    }

    private var averageHeartRateText: String? {
        guard !detail.heartRates.isEmpty else { return nil }
        let average = detail.heartRates.map(\.bpm).reduce(0, +) / Double(detail.heartRates.count)
        return average.formatted(.number.precision(.fractionLength(0))) + " bpm"
    }

    private var averageCadenceText: String? {
        let weightedCadence = detail.splits.reduce(into: (weighted: 0.0, duration: 0.0)) { partial, split in
            guard let cadence = split.averageCadence else { return }
            partial.weighted += cadence * split.duration
            partial.duration += split.duration
        }

        if weightedCadence.duration > 0 {
            let average = weightedCadence.weighted / weightedCadence.duration
            return average.formatted(.number.precision(.fractionLength(0))) + " spm"
        }

        guard !detail.runningMetrics.cadence.isEmpty else { return nil }
        let average = detail.runningMetrics.cadence.map(\.value).reduce(0, +) / Double(detail.runningMetrics.cadence.count)
        return average.formatted(.number.precision(.fractionLength(0))) + " spm"
    }
}

private struct RunShareTemplateBackground: View {
    let template: RunShareTemplate

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.10),
                    Color(red: 0.14, green: 0.15, blue: 0.19),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(runOnlyShareAccent.opacity(template == .story ? 0.22 : 0.14))
                .frame(width: template == .story ? 560 : 320)
                .blur(radius: 24)
                .offset(x: 180, y: -220)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: template == .story ? 420 : 260)
                .blur(radius: 18)
                .offset(x: -160, y: 260)
        }
    }
}

private struct RunShareRouteCanvas: View {
    let route: [RunRoutePoint]

    var body: some View {
        GeometryReader { geometry in
            let projection = RouteProjection(route: route, size: geometry.size, padding: 18)

            ZStack {
                if let projection {
                    Path { path in
                        guard let first = projection.points.first else { return }
                        path.move(to: first)
                        for point in projection.points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [
                                runOnlyShareAccent,
                                runOnlyShareAccentDark
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: runOnlyShareAccent.opacity(0.28), radius: 18, y: 10)
                } else {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.44))
                                Text("경로 없음")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.44))
                            }
                        )
                }
            }
        }
    }
}

private struct RouteProjection {
    let points: [CGPoint]
    let startPoint: CGPoint
    let endPoint: CGPoint

    init?(route: [RunRoutePoint], size: CGSize, padding: CGFloat) {
        guard route.count >= 2 else { return nil }

        let latitudes = route.map(\.latitude)
        let longitudes = route.map(\.longitude)

        guard
            let minLatitude = latitudes.min(),
            let maxLatitude = latitudes.max(),
            let minLongitude = longitudes.min(),
            let maxLongitude = longitudes.max()
        else {
            return nil
        }

        let longitudeSpan = max(maxLongitude - minLongitude, 0.00001)
        let latitudeSpan = max(maxLatitude - minLatitude, 0.00001)
        let availableWidth = max(size.width - padding * 2, 1)
        let availableHeight = max(size.height - padding * 2, 1)
        let scale = min(availableWidth / longitudeSpan, availableHeight / latitudeSpan)
        let contentWidth = longitudeSpan * scale
        let contentHeight = latitudeSpan * scale
        let offsetX = (size.width - contentWidth) / 2
        let offsetY = (size.height - contentHeight) / 2

        let projectedPoints = route.map { point in
            CGPoint(
                x: offsetX + (point.longitude - minLongitude) * scale,
                y: offsetY + (maxLatitude - point.latitude) * scale
            )
        }

        guard let startPoint = projectedPoints.first, let endPoint = projectedPoints.last else {
            return nil
        }

        self.points = projectedPoints
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
}

private struct RunShareMetricTile: View {
    let metric: RunShareMetric
    let template: RunShareTemplate
    let centered: Bool

    private var valueFontSize: CGFloat {
        switch template {
        case .sticker:
            return 64
        case .square:
            return 38
        case .story:
            return 44
        }
    }

    var body: some View {
        Text(metric.value)
            .font(.system(size: valueFontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .shadow(color: .black.opacity(0.28), radius: 6, y: 2)
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

private struct ShareMetaPill: View {
    let text: String
    let centered: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(runOnlyShareAccent.opacity(0.94))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

private struct TransparentPreviewBackground: View {
    private let tileSize: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.04)))

            let rows = Int(ceil(size.height / tileSize))
            let columns = Int(ceil(size.width / tileSize))

            for row in 0...rows {
                for column in 0...columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.08)))
                }
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// 신발 탭은 등록된 러닝화와 누적 사용량을 관리한다.
private struct ShoesTabView: View {
    let runs: [RunningWorkout]
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingAddShoe = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if shoeStore.shoes.isEmpty {
                        DetailSection(title: "신발") {
                            Text("러닝화를 등록하면 신발별 누적 거리와 남은 수명을 볼 수 있습니다.")
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    } else {
                        VStack(spacing: 14) {
                            ForEach(shoeStore.shoes) { shoe in
                                NavigationLink {
                                    ShoeDetailView(shoe: shoe, runs: runs)
                                } label: {
                                    ShoeSummaryCard(
                                        shoe: shoe,
                                        distanceKilometers: shoeStore.distance(for: shoe.id, runs: runs),
                                        runCount: shoeStore.runCount(for: shoe.id)
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
            .navigationTitle("신발")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("추가") {
                        showingAddShoe = true
                    }
                }
            }
            .sheet(isPresented: $showingAddShoe) {
                AddShoeView()
                    .environmentObject(shoeStore)
            }
        }
    }
}

// 설정 탭은 권한 설명, 저장 정책, 법적 고지, 지원 경로를 모아둔다.
private struct SettingsTabView: View {
    @EnvironmentObject private var shoeStore: ShoeStore
    @EnvironmentObject private var appSettings: AppSettingsStore
    @State private var backupURL: URL?
    @State private var backupErrorMessage: String?
    @State private var backupStatusMessage: String?
    @State private var showingImportOptions = false
    @State private var showingBackupImporter = false
    @State private var showingDeleteShoeDataConfirmation = false
    @State private var selectedImportStrategy: ShoeImportStrategy = .merge

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DetailSection(title: "표시") {
                        VStack(spacing: 14) {
                            Toggle(isOn: $appSettings.defaultAppleOnlyFilter) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Apple 운동 앱 기록만 보기 기본값")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("앱을 열었을 때 홈/기록 탭에서 기본으로 적용됩니다.")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.58))
                                }
                            }
                            .tint(Color(red: 0.29, green: 0.88, blue: 0.63))

                            SettingInfoRow(title: "거리 단위", value: "km")
                            SettingInfoRow(title: "페이스 단위", value: "/km")
                        }
                    }

                    DetailSection(title: "정책 및 지원") {
                        VStack(spacing: 12) {
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

                    DetailSection(title: "신발 데이터") {
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
                                    backupStatusMessage = "백업 파일을 준비했습니다."
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

                    DetailSection(title: "데이터 및 권한") {
                        VStack(alignment: .leading, spacing: 14) {
                            SettingInfoRow(title: "권한", value: "HealthKit 읽기")
                            SettingInfoRow(title: "네트워크 업로드", value: "없음")
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
                            Text("이 앱은 Apple 건강 데이터 중 러닝과 관련된 항목만 읽습니다. 현재는 서버 업로드 없이 기기 안에서만 표시합니다.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }

                    DetailSection(title: "고지") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("이 앱은 러닝 기록을 보기 쉽게 정리하는 용도이며, 의료적 판단이나 진단을 위한 앱이 아닙니다.")
                            Text("VO2 Max, 예상 기록, 훈련 추세는 참고용 추정치이며 실제 경기력과 다를 수 있습니다.")
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
            }
            .background(AppBackground())
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.large)
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
            .confirmationDialog("기존 신발데이터 삭제", isPresented: $showingDeleteShoeDataConfirmation, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    shoeStore.clearAllData()
                    backupURL = nil
                    backupErrorMessage = nil
                    backupStatusMessage = "기존 신발데이터를 삭제했습니다."
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("등록한 신발 정보와 러닝 연결 정보가 모두 삭제됩니다. HealthKit 원본 러닝 데이터는 삭제되지 않습니다.")
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
}

// 개인정보처리방침은 앱 안에서도 바로 읽을 수 있게 별도 화면으로 제공한다.
private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "개요") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(AppMetadata.displayName)은 Apple 건강의 러닝 데이터를 iPhone에서 분석하고 보기 쉽게 정리하는 앱입니다.")
                        Text("계정 생성, 광고 추적, 외부 분석 SDK 없이 동작하며, 현재는 서버로 데이터를 업로드하지 않습니다.")
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
                        Text("신발 데이터, 설정값, PR 계산 결과 같은 보조 데이터는 기기 내부 저장소에만 저장됩니다.")
                        Text("HealthKit에서 읽은 원본 데이터를 서버로 복제하지 않으며, 앱이 저장하는 보조 파일은 자동 클라우드 백업 대상에서 제외됩니다.")
                        Text("신발 백업 파일은 사용자가 직접 공유 버튼을 눌렀을 때만 외부 앱으로 전달됩니다.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "문의") {
                    VStack(alignment: .leading, spacing: 12) {
                        Link("지원 메일 보내기", destination: AppMetadata.supportMailURL)
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
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.38))
        }
    }
}

// 설정 정보의 제목/값 행은 긴 값도 줄바꿈해서 표시할 수 있게 만든다.
private struct SettingInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}

// 신발 목록 카드 하나는 누적 거리와 교체까지 남은 거리를 요약한다.
private struct ShoeSummaryCard: View {
    let shoe: RunningShoe
    let distanceKilometers: Double
    let runCount: Int

    private var totalKilometers: Double {
        shoe.startMileageKilometers + distanceKilometers
    }

    private var usageRatio: Double {
        min(totalKilometers / max(shoe.retirementKilometers, 1), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shoe.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(shoe.brandModelText)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.4))
            }

            HStack(spacing: 12) {
                RunMetricPill(title: "누적", value: formatKilometers(totalKilometers))
                RunMetricPill(title: "남은 거리", value: formatKilometers(max(shoe.retirementKilometers - totalKilometers, 0)))
                RunMetricPill(title: "러닝 수", value: "\(runCount)회")
            }

            ProgressView(value: usageRatio)
                .tint(usageRatio >= 0.8 ? .orange : Color(red: 0.29, green: 0.88, blue: 0.63))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
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
                HStack(spacing: 12) {
                    SummaryCard(title: "누적 거리", value: formatKilometers(totalKilometers), detail: "시작 거리 포함")
                    SummaryCard(title: "목표 수명", value: formatKilometers(currentShoe.retirementKilometers), detail: currentShoe.brandModelText)
                }

                HStack(spacing: 12) {
                    SummaryCard(title: "남은 거리", value: formatKilometers(max(currentShoe.retirementKilometers - totalKilometers, 0)), detail: "교체까지 남은 거리")
                    SummaryCard(title: "착용 러닝", value: "\(assignedRuns.count)회", detail: "현재 불러온 러닝 기준")
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

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("별칭", text: $nickname)
                    TextField("브랜드", text: $brand)
                    TextField("모델", text: $model)
                }

                Section("마일리지") {
                    TextField("시작 거리 (km)", value: $startMileage, format: .number)
                        .keyboardType(.decimalPad)
                    Text("단위는 km입니다. 이미 다른 앱이나 실제 사용으로 누적된 거리가 있다면 입력하고, 새 신발이면 0으로 두면 됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("목표 수명 거리 (km)", value: $retirementMileage, format: .number)
                        .keyboardType(.decimalPad)
                    Text("단위는 km입니다. 교체를 고려할 기준 거리이며, 보통 500~800km 범위에서 잡습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(existingShoe == nil ? "신발 추가" : "신발 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(existingShoe == nil ? "저장" : "완료") {
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

// 신발 정보와 러닝 매핑은 별도 파일에 저장해 자동 백업 대상에서 제외한다.
@MainActor
final class ShoeStore: ObservableObject {
    @Published private(set) var shoes: [RunningShoe] = []
    @Published private(set) var assignments: [ShoeAssignmentRecord] = []

    private let storageFilename = "shoe-store.json"

    init() {
        load()
    }

    func addShoe(_ shoe: RunningShoe) {
        shoes.insert(shoe, at: 0)
        save()
    }

    func updateShoe(_ shoe: RunningShoe) {
        guard let index = shoes.firstIndex(where: { $0.id == shoe.id }) else { return }
        shoes[index] = shoe
        save()
    }

    func shoe(for runID: UUID) -> RunningShoe? {
        guard let shoeID = assignments.first(where: { $0.runID == runID })?.shoeID else { return nil }
        return shoes.first(where: { $0.id == shoeID })
    }

    func assign(_ shoeID: UUID?, to runID: UUID) {
        assignments.removeAll { $0.runID == runID }
        if let shoeID {
            assignments.append(ShoeAssignmentRecord(runID: runID, shoeID: shoeID))
        }
        save()
    }

    func clearAllData() {
        shoes = []
        assignments = []
        save()
    }

    func distance(for shoeID: UUID, runs allRuns: [RunningWorkout]) -> Double {
        self.runs(for: shoeID, in: allRuns).reduce(0) { $0 + $1.distanceInKilometers }
    }

    func runCount(for shoeID: UUID) -> Int {
        assignments.filter { $0.shoeID == shoeID }.count
    }

    func runs(for shoeID: UUID, in runs: [RunningWorkout]) -> [RunningWorkout] {
        let runIDs = assignments.filter { $0.shoeID == shoeID }.map(\.runID)
        return runs.filter { runIDs.contains($0.id) }.sorted(by: { $0.startDate > $1.startDate })
    }

    func exportBackupFile() throws -> URL {
        let payload = ShoeBackupPayload(
            schemaVersion: ShoeBackupPayload.currentSchemaVersion,
            exportedAt: .now,
            appVersion: AppMetadata.versionText,
            assignmentReference: "healthkit_workout_uuid",
            shoes: shoes,
            assignments: assignments
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(payload)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let filename = "RunOnly-ShoeBackup-\(formatter.string(from: .now)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    func importBackupFile(from url: URL, strategy: ShoeImportStrategy) throws -> ShoeImportSummary {
        let didAccessSecurityScopedResource = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload: ShoeBackupPayload
        if let decoded = try? decoder.decode(ShoeBackupPayload.self, from: data) {
            payload = decoded
        } else if let legacyPayload = try? decoder.decode(LegacyShoeBackupPayload.self, from: data) {
            payload = ShoeBackupPayload(
                schemaVersion: 0,
                exportedAt: legacyPayload.exportedAt,
                appVersion: "legacy",
                assignmentReference: "healthkit_workout_uuid",
                shoes: legacyPayload.shoes,
                assignments: legacyPayload.assignments
            )
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard payload.schemaVersion <= ShoeBackupPayload.currentSchemaVersion else {
            throw ShoeBackupError.unsupportedSchemaVersion(payload.schemaVersion)
        }

        let importedShoes = deduplicatedShoes(payload.shoes)
        guard !importedShoes.isEmpty else {
            throw ShoeBackupError.emptyBackup
        }

        let validShoeIDs = Set(importedShoes.map(\.id))
        let importedAssignments = deduplicatedAssignments(
            payload.assignments.filter { validShoeIDs.contains($0.shoeID) }
        )

        switch strategy {
        case .replace:
            shoes = importedShoes
            assignments = importedAssignments
        case .merge:
            var shoeMap = Dictionary(uniqueKeysWithValues: shoes.map { ($0.id, $0) })
            for shoe in importedShoes {
                shoeMap[shoe.id] = shoe
            }

            var assignmentMap = Dictionary(uniqueKeysWithValues: assignments.map { ($0.runID, $0) })
            for assignment in importedAssignments {
                assignmentMap[assignment.runID] = assignment
            }

            let mergedShoes = deduplicatedShoes(Array(shoeMap.values))
            let mergedShoeIDs = Set(mergedShoes.map(\.id))
            shoes = mergedShoes
            assignments = deduplicatedAssignments(
                Array(assignmentMap.values).filter { mergedShoeIDs.contains($0.shoeID) }
            )
        }

        save()
        return ShoeImportSummary(
            strategy: strategy,
            shoeCount: importedShoes.count,
            assignmentCount: importedAssignments.count
        )
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let snapshot = try? AppStorage.load(ShoeStoreSnapshot.self, from: storageFilename, decoder: decoder) else {
            shoes = []
            assignments = []
            return
        }

        shoes = snapshot.shoes
        assignments = snapshot.assignments
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let snapshot = ShoeStoreSnapshot(shoes: shoes, assignments: assignments)
        try? AppStorage.save(snapshot, to: storageFilename, encoder: encoder)
    }

    private func deduplicatedShoes(_ shoes: [RunningShoe]) -> [RunningShoe] {
        let unique = Dictionary(uniqueKeysWithValues: shoes.map { ($0.id, $0) })
        return unique.values.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.displayName < rhs.displayName
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func deduplicatedAssignments(_ assignments: [ShoeAssignmentRecord]) -> [ShoeAssignmentRecord] {
        let unique = Dictionary(uniqueKeysWithValues: assignments.map { ($0.runID, $0) })
        return Array(unique.values).sorted { $0.runID.uuidString < $1.runID.uuidString }
    }
}

// 수동 백업 파일은 공유용 JSON 포맷으로 만든다.
private struct ShoeBackupPayload: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let appVersion: String
    let assignmentReference: String
    let shoes: [RunningShoe]
    let assignments: [ShoeAssignmentRecord]
}

private struct LegacyShoeBackupPayload: Codable {
    let exportedAt: Date
    let shoes: [RunningShoe]
    let assignments: [ShoeAssignmentRecord]
}

enum ShoeImportStrategy {
    case merge
    case replace
}

struct ShoeImportSummary {
    let strategy: ShoeImportStrategy
    let shoeCount: Int
    let assignmentCount: Int

    var message: String {
        switch strategy {
        case .merge:
            return "신발 \(shoeCount)개와 연결 \(assignmentCount)건을 병합했습니다."
        case .replace:
            return "신발 \(shoeCount)개와 연결 \(assignmentCount)건으로 교체했습니다."
        }
    }
}

private enum ShoeBackupError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case emptyBackup

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "이 백업 파일은 더 새로운 형식(v\(version))이라 현재 앱에서 가져올 수 없습니다."
        case .emptyBackup:
            return "가져올 신발 데이터가 없습니다."
        }
    }
}

// 내부 저장용 스냅샷은 신발과 연결 정보를 한 번에 다룬다.
private struct ShoeStoreSnapshot: Codable {
    let shoes: [RunningShoe]
    let assignments: [ShoeAssignmentRecord]
}

// 앱 설정은 비민감 값만 UserDefaults에 저장한다.
@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var defaultAppleOnlyFilter: Bool {
        didSet {
            UserDefaults.standard.set(defaultAppleOnlyFilter, forKey: defaultAppleOnlyFilterKey)
        }
    }

    private let defaultAppleOnlyFilterKey = "runonly.settings.defaultAppleOnlyFilter"

    init() {
        if UserDefaults.standard.object(forKey: defaultAppleOnlyFilterKey) == nil {
            UserDefaults.standard.set(true, forKey: defaultAppleOnlyFilterKey)
        }
        self.defaultAppleOnlyFilter = UserDefaults.standard.bool(forKey: defaultAppleOnlyFilterKey)
    }
}

@MainActor
final class MileageGoalStore: ObservableObject {
    @Published var monthlyGoalKilometers: Double {
        didSet {
            UserDefaults.standard.set(monthlyGoalKilometers, forKey: monthlyGoalKilometersKey)
        }
    }

    private let monthlyGoalKilometersKey = "runonly.goals.monthlyKilometers"

    init() {
        let storedValue = UserDefaults.standard.double(forKey: monthlyGoalKilometersKey)
        if storedValue <= 0 {
            UserDefaults.standard.set(60.0, forKey: monthlyGoalKilometersKey)
        }
        self.monthlyGoalKilometers = UserDefaults.standard.double(forKey: monthlyGoalKilometersKey)
    }
}

// 모든 탭이 같은 분위기를 유지하도록 공통 배경을 분리했다.
private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.14, blue: 0.20),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
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
                        detail: "\(summary.runCount)회 러닝"
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

private func formatKilometers(_ kilometers: Double) -> String {
    kilometers.formatted(.number.precision(.fractionLength(1))) + " km"
}

private func formatDuration(_ seconds: Double) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = [.pad]
    return formatter.string(from: seconds) ?? "-"
}

private func formatSignedDuration(_ seconds: Double) -> String {
    let sign = seconds > 0 ? "+" : seconds < 0 ? "-" : ""
    return sign + formatDuration(abs(seconds))
}

// 미리보기는 앱 루트 화면만 빠르게 점검할 때 사용한다.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
