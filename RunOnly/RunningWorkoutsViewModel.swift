import Combine
import Foundation

// 기록 탭에서 쓰는 월간 요약 정보다.
struct RecordMonthSummary {
    let monthStart: Date
    let runCount: Int
    let totalDistanceKilometers: Double
    let totalDuration: TimeInterval
    let runningDays: Int
    let weeklyRunFrequency: Double
}

struct MileageRangeSummary {
    let totalDistanceKilometers: Double
    let runCount: Int
    let helperText: String
    let isFullyLoaded: Bool
}

// 메인 목록과 대시보드에 필요한 러닝 데이터를 로드하고 가공한다.
@MainActor
final class RunningWorkoutsViewModel: ObservableObject {
    // 홈/기록 탭은 이 상태 하나만 보고 화면을 분기한다.
    enum State {
        case idle
        case loading
        case empty
        case loaded([RunningWorkout])
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var showAppleWorkoutOnly = true
    @Published private(set) var summary: RunningSummary = .empty
    @Published private(set) var monthlyMileage: [MileagePeriod] = []
    @Published private(set) var yearlyMileage: [MileagePeriod] = []
    @Published private(set) var vo2MaxSamples: [VO2MaxSample] = []
    @Published private(set) var isLoadingMoreHistory = false
    @Published private(set) var isPreparingMileageHistory = false
    @Published private(set) var hasMoreHistory = false
    @Published private(set) var personalRecords: [PersonalRecordEntry]
    @Published private(set) var pendingPersonalRecordCandidates: [PersonalRecordCandidate]
    @Published private(set) var personalRecordHistory: [PersonalRecordHistoryEntry]
    @Published private(set) var isRefreshingPersonalRecords = false
    @Published private(set) var personalRecordProgress: Double?
    @Published private(set) var selectedRecordMonth: Date
    @Published private(set) var selectedRecordDate: Date?

    private(set) var allRuns: [RunningWorkout] = []
    private var latestVO2Max: VO2MaxSample?
    private var oldestRunningWorkoutDate: Date?
    private var nextHistoryMonthStart: Date?

    private let healthKitService = HealthKitService()
    private let personalRecordStore = PersonalRecordStore()
    private var personalRecordSnapshot: PersonalRecordSnapshot

    init() {
        let snapshot = PersonalRecordStore().load()
        personalRecordSnapshot = snapshot
        personalRecords = snapshot.records
        pendingPersonalRecordCandidates = snapshot.pendingCandidates
        personalRecordHistory = snapshot.history
        selectedRecordMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        selectedRecordDate = nil
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    // 최초 진입 시 올해 러닝과 요약 지표를 함께 읽어온다.
    func load() async {
        state = .loading

        do {
            try await healthKitService.requestReadAuthorization()
            let calendar = Calendar.current
            let now = Date()
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now

            async let runsTask = healthKitService.fetchRunningWorkouts(from: startOfYear, to: now)
            async let vo2MaxTask = healthKitService.fetchLatestVO2Max()
            async let vo2MaxSamplesTask = healthKitService.fetchVO2MaxSamples()
            async let oldestDateTask = healthKitService.fetchOldestRunningWorkoutDate()

            let runs = try await runsTask
            latestVO2Max = try await vo2MaxTask
            vo2MaxSamples = try await vo2MaxSamplesTask
            oldestRunningWorkoutDate = try await oldestDateTask
            allRuns = deduplicatedAndSorted(runs)
            nextHistoryMonthStart = calendar.date(byAdding: .month, value: -1, to: startOfYear)
            selectedRecordMonth = startOfMonth(selectedRecordMonth)
            if let nextHistoryMonthStart, let oldestRunningWorkoutDate {
                hasMoreHistory = startOfMonth(nextHistoryMonthStart) >= startOfMonth(oldestRunningWorkoutDate)
            } else {
                hasMoreHistory = false
            }
            applyFilter()
            Task {
                await refreshPersonalRecordsIfNeeded()
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // 소스 필터가 바뀌면 목록/요약/마일리지를 한 번에 다시 계산한다.
    func applyFilter() {
        let filteredRuns = showAppleWorkoutOnly ? allRuns.filter(\.isAppleWorkout) : allRuns
        summary = Self.buildSummary(from: filteredRuns, vo2Max: latestVO2Max)
        monthlyMileage = buildMonthlyMileage(from: filteredRuns)
        yearlyMileage = buildYearlyMileage(from: filteredRuns)

        if filteredRuns.isEmpty {
            state = .empty
        } else {
            state = .loaded(filteredRuns)
        }
    }

    // 기록 탭에서 이전 달 데이터를 요청할 때 필요한 추가 로딩 경로다.
    @discardableResult
    func loadMoreHistory(refreshPersonalRecords: Bool = true) async -> Bool {
        guard !isLoadingMoreHistory, let monthStart = nextHistoryMonthStart else { return false }

        isLoadingMoreHistory = true
        defer { isLoadingMoreHistory = false }

        do {
            let monthEnd = Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? Date()
            let olderRuns = try await healthKitService.fetchRunningWorkouts(from: monthStart, to: monthEnd)
            allRuns = deduplicatedAndSorted(allRuns + olderRuns)

            let previousMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: monthStart)
            nextHistoryMonthStart = previousMonthStart

            if let oldestRunningWorkoutDate, let previousMonthStart {
                hasMoreHistory = startOfMonth(previousMonthStart) >= startOfMonth(oldestRunningWorkoutDate)
            } else {
                hasMoreHistory = false
            }

            applyFilter()
            if refreshPersonalRecords {
                Task {
                    await refreshPersonalRecordsIfNeeded()
                }
            }
            return true
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }

    func prepareMileageHistory(for range: MileageHistoryRange) async {
        guard range != .currentYear else { return }
        guard !isPreparingMileageHistory else { return }
        guard !isMileageHistoryReady(for: range) else { return }

        isPreparingMileageHistory = true
        defer { isPreparingMileageHistory = false }

        var didLoadAdditionalHistory = false

        while shouldLoadMoreHistory(forMileageRange: range) {
            let loaded = await loadMoreHistory(refreshPersonalRecords: false)
            guard loaded else { break }
            didLoadAdditionalHistory = true
        }

        if didLoadAdditionalHistory {
            await refreshPersonalRecordsIfNeeded()
        }
    }

    func mileageMonthlyPeriods(for range: MileageHistoryRange) -> [MileagePeriod] {
        buildMonthlyMileage(from: mileageRuns(for: range))
    }

    func mileageYearlyPeriods(for range: MileageHistoryRange) -> [MileagePeriod] {
        buildYearlyMileage(from: mileageRuns(for: range))
    }

    func mileageSummary(for range: MileageHistoryRange) -> MileageRangeSummary {
        let runs = mileageRuns(for: range)
        let totalDistanceKilometers = runs.reduce(0) { $0 + $1.distanceInKilometers }
        let runCount = runs.count
        let isFullyLoaded = isMileageHistoryReady(for: range)

        return MileageRangeSummary(
            totalDistanceKilometers: totalDistanceKilometers,
            runCount: runCount,
            helperText: mileageHelperText(for: range, isFullyLoaded: isFullyLoaded),
            isFullyLoaded: isFullyLoaded
        )
    }

    var recordRuns: [RunningWorkout] {
        let monthRuns = filteredAllRuns.filter {
            Calendar.current.isDate($0.startDate, equalTo: selectedRecordMonth, toGranularity: .month)
        }

        guard let selectedRecordDate else {
            return monthRuns
        }

        return monthRuns.filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedRecordDate) }
    }

    var selectedMonthRuns: [RunningWorkout] {
        filteredAllRuns.filter {
            Calendar.current.isDate($0.startDate, equalTo: selectedRecordMonth, toGranularity: .month)
        }
    }

    var selectedMonthSummary: RecordMonthSummary {
        let monthRuns = selectedMonthRuns
        let totalDistanceKilometers = monthRuns.reduce(0) { $0 + $1.distanceInKilometers }
        let totalDuration = monthRuns.reduce(0) { $0 + $1.duration }
        let runningDays = Set(monthRuns.map { Calendar.current.startOfDay(for: $0.startDate) }).count
        let weeksInMonth = Double(max(Calendar.current.range(of: .weekOfMonth, in: .month, for: selectedRecordMonth)?.count ?? 1, 1))

        return RecordMonthSummary(
            monthStart: selectedRecordMonth,
            runCount: monthRuns.count,
            totalDistanceKilometers: totalDistanceKilometers,
            totalDuration: totalDuration,
            runningDays: runningDays,
            weeklyRunFrequency: Double(monthRuns.count) / weeksInMonth
        )
    }

    var selectedMonthLabelText: String {
        selectedRecordMonth.formatted(
            .dateTime
                .locale(Locale(identifier: "ko_KR"))
                .year()
                .month(.wide)
        )
    }

    var selectedDateLabelText: String? {
        guard let selectedRecordDate else { return nil }
        return selectedRecordDate.formatted(
            .dateTime
                .locale(Locale(identifier: "ko_KR"))
                .month(.wide)
                .day()
                .weekday(.abbreviated)
        )
    }

    var canMoveToNextRecordMonth: Bool {
        selectedRecordMonth < startOfMonth(Date())
    }

    // 달 이동 버튼은 결국 특정 월 선택 로직으로 합류한다.
    func moveRecordMonth(by offset: Int) async {
        guard offset != 0 else { return }
        let targetMonth = Calendar.current.date(byAdding: .month, value: offset, to: selectedRecordMonth) ?? selectedRecordMonth
        await selectRecordMonth(targetMonth)
    }

    // 미래 월로는 이동하지 못하도록 현재 월 상한을 둔다.
    func selectRecordMonth(_ date: Date) async {
        let currentMonthStart = startOfMonth(Date())
        let targetMonth = min(startOfMonth(date), currentMonthStart)
        selectedRecordMonth = targetMonth
        selectedRecordDate = nil
        await ensureRecordMonthAvailable(targetMonth)
    }

    // 날짜 필터는 선택된 월 안에 있을 때만 적용한다.
    func selectRecordDate(_ date: Date?) {
        guard let date else {
            selectedRecordDate = nil
            return
        }

        if Calendar.current.isDate(date, equalTo: selectedRecordMonth, toGranularity: .month) {
            selectedRecordDate = Calendar.current.startOfDay(for: date)
        }
    }

    func runs(on date: Date) -> [RunningWorkout] {
        selectedMonthRuns.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    func clearRecordDateSelection() {
        selectedRecordDate = nil
    }

    // PR은 Apple 운동 앱 러닝만 기준으로 계산해 기록 탭과 일관성을 맞춘다.
    func refreshPersonalRecordsIfNeeded() async {
        guard !isRefreshingPersonalRecords else { return }
        isRefreshingPersonalRecords = true
        defer {
            isRefreshingPersonalRecords = false
            personalRecordProgress = nil
        }

        do {
            var snapshot = personalRecordSnapshot.version == personalRecordStore.version
                ? personalRecordSnapshot
                : .empty(version: personalRecordStore.version)

            let runsToProcess: [RunningWorkout]
            let now = Date()
            let cutoffDate = Calendar.current.date(byAdding: .year, value: -3, to: now) ?? .distantPast

            if snapshot.processedRunIDs.isEmpty {
                guard let oldestRunningWorkoutDate else { return }
                let startDate = max(oldestRunningWorkoutDate, cutoffDate)
                let historicalRuns = try await healthKitService.fetchRunningWorkouts(from: startDate, to: now)
                runsToProcess = deduplicatedAndSortedChronologically(historicalRuns).filter(\.isAppleWorkout)
                snapshot = .empty(version: personalRecordStore.version)
            } else {
                let processedIDs = Set(snapshot.processedRunIDs)
                runsToProcess = deduplicatedAndSortedChronologically(allRuns).filter {
                    $0.isAppleWorkout && !processedIDs.contains($0.id) && $0.startDate >= cutoffDate
                }
            }

            guard !runsToProcess.isEmpty else {
                personalRecords = snapshot.records
                pendingPersonalRecordCandidates = snapshot.pendingCandidates
                personalRecordHistory = snapshot.history
                personalRecordSnapshot = snapshot
                personalRecordProgress = 1
                return
            }

            personalRecordProgress = 0
            snapshot = try await updatePersonalRecords(snapshot, with: runsToProcess)
            personalRecordSnapshot = snapshot
            personalRecords = snapshot.records
            pendingPersonalRecordCandidates = snapshot.pendingCandidates
            personalRecordHistory = snapshot.history
            personalRecordStore.save(snapshot)
        } catch {
            print("Personal record refresh failed: \(error.localizedDescription)")
        }
    }

    // 사용자가 후보 기록을 승인하면 현재 PR 스냅샷을 즉시 갱신한다.
    func approvePersonalRecordCandidate(for distance: PersonalRecordDistance) {
        guard let candidate = pendingPersonalRecordCandidates.first(where: { $0.distance == distance }) else { return }

        var recordMap = Dictionary(uniqueKeysWithValues: personalRecordSnapshot.records.map { ($0.distance, $0) })
        recordMap[distance] = PersonalRecordEntry(
            distance: distance,
            duration: candidate.duration,
            date: candidate.date,
            workoutID: candidate.workoutID
        )

        personalRecordSnapshot.records = PersonalRecordDistance.allCases.map {
            recordMap[$0] ?? PersonalRecordEntry(distance: $0, duration: nil, date: nil, workoutID: nil)
        }
        personalRecordSnapshot.pendingCandidates.removeAll { $0.distance == distance }
        personalRecordSnapshot.history = approvedCandidateHistory(candidate)
        personalRecordSnapshot.updatedAt = .now

        personalRecords = personalRecordSnapshot.records
        pendingPersonalRecordCandidates = personalRecordSnapshot.pendingCandidates
        personalRecordHistory = personalRecordSnapshot.history
        personalRecordStore.save(personalRecordSnapshot)
    }

    // 후보를 유지하지 않기로 했을 때도 스냅샷에 처리 사실을 남긴다.
    func dismissPersonalRecordCandidate(for distance: PersonalRecordDistance) {
        personalRecordSnapshot.pendingCandidates.removeAll { $0.distance == distance }
        personalRecordSnapshot.updatedAt = .now
        pendingPersonalRecordCandidates = personalRecordSnapshot.pendingCandidates
        personalRecordStore.save(personalRecordSnapshot)
    }

    func personalRecordAchievements(for run: RunningWorkout) -> [PersonalRecordDistance] {
        let exactMatches = personalRecordAchievements(for: run.id)
        guard exactMatches.isEmpty else { return exactMatches }

        let matchedByDate = Set(
            personalRecordHistory
                .filter { abs($0.date.timeIntervalSince(run.startDate)) < 1 }
                .map(\.distance)
            +
            personalRecords
                .compactMap { record -> PersonalRecordDistance? in
                    guard
                        let recordDate = record.date,
                        abs(recordDate.timeIntervalSince(run.startDate)) < 1
                    else {
                        return nil
                    }
                    return record.distance
                }
        )

        return PersonalRecordDistance.allCases.filter { matchedByDate.contains($0) }
    }

    func personalRecordAchievements(for workoutID: UUID) -> [PersonalRecordDistance] {
        let historyDistances = personalRecordHistory
            .filter { $0.workoutID == workoutID }
            .map(\.distance)
        let currentRecordDistances = personalRecords
            .filter { $0.workoutID == workoutID }
            .map(\.distance)
        let achievedDistances = Set(historyDistances + currentRecordDistances)

        return PersonalRecordDistance.allCases.filter { achievedDistances.contains($0) }
    }

    // 대시보드의 핵심 숫자와 텍스트 요약을 한 번에 만든다.
    static private func buildSummary(from runs: [RunningWorkout], vo2Max: VO2MaxSample?) -> RunningSummary {
        guard !runs.isEmpty else { return .empty }

        let calendar = Calendar.current
        let now = Date()
        let monthDistance = runs
            .filter { calendar.isDate($0.startDate, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.distanceInKilometers }
        let yearDistance = runs
            .filter { calendar.isDate($0.startDate, equalTo: now, toGranularity: .year) }
            .reduce(0) { $0 + $1.distanceInKilometers }

        let last7Distance = runs
            .filter { $0.startDate >= calendar.date(byAdding: .day, value: -7, to: now) ?? now }
            .reduce(0) { $0 + $1.distanceInKilometers }
        let previous7Distance = runs
            .filter {
                guard
                    let start = calendar.date(byAdding: .day, value: -14, to: now),
                    let end = calendar.date(byAdding: .day, value: -7, to: now)
                else { return false }
                return $0.startDate >= start && $0.startDate < end
            }
            .reduce(0) { $0 + $1.distanceInKilometers }

        let trainingStatus: (String, String)
        if last7Distance >= previous7Distance * 1.2, last7Distance > 0 {
            trainingStatus = ("빌드업", "최근 7일 거리가 직전 주보다 늘었습니다.")
        } else if last7Distance > 0 {
            trainingStatus = ("유지", "최근 2주 훈련량이 안정적으로 유지되고 있습니다.")
        } else {
            trainingStatus = ("회복", "최근 7일 러닝이 적어 회복 상태로 보입니다.")
        }

        let predicted5K = predictTime(for: 5_000, from: runs)
        let predicted10K = predictTime(for: 10_000, from: runs)
        let predictedHalf = predictTime(for: 21_097.5, from: runs)
        let predictedMarathon = predictTime(for: 42_195, from: runs)

        return RunningSummary(
            monthDistanceKilometers: monthDistance,
            yearDistanceKilometers: yearDistance,
            monthDistanceText: formatDistance(monthDistance),
            yearDistanceText: formatDistance(yearDistance),
            trainingStatus: trainingStatus.0,
            trainingStatusDetail: trainingStatus.1,
            vo2MaxText: vo2Max.map { $0.value.formatted(.number.precision(.fractionLength(1))) } ?? "-",
            vo2MaxDateText: vo2Max.map { "업데이트 \(formatShortKoreanDate($0.date))" } ?? "VO2 Max 데이터 없음",
            predicted5KText: predicted5K,
            predicted10KText: predicted10K,
            predictedHalfText: predictedHalf,
            predictedMarathonText: predictedMarathon
        )
    }

    private static func formatDistance(_ kilometers: Double) -> String {
        kilometers.formatted(.number.precision(.fractionLength(1))) + " km"
    }

    private static func formatShortKoreanDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale(identifier: "ko_KR"))
                .month(.wide)
                .day()
        )
    }

    private static func predictTime(for targetDistance: Double, from runs: [RunningWorkout]) -> String {
        let recentRuns = runs
            .filter { $0.distanceInMeters >= 1_000 && $0.startDate >= Calendar.current.date(byAdding: .day, value: -120, to: Date()) ?? .distantPast }

        let candidates = recentRuns.isEmpty ? runs.filter { $0.distanceInMeters >= 1_000 } : recentRuns
        guard !candidates.isEmpty else {
            return "-"
        }

        let predictedSeconds = candidates
            .map { $0.duration * pow(targetDistance / $0.distanceInMeters, 1.06) }
            .min() ?? 0
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = predictedSeconds >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: predictedSeconds) ?? "-"
    }

    private func buildMonthlyMileage(from runs: [RunningWorkout]) -> [MileagePeriod] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: runs) {
            let components = calendar.dateComponents([.year, .month], from: $0.startDate)
            return calendar.date(from: components) ?? $0.startDate
        }

        return grouped.keys.sorted(by: >).map { monthDate in
            let distance = grouped[monthDate, default: []].reduce(0) { $0 + $1.distanceInKilometers }
            return MileagePeriod(
                id: "month-\(monthDate.timeIntervalSince1970)",
                title: monthDate.formatted(.dateTime.year().month(.wide)),
                subtitle: "\(grouped[monthDate, default: []].count)회 러닝",
                distanceText: Self.formatDistance(distance)
            )
        }
    }

    private func buildYearlyMileage(from runs: [RunningWorkout]) -> [MileagePeriod] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: runs) {
            let components = calendar.dateComponents([.year], from: $0.startDate)
            return calendar.date(from: components) ?? $0.startDate
        }

        return grouped.keys.sorted(by: >).map { yearDate in
            let distance = grouped[yearDate, default: []].reduce(0) { $0 + $1.distanceInKilometers }
            return MileagePeriod(
                id: "year-\(yearDate.timeIntervalSince1970)",
                title: yearDate.formatted(.dateTime.year()),
                subtitle: "\(grouped[yearDate, default: []].count)회 러닝",
                distanceText: Self.formatDistance(distance)
            )
        }
    }

    private func deduplicatedAndSorted(_ runs: [RunningWorkout]) -> [RunningWorkout] {
        let unique = Dictionary(runs.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
        return unique.values.sorted(by: { $0.startDate > $1.startDate })
    }

    private var filteredAllRuns: [RunningWorkout] {
        showAppleWorkoutOnly ? allRuns.filter(\.isAppleWorkout) : allRuns
    }

    private func ensureRecordMonthAvailable(_ monthStart: Date) async {
        var didLoadAdditionalHistory = false
        while !isRecordMonthLoaded(monthStart) && hasMoreHistory {
            let loaded = await loadMoreHistory(refreshPersonalRecords: false)
            guard loaded else { break }
            didLoadAdditionalHistory = true
        }

        if didLoadAdditionalHistory {
            await refreshPersonalRecordsIfNeeded()
        }
    }

    private func isRecordMonthLoaded(_ monthStart: Date) -> Bool {
        guard let nextHistoryMonthStart else {
            return true
        }
        return monthStart > nextHistoryMonthStart
    }

    private func mileageRuns(for range: MileageHistoryRange) -> [RunningWorkout] {
        guard let startDate = mileageStartDate(for: range) else {
            return filteredAllRuns
        }

        return filteredAllRuns.filter { $0.startDate >= startDate }
    }

    private func mileageStartDate(for range: MileageHistoryRange) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        switch range {
        case .currentYear:
            return calendar.date(from: calendar.dateComponents([.year], from: now))
        case .recentThreeYears:
            return calendar.date(byAdding: .year, value: -3, to: now)
        case .all:
            return nil
        }
    }

    private func shouldLoadMoreHistory(forMileageRange range: MileageHistoryRange) -> Bool {
        guard hasMoreHistory, let nextHistoryMonthStart else { return false }

        switch range {
        case .currentYear:
            return false
        case .recentThreeYears:
            guard let targetStartDate = mileageStartDate(for: range) else { return false }
            return startOfMonth(nextHistoryMonthStart) >= startOfMonth(targetStartDate)
        case .all:
            return true
        }
    }

    private func isMileageHistoryReady(for range: MileageHistoryRange) -> Bool {
        switch range {
        case .currentYear:
            return true
        case .recentThreeYears:
            guard let targetStartDate = mileageStartDate(for: range) else { return !hasMoreHistory }
            guard let earliestLoadedDate = allRuns.map(\.startDate).min() else { return !hasMoreHistory }
            return startOfMonth(earliestLoadedDate) <= startOfMonth(targetStartDate) || !hasMoreHistory
        case .all:
            return !hasMoreHistory
        }
    }

    private func mileageHelperText(for range: MileageHistoryRange, isFullyLoaded: Bool) -> String {
        switch range {
        case .currentYear:
            return "올해 범위는 앱 첫 로딩 데이터로 바로 볼 수 있습니다."
        case .recentThreeYears:
            if isFullyLoaded {
                return "최근 3년 범위까지 반영했습니다."
            }
            if let targetStartDate = mileageStartDate(for: range) {
                return "\(formatMonthYear(targetStartDate))까지 과거 기록을 추가로 불러오는 중입니다."
            }
            return "최근 3년 범위를 위해 과거 기록을 불러오는 중입니다."
        case .all:
            if let earliestLoadedDate = allRuns.map(\.startDate).min(), isFullyLoaded {
                return "\(formatMonthYear(earliestLoadedDate))부터 전체 기록을 반영했습니다."
            }
            return "전체 기간을 보려면 과거 기록을 순차적으로 더 불러옵니다."
        }
    }

    private func formatMonthYear(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale(identifier: "ko_KR"))
                .year()
                .month(.wide)
        )
    }

    private func updatePersonalRecords(
        _ snapshot: PersonalRecordSnapshot,
        with runs: [RunningWorkout]
    ) async throws -> PersonalRecordSnapshot {
        var updatedSnapshot = snapshot
        var recordMap = Dictionary(uniqueKeysWithValues: updatedSnapshot.records.map { ($0.distance, $0) })
        var history = updatedSnapshot.history.sorted {
            if $0.date == $1.date {
                return $0.distance.meters < $1.distance.meters
            }
            return $0.date < $1.date
        }
        var processedRunIDs = Set(updatedSnapshot.processedRunIDs)
        let totalRuns = runs.count

        for (offset, run) in runs.enumerated() where !processedRunIDs.contains(run.id) {
            let detail = try await healthKitService.fetchRunDetail(for: run)

            for distance in PersonalRecordDistance.allCases {
                guard let candidateDuration = bestDuration(for: distance.meters, in: detail.distanceTimeline) else { continue }

                let current = recordMap[distance]
                if current?.duration == nil || candidateDuration < (current?.duration ?? .greatestFiniteMagnitude) {
                    history.append(
                        PersonalRecordHistoryEntry(
                            distance: distance,
                            duration: candidateDuration,
                            date: run.startDate,
                            workoutID: run.id
                        )
                    )
                    recordMap[distance] = PersonalRecordEntry(
                        distance: distance,
                        duration: candidateDuration,
                        date: run.startDate,
                        workoutID: run.id
                    )
                }
            }

            processedRunIDs.insert(run.id)
            updatedSnapshot.records = PersonalRecordDistance.allCases.map {
                recordMap[$0] ?? PersonalRecordEntry(distance: $0, duration: nil, date: nil, workoutID: nil)
            }
            updatedSnapshot.pendingCandidates = []
            updatedSnapshot.history = history
            updatedSnapshot.processedRunIDs = Array(processedRunIDs)
            updatedSnapshot.updatedAt = .now
            personalRecordSnapshot = updatedSnapshot
            personalRecords = updatedSnapshot.records
            pendingPersonalRecordCandidates = updatedSnapshot.pendingCandidates
            personalRecordHistory = updatedSnapshot.history
            personalRecordProgress = Double(offset + 1) / Double(max(totalRuns, 1))
            personalRecordStore.save(updatedSnapshot)
        }

        updatedSnapshot.records = PersonalRecordDistance.allCases.map {
            recordMap[$0] ?? PersonalRecordEntry(distance: $0, duration: nil, date: nil, workoutID: nil)
        }
        updatedSnapshot.pendingCandidates = []
        updatedSnapshot.history = history
        updatedSnapshot.processedRunIDs = Array(processedRunIDs)
        updatedSnapshot.updatedAt = .now
        return updatedSnapshot
    }

    private func bestDuration(for targetDistance: Double, in timeline: [DistanceTimelinePoint]) -> TimeInterval? {
        guard timeline.count > 1, let lastDistance = timeline.last?.distanceMeters, lastDistance >= targetDistance else {
            return nil
        }

        var best: TimeInterval?
        var lowerIndex = 0

        for endIndex in timeline.indices {
            let endPoint = timeline[endIndex]
            guard endPoint.distanceMeters >= targetDistance else { continue }

            let startDistance = endPoint.distanceMeters - targetDistance
            while lowerIndex + 1 < timeline.count, timeline[lowerIndex + 1].distanceMeters < startDistance {
                lowerIndex += 1
            }

            let startElapsed = interpolatedElapsed(for: startDistance, in: timeline, lowerIndex: lowerIndex)
            let duration = endPoint.elapsed - startElapsed
            guard duration > 0 else { continue }

            if best == nil || duration < (best ?? .greatestFiniteMagnitude) {
                best = duration
            }
        }

        return best
    }

    private func interpolatedElapsed(
        for distance: Double,
        in timeline: [DistanceTimelinePoint],
        lowerIndex: Int
    ) -> TimeInterval {
        let clampedIndex = min(max(lowerIndex, 0), timeline.count - 1)
        let lowerPoint = timeline[clampedIndex]
        guard clampedIndex + 1 < timeline.count else { return lowerPoint.elapsed }

        let upperPoint = timeline[clampedIndex + 1]
        let distanceSpan = upperPoint.distanceMeters - lowerPoint.distanceMeters
        guard distanceSpan > 0 else { return upperPoint.elapsed }

        let ratio = (distance - lowerPoint.distanceMeters) / distanceSpan
        let clampedRatio = min(max(ratio, 0), 1)
        return lowerPoint.elapsed + (upperPoint.elapsed - lowerPoint.elapsed) * clampedRatio
    }

    private func approvedCandidateHistory(_ candidate: PersonalRecordCandidate) -> [PersonalRecordHistoryEntry] {
        let existingDistanceHistory = personalRecordSnapshot.history
            .filter { $0.distance == candidate.distance }
            .sorted { $0.date < $1.date }
        let unaffectedHistory = personalRecordSnapshot.history.filter { $0.distance != candidate.distance }
        let approvedEntry = PersonalRecordHistoryEntry(
            distance: candidate.distance,
            duration: candidate.duration,
            date: candidate.date,
            workoutID: candidate.workoutID
        )

        var rebuiltDistanceHistory: [PersonalRecordHistoryEntry] = []
        var bestDuration = TimeInterval.greatestFiniteMagnitude

        for entry in existingDistanceHistory where entry.date < candidate.date {
            guard entry.duration < bestDuration else { continue }
            rebuiltDistanceHistory.append(entry)
            bestDuration = entry.duration
        }

        if approvedEntry.duration < bestDuration {
            rebuiltDistanceHistory.append(approvedEntry)
            bestDuration = approvedEntry.duration
        }

        for entry in existingDistanceHistory where entry.date > candidate.date {
            guard entry.duration < bestDuration else { continue }
            rebuiltDistanceHistory.append(entry)
            bestDuration = entry.duration
        }

        return (unaffectedHistory + rebuiltDistanceHistory).sorted {
            if $0.date == $1.date {
                return $0.distance.meters < $1.distance.meters
            }
            return $0.date < $1.date
        }
    }

    private func deduplicatedAndSortedChronologically(_ runs: [RunningWorkout]) -> [RunningWorkout] {
        let unique = Dictionary(runs.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
        return unique.values.sorted(by: { $0.startDate < $1.startDate })
    }

    private func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
