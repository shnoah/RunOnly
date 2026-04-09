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
    private var restingHeartRateSnapshot: RestingHeartRateSnapshot?
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

    // 최초 진입 시 현재 연도 기록과 최근 요약 계산에 필요한 이전 구간까지 함께 읽어온다.
    func load() async {
        state = .loading

        do {
            try await healthKitService.requestReadAuthorization()
            let calendar = Calendar.current
            let now = Date()
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            let predictionWindowStart = calendar.date(byAdding: .day, value: -PredictionModel.lookbackDays, to: now) ?? now
            let summaryHistoryStart = min(startOfYear, startOfMonth(predictionWindowStart))

            async let runsTask = healthKitService.fetchRunningWorkouts(from: summaryHistoryStart, to: now)
            async let vo2MaxTask = healthKitService.fetchLatestVO2Max()
            async let vo2MaxSamplesTask = healthKitService.fetchVO2MaxSamples()
            async let restingHeartRateTask = healthKitService.fetchRestingHeartRateSnapshot(referenceDate: now)
            async let oldestDateTask = healthKitService.fetchOldestRunningWorkoutDate()

            let runs = try await runsTask
            latestVO2Max = try await vo2MaxTask
            vo2MaxSamples = try await vo2MaxSamplesTask
            restingHeartRateSnapshot = try await restingHeartRateTask
            oldestRunningWorkoutDate = try await oldestDateTask
            allRuns = deduplicatedAndSorted(runs)
            nextHistoryMonthStart = calendar.date(byAdding: .month, value: -1, to: summaryHistoryStart)
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

    func requestReadAuthorization() async throws {
        try await healthKitService.requestReadAuthorization()
    }

    // 소스 필터가 바뀌면 목록/요약/마일리지를 한 번에 다시 계산한다.
    func applyFilter() {
        let filteredRuns = showAppleWorkoutOnly ? allRuns.filter(\.isAppleWorkout) : allRuns
        summary = Self.buildSummary(
            from: filteredRuns,
            vo2Max: latestVO2Max,
            restingHeartRateSnapshot: restingHeartRateSnapshot
        )
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
        RunDisplayFormatter.monthLabel(selectedRecordMonth)
    }

    var selectedDateLabelText: String? {
        guard let selectedRecordDate else { return nil }
        return RunDisplayFormatter.dayLabel(selectedRecordDate)
    }

    var canMoveToNextRecordMonth: Bool {
        selectedRecordMonth < startOfMonth(Date())
    }

    var isViewingCurrentRecordMonth: Bool {
        Calendar.current.isDate(selectedRecordMonth, equalTo: startOfMonth(Date()), toGranularity: .month)
    }

    // 달 이동 버튼은 결국 특정 월 선택 로직으로 합류한다.
    func moveRecordMonth(by offset: Int) async {
        guard offset != 0 else { return }
        let targetMonth = Calendar.current.date(byAdding: .month, value: offset, to: selectedRecordMonth) ?? selectedRecordMonth
        await selectRecordMonth(targetMonth)
    }

    func jumpToCurrentRecordMonth() async {
        await selectRecordMonth(Date())
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
    static private func buildSummary(
        from runs: [RunningWorkout],
        vo2Max: VO2MaxSample?,
        restingHeartRateSnapshot: RestingHeartRateSnapshot?
    ) -> RunningSummary {
        guard !runs.isEmpty else { return .empty }

        let calendar = Calendar.current
        let now = Date()
        let monthDistance = runs
            .filter { calendar.isDate($0.startDate, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.distanceInKilometers }
        let yearDistance = runs
            .filter { calendar.isDate($0.startDate, equalTo: now, toGranularity: .year) }
            .reduce(0) { $0 + $1.distanceInKilometers }

        let predicted5K = predictTime(for: 5_000, from: runs)
        let predicted10K = predictTime(for: 10_000, from: runs)
        let predictedHalf = predictTime(for: 21_097.5, from: runs)
        let predictedMarathon = predictTime(for: 42_195, from: runs)
        let readiness = buildRecoveryReadiness(
            from: runs,
            restingHeartRateSnapshot: restingHeartRateSnapshot,
            now: now
        )

        return RunningSummary(
            monthDistanceKilometers: monthDistance,
            yearDistanceKilometers: yearDistance,
            monthDistanceText: formatDistance(monthDistance),
            yearDistanceText: formatDistance(yearDistance),
            recoveryReadiness: readiness,
            vo2MaxText: vo2Max.map { $0.value.formatted(.number.precision(.fractionLength(1))) } ?? "-",
            vo2MaxDateText: vo2Max.map { L10n.format("업데이트 %@", formatShortDate($0.date)) } ?? L10n.tr("VO2 Max 데이터 없음"),
            predicted5KText: predicted5K,
            predicted10KText: predicted10K,
            predictedHalfText: predictedHalf,
            predictedMarathonText: predictedMarathon
        )
    }

    private static func formatDistance(_ kilometers: Double) -> String {
        RunDisplayFormatter.distance(kilometers: kilometers, fractionLength: 1)
    }

    private static func formatShortDate(_ date: Date) -> String {
        RunDisplayFormatter.shortMonthDay(date)
    }

    private static func buildRecoveryReadiness(
        from runs: [RunningWorkout],
        restingHeartRateSnapshot: RestingHeartRateSnapshot?,
        now: Date
    ) -> RecoveryReadiness {
        let calendar = Calendar.current
        let recent28Start = calendar.date(byAdding: .day, value: -28, to: now) ?? .distantPast
        let recent10Start = calendar.date(byAdding: .day, value: -10, to: now) ?? .distantPast
        let recent28Runs = runs.filter { $0.startDate >= recent28Start && $0.startDate <= now }
        let weeklyLoadChart = buildRecoveryLoadChart(from: recent28Runs, now: now)

        guard recent28Runs.count >= 3 else {
            return RecoveryReadiness(
                score: nil,
                status: L10n.tr("데이터 필요"),
                detail: L10n.tr("최근 러닝이 더 쌓이면 준비도를 계산합니다."),
                recommendationTitle: L10n.tr("러닝 데이터가 더 필요해요"),
                recommendationDetail: L10n.tr("최근 28일 안에 최소 3회의 러닝이 있으면 준비도를 보여드릴게요."),
                factors: [
                    L10n.format("최근 28일 러닝 %d/3회", recent28Runs.count),
                    L10n.tr("최소 3회가 쌓이면 준비도 계산 시작"),
                    L10n.tr("지금은 예측 대신 데이터 축적을 우선해요")
                ],
                confidenceText: L10n.tr("데이터가 더 쌓이면 계산"),
                recentLoadText: L10n.format("%d점", Int(weeklyLoadChart.reduce(0) { $0 + $1.load }.rounded())),
                lastRunText: runs.first.map { relativeTimeText(from: $0.startDate, to: now) } ?? "-",
                restingHeartRateText: restingHeartRateSnapshot.map { Self.restingHeartRateText(from: $0) },
                loadRatioText: nil,
                weeklyLoadChart: weeklyLoadChart,
                isDataSufficient: false,
                dataRequirementText: L10n.tr("최근 28일 안에 최소 3회의 러닝이 필요합니다.")
            )
        }

        guard recent28Runs.contains(where: { $0.startDate >= recent10Start }) else {
            return RecoveryReadiness(
                score: nil,
                status: L10n.tr("데이터 필요"),
                detail: L10n.tr("최근 10일 안의 러닝이 있어야 오늘 컨디션을 가늠할 수 있어요."),
                recommendationTitle: L10n.tr("최근 러닝이 더 필요해요"),
                recommendationDetail: L10n.tr("최근 10일 안에 러닝이 한 번 이상 쌓이면 준비도를 다시 계산할게요."),
                factors: [
                    L10n.tr("최근 28일 러닝 횟수는 충족"),
                    L10n.tr("최근 10일 안 러닝이 아직 없어요"),
                    L10n.tr("오늘은 점수보다 가볍게 다시 시작하는 쪽을 추천해요")
                ],
                confidenceText: L10n.tr("최근 러닝이 더 필요해요"),
                recentLoadText: L10n.format("%d점", Int(weeklyLoadChart.reduce(0) { $0 + $1.load }.rounded())),
                lastRunText: runs.first.map { relativeTimeText(from: $0.startDate, to: now) } ?? "-",
                restingHeartRateText: restingHeartRateSnapshot.map { Self.restingHeartRateText(from: $0) },
                loadRatioText: nil,
                weeklyLoadChart: weeklyLoadChart,
                isDataSufficient: false,
                dataRequirementText: L10n.tr("최근 10일 안에 러닝이 한 번 이상 필요합니다.")
            )
        }

        guard let lastRun = recent28Runs.max(by: { $0.startDate < $1.startDate }) else {
            return .empty
        }

        let baselinePace = median(
            recent28Runs.compactMap { paceSecondsPerKilometer(for: $0) }
        )
        let last7Start = calendar.date(byAdding: .day, value: -7, to: now) ?? .distantPast
        let last3Start = calendar.date(byAdding: .day, value: -3, to: now) ?? .distantPast
        let total28Load = recent28Runs.reduce(0) { $0 + recoveryLoad(for: $1, baselinePaceSecondsPerKilometer: baselinePace) }
        let last7Load = recent28Runs
            .filter { $0.startDate >= last7Start }
            .reduce(0) { $0 + recoveryLoad(for: $1, baselinePaceSecondsPerKilometer: baselinePace) }
        let last3Load = recent28Runs
            .filter { $0.startDate >= last3Start }
            .reduce(0) { $0 + recoveryLoad(for: $1, baselinePaceSecondsPerKilometer: baselinePace) }

        let baselineWeeklyLoad = max(total28Load / 4, 1)
        let baselineThreeDayLoad = max(total28Load * 3 / 28, 1)
        let loadRatio = last7Load / baselineWeeklyLoad
        let acuteRatio = last3Load / baselineThreeDayLoad
        let hoursSinceLastRun = max(now.timeIntervalSince(lastRun.startDate) / 3_600, 0)

        let acuteScore: Int
        switch acuteRatio {
        case ..<0.75: acuteScore = 34
        case ..<0.95: acuteScore = 38
        case ..<1.15: acuteScore = 32
        case ..<1.35: acuteScore = 22
        case ..<1.6: acuteScore = 12
        default: acuteScore = 4
        }

        let recoveryGapScore: Int
        switch hoursSinceLastRun {
        case 36...: recoveryGapScore = 30
        case 24..<36: recoveryGapScore = 24
        case 16..<24: recoveryGapScore = 18
        case 10..<16: recoveryGapScore = 12
        case 6..<10: recoveryGapScore = 6
        default: recoveryGapScore = 0
        }

        let weeklyBalanceScore: Int
        switch loadRatio {
        case 0.8...1.15: weeklyBalanceScore = 20
        case 0.65..<0.8, 1.15..<1.3: weeklyBalanceScore = 15
        case 0.5..<0.65, 1.3..<1.45: weeklyBalanceScore = 10
        default: weeklyBalanceScore = 5
        }

        let restingHeartRateScore: Int
        let restingHeartRateText: String?
        if let restingHeartRateSnapshot {
            let delta = restingHeartRateSnapshot.deltaFromBaseline
            restingHeartRateText = Self.restingHeartRateText(from: restingHeartRateSnapshot)
            switch delta {
            case ...1:
                restingHeartRateScore = 10
            case ...3:
                restingHeartRateScore = 7
            case ...5:
                restingHeartRateScore = 4
            default:
                restingHeartRateScore = 1
            }
        } else {
            restingHeartRateScore = 6
            restingHeartRateText = nil
        }

        var score = acuteScore + recoveryGapScore + weeklyBalanceScore + restingHeartRateScore

        if hoursSinceLastRun >= 72, loadRatio < 0.55 {
            score = min(score, 59)
        }

        score = max(0, min(score, 100))

        let status: String
        let detail: String
        let recommendationTitle: String
        let recommendationDetail: String

        switch score {
        case 82...:
            status = L10n.tr("좋음")
            detail = L10n.tr("최근 부하와 회복 간격이 안정적이에요.")
            recommendationTitle = L10n.tr("품질 훈련까지 무난해 보여요")
            recommendationDetail = L10n.tr("템포런이나 인터벌도 가능해 보이지만, 몸이 무겁다면 보통 러닝으로 낮춰도 좋아요.")
        case 63..<82:
            status = L10n.tr("보통")
            detail = L10n.tr("보통 러닝을 하기 좋은 흐름이에요.")
            recommendationTitle = L10n.tr("보통 러닝이나 지속주가 잘 맞아요")
            recommendationDetail = L10n.tr("오늘은 편하게 이어가는 지속주나 여유 있는 페이스의 러닝을 추천해요.")
        case 45..<63:
            status = L10n.tr("가볍게")
            detail = L10n.tr("최근 부하가 남아 있어 가볍게 가는 편이 좋아요.")
            recommendationTitle = L10n.tr("이지런 20~40분 정도가 잘 맞아요")
            recommendationDetail = L10n.tr("강한 자극보다는 몸을 푸는 느낌의 가벼운 러닝이 더 잘 어울려요.")
        default:
            status = L10n.tr("회복")
            detail = L10n.tr("최근 부하 대비 회복 여유가 적어 보여요.")
            recommendationTitle = L10n.tr("휴식이나 아주 가벼운 조깅이 좋아요")
            recommendationDetail = L10n.tr("오늘은 쉬거나 산책, 또는 아주 짧은 회복 조깅 정도로 마무리하는 편을 추천해요.")
        }

        let loadFactorText: String
        if loadRatio > 1.2 {
            loadFactorText = L10n.tr("최근 7일 부하가 평소보다 높은 편이에요")
        } else if loadRatio < 0.75 {
            loadFactorText = L10n.tr("최근 7일 부하는 평소보다 낮은 편이에요")
        } else {
            loadFactorText = L10n.tr("최근 7일 부하가 평소 범위 안에 있어요")
        }

        let recoveryFactorText: String
        switch hoursSinceLastRun {
        case 36...:
            recoveryFactorText = L10n.tr("마지막 러닝 뒤 충분히 쉬었어요")
        case 24..<36:
            recoveryFactorText = L10n.tr("마지막 러닝 뒤 회복 시간이 확보됐어요")
        case 12..<24:
            recoveryFactorText = L10n.tr("마지막 러닝이 아직 꽤 최근이에요")
        default:
            recoveryFactorText = L10n.tr("마지막 러닝이 매우 가까워요")
        }

        let heartRateFactorText: String
        if let restingHeartRateSnapshot {
            switch restingHeartRateSnapshot.deltaFromBaseline {
            case ...1:
                heartRateFactorText = L10n.tr("안정시 심박이 평소 범위예요")
            case ...3:
                heartRateFactorText = L10n.tr("안정시 심박이 조금 올라와 있어요")
            default:
                heartRateFactorText = L10n.tr("안정시 심박이 평소보다 높아요")
            }
        } else {
            heartRateFactorText = L10n.tr("안정시 심박 없이 러닝 기록 중심으로 계산했어요")
        }

        return RecoveryReadiness(
            score: score,
            status: status,
            detail: detail,
            recommendationTitle: recommendationTitle,
            recommendationDetail: recommendationDetail,
            factors: [loadFactorText, recoveryFactorText, heartRateFactorText],
            confidenceText: restingHeartRateSnapshot == nil
                ? L10n.tr("러닝 기록 기준")
                : L10n.tr("러닝 기록 + 안정시 심박 기준"),
            recentLoadText: L10n.format("%d점", Int(last7Load.rounded())),
            lastRunText: relativeTimeText(from: lastRun.startDate, to: now),
            restingHeartRateText: restingHeartRateText,
            loadRatioText: L10n.format("평소 대비 %.0f%%", loadRatio * 100),
            weeklyLoadChart: weeklyLoadChart,
            isDataSufficient: true,
            dataRequirementText: nil
        )
    }

    private static func buildRecoveryLoadChart(from runs: [RunningWorkout], now: Date) -> [RecoveryLoadPoint] {
        let calendar = Calendar.current
        let baselinePace = median(runs.compactMap { paceSecondsPerKilometer(for: $0) })

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: calendar.startOfDay(for: now)) else {
                return nil
            }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let dailyLoad = runs
                .filter { $0.startDate >= date && $0.startDate < nextDay }
                .reduce(0) { $0 + recoveryLoad(for: $1, baselinePaceSecondsPerKilometer: baselinePace) }

            return RecoveryLoadPoint(date: date, load: dailyLoad)
        }
    }

    private static func recoveryLoad(
        for run: RunningWorkout,
        baselinePaceSecondsPerKilometer: Double?
    ) -> Double {
        let minutes = max(run.duration / 60, 0)
        guard let baselinePaceSecondsPerKilometer,
              let runPace = paceSecondsPerKilometer(for: run),
              runPace > 0 else {
            return minutes
        }

        let intensityFactor = min(max(baselinePaceSecondsPerKilometer / runPace, 0.85), 1.2)
        return minutes * intensityFactor
    }

    private static func paceSecondsPerKilometer(for run: RunningWorkout) -> Double? {
        guard run.distanceInMeters >= 800, run.duration > 0 else {
            return nil
        }
        return run.duration / run.distanceInKilometers
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }

    private static func relativeTimeText(from date: Date, to now: Date) -> String {
        let elapsed = max(now.timeIntervalSince(date), 0)
        let hours = Int(elapsed / 3_600)

        if hours < 1 {
            return L10n.tr("1시간 이내")
        }
        if hours < 24 {
            return L10n.format("%d시간 전", hours)
        }

        return L10n.format("%d일 전", Int(elapsed / 86_400))
    }

    private static func restingHeartRateText(from snapshot: RestingHeartRateSnapshot) -> String {
        let delta = snapshot.deltaFromBaseline
        let signedDelta = delta >= 0 ? "+\(Int(delta.rounded()))" : "\(Int(delta.rounded()))"
        return L10n.format(
            "%d bpm (%@)",
            Int(snapshot.latestBPM.rounded()),
            signedDelta
        )
    }

    private static func predictTime(for targetDistance: Double, from runs: [RunningWorkout]) -> String {
        guard let predictedSeconds = PredictionModel.predictedSeconds(
            for: targetDistance,
            from: runs,
            referenceDate: Date()
        ) else {
            return "-"
        }

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
                title: RunDisplayFormatter.monthLabel(monthDate),
                subtitle: L10n.format("%d회 러닝", grouped[monthDate, default: []].count),
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
                subtitle: L10n.format("%d회 러닝", grouped[yearDate, default: []].count),
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
            return L10n.tr("올해 범위는 앱 첫 로딩 데이터로 바로 볼 수 있습니다.")
        case .recentThreeYears:
            if isFullyLoaded {
                return L10n.tr("최근 3년 범위까지 반영했습니다.")
            }
            if let targetStartDate = mileageStartDate(for: range) {
                return L10n.format("%@까지 과거 기록을 추가로 불러오는 중입니다.", formatMonthYear(targetStartDate))
            }
            return L10n.tr("최근 3년 범위를 위해 과거 기록을 불러오는 중입니다.")
        case .all:
            if let earliestLoadedDate = allRuns.map(\.startDate).min(), isFullyLoaded {
                return L10n.format("%@부터 전체 기록을 반영했습니다.", formatMonthYear(earliestLoadedDate))
            }
            return L10n.tr("전체 기간을 보려면 과거 기록을 순차적으로 더 불러옵니다.")
        }
    }

    private func formatMonthYear(_ date: Date) -> String {
        RunDisplayFormatter.monthLabel(date)
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
