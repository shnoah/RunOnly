import Charts
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 홈 탭은 요약 카드와 최근 상태를 빠르게 보는 대시보드 역할을 맡는다.
struct RecordMonthHeader: View {
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
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        FeatureToneBadge(
                            text: "기록",
                            tint: Color(red: 0.42, green: 0.76, blue: 1.0),
                            foreground: Color(red: 0.82, green: 0.94, blue: 1.0)
                        )

                        if isLoading {
                            Text("불러오는 중")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }

                    Text(monthText)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .accessibilityLabel(Text(L10n.format("현재 선택 월: %@", monthText)))
                }

                Spacer(minLength: 12)

                if selectedDateText != nil {
                    Button("전체 보기", action: onClearDate)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                        .buttonStyle(.plain)
                }
            }

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
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color(red: 0.24, green: 0.45, blue: 0.82).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
        )
    }

    private var headerSubtitleText: String {
        if let selectedDateText {
            return L10n.format("%@ 기록만 보고 있어요", selectedDateText)
        }

        if isViewingCurrentMonth {
            return L10n.tr("이번 달 러닝을 한눈에 정리했어요")
        }

        return L10n.tr("월별로 러닝 기록을 둘러보세요")
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
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
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
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
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
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.18))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// 선택한 달의 거리/빈도/시간을 한눈에 보여주는 요약 카드다.
struct RecordMonthSummaryCard: View {
    let summary: RecordMonthSummary

    var body: some View {
        DetailSection(title: "이달 요약", systemImage: "calendar.badge.clock", tint: Color(red: 0.42, green: 0.76, blue: 1.0)) {
            ViewThatFits(in: .vertical) {
                HStack(spacing: 10) {
                    RecordSummaryMetricTile(
                        title: "거리",
                        value: formatKilometers(summary.totalDistanceKilometers),
                        detail: L10n.format("%d회 러닝", summary.runCount)
                    )
                    RecordSummaryMetricTile(
                        title: "빈도",
                        value: L10n.format("%d일", summary.runningDays),
                        detail: L10n.format("주 평균 %.1f회", summary.weeklyRunFrequency)
                    )
                    RecordSummaryMetricTile(
                        title: "시간",
                        value: formatDuration(summary.totalDuration),
                        detail: "월 누적"
                    )
                }

                VStack(spacing: 10) {
                    RecordSummaryMetricTile(
                        title: "거리",
                        value: formatKilometers(summary.totalDistanceKilometers),
                        detail: L10n.format("%d회 러닝", summary.runCount)
                    )
                    RecordSummaryMetricTile(
                        title: "빈도",
                        value: L10n.format("%d일", summary.runningDays),
                        detail: L10n.format("주 평균 %.1f회", summary.weeklyRunFrequency)
                    )
                    RecordSummaryMetricTile(
                        title: "시간",
                        value: formatDuration(summary.totalDuration),
                        detail: "월 누적"
                    )
                }
            }
        }
    }
}

struct RecordSummaryMetricTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(LocalizedStringKey(detail))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// 달력 시트는 특정 날짜 러닝만 빠르게 필터링할 때 사용한다.
struct RecordCalendarSheet: View {
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

                    DetailSection(title: "월간 체크", systemImage: "calendar.badge.clock", tint: Color(red: 0.42, green: 0.76, blue: 1.0)) {
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
struct RecordCalendarDayCell: View {
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
struct PersonalRecordsCard: View {
    let records: [PersonalRecordEntry]
    let pendingCandidates: [PersonalRecordCandidate]
    let isRefreshing: Bool
    let progress: Double?
    let onApproveCandidate: (PersonalRecordDistance) -> Void
    let onDismissCandidate: (PersonalRecordDistance) -> Void
    let onResetAndReloadRecords: () async -> Void

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
                            isRefreshingRecords: isRefreshing,
                            personalRecordProgress: progress,
                            onApproveCandidate: onApproveCandidate,
                            onDismissCandidate: onDismissCandidate,
                            onResetAndReloadRecords: onResetAndReloadRecords
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
struct PersonalRecordCell: View {
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
final class PersonalRecordRunLoaderViewModel: ObservableObject {
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

struct PersonalRecordRunDestinationView: View {
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
struct PersonalRecordsManagementView: View {
    let currentRecords: [PersonalRecordEntry]
    let pendingCandidates: [PersonalRecordCandidate]
    let isRefreshingRecords: Bool
    let personalRecordProgress: Double?
    let onApproveCandidate: (PersonalRecordDistance) -> Void
    let onDismissCandidate: (PersonalRecordDistance) -> Void
    let onResetAndReloadRecords: () async -> Void

    @State private var isResettingRecords = false

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
                        Text("1년보다 오래됐거나 데이터가 빈약한 더 빠른 후보 기록이 없습니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }

                // TEST-ONLY PR TOOL: 최고 기록 계산 안정화 확인용 임시 UI다.
                // 안정화 후 이 DetailSection과 관련 initializer 인자를 함께 제거하면 된다.
                DetailSection(title: "테스트 도구") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("최고 기록 캐시를 비우고 HealthKit 러닝을 처음부터 다시 읽습니다.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.64))

                        if isRefreshingRecords || isResettingRecords {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(.white)
                                Text(personalRecordProgressText)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        }

                        Button {
                            Task {
                                isResettingRecords = true
                                await onResetAndReloadRecords()
                                isResettingRecords = false
                            }
                        } label: {
                            Label("기록 초기화 및 다시읽기", systemImage: "arrow.clockwise.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
                        .disabled(isRefreshingRecords || isResettingRecords)
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("최고 기록")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var personalRecordProgressText: String {
        guard let personalRecordProgress else {
            return "최고 기록을 다시 읽는 중"
        }

        let percent = Int((personalRecordProgress * 100).rounded())
        return "최고 기록을 다시 읽는 중 \(percent)%"
    }
}

// 후보 기록과 현재 기록을 나란히 비교할 수 있게 만든다.
struct PersonalRecordCandidateRow: View {
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
                    Text("검토 대상 기록")
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
