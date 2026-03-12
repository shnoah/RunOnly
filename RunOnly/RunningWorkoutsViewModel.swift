import Combine
import Foundation

@MainActor
final class RunningWorkoutsViewModel: ObservableObject {
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
    @Published private(set) var hasMoreHistory = false
    @Published private(set) var personalRecords: [PersonalRecordEntry]
    @Published private(set) var pendingPersonalRecordCandidates: [PersonalRecordCandidate]
    @Published private(set) var isRefreshingPersonalRecords = false
    @Published private(set) var personalRecordProgress: Double?

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
    }

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

    func loadMoreHistory() async {
        guard !isLoadingMoreHistory, let monthStart = nextHistoryMonthStart else { return }

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
            Task {
                await refreshPersonalRecordsIfNeeded()
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

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

            if snapshot.processedRunIDs.isEmpty {
                guard let oldestRunningWorkoutDate else { return }
                let historicalRuns = try await healthKitService.fetchRunningWorkouts(from: oldestRunningWorkoutDate, to: now)
                runsToProcess = deduplicatedAndSorted(historicalRuns)
                snapshot = .empty(version: personalRecordStore.version)
            } else {
                let processedIDs = Set(snapshot.processedRunIDs)
                runsToProcess = deduplicatedAndSorted(allRuns).filter { !processedIDs.contains($0.id) }
            }

            guard !runsToProcess.isEmpty else {
                personalRecords = snapshot.records
                pendingPersonalRecordCandidates = snapshot.pendingCandidates
                personalRecordSnapshot = snapshot
                personalRecordProgress = 1
                return
            }

            personalRecordProgress = 0
            snapshot = try await updatePersonalRecords(snapshot, with: runsToProcess)
            personalRecordSnapshot = snapshot
            personalRecords = snapshot.records
            pendingPersonalRecordCandidates = snapshot.pendingCandidates
            personalRecordStore.save(snapshot)
        } catch {
            print("Personal record refresh failed: \(error.localizedDescription)")
        }
    }

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
        personalRecordSnapshot.updatedAt = .now

        personalRecords = personalRecordSnapshot.records
        pendingPersonalRecordCandidates = personalRecordSnapshot.pendingCandidates
        personalRecordStore.save(personalRecordSnapshot)
    }

    func dismissPersonalRecordCandidate(for distance: PersonalRecordDistance) {
        personalRecordSnapshot.pendingCandidates.removeAll { $0.distance == distance }
        personalRecordSnapshot.updatedAt = .now
        pendingPersonalRecordCandidates = personalRecordSnapshot.pendingCandidates
        personalRecordStore.save(personalRecordSnapshot)
    }

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
            monthDistanceText: formatDistance(monthDistance),
            yearDistanceText: formatDistance(yearDistance),
            trainingStatus: trainingStatus.0,
            trainingStatusDetail: trainingStatus.1,
            vo2MaxText: vo2Max.map { $0.value.formatted(.number.precision(.fractionLength(1))) } ?? "-",
            vo2MaxDateText: vo2Max.map { "업데이트 \($0.date.formatted(date: .abbreviated, time: .omitted))" } ?? "VO2 Max 데이터 없음",
            predicted5KText: predicted5K,
            predicted10KText: predicted10K,
            predictedHalfText: predictedHalf,
            predictedMarathonText: predictedMarathon
        )
    }

    private static func formatDistance(_ kilometers: Double) -> String {
        kilometers.formatted(.number.precision(.fractionLength(1))) + " km"
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

    private func updatePersonalRecords(
        _ snapshot: PersonalRecordSnapshot,
        with runs: [RunningWorkout]
    ) async throws -> PersonalRecordSnapshot {
        var updatedSnapshot = snapshot
        var recordMap = Dictionary(uniqueKeysWithValues: updatedSnapshot.records.map { ($0.distance, $0) })
        var candidateMap = Dictionary(uniqueKeysWithValues: updatedSnapshot.pendingCandidates.map { ($0.distance, $0) })
        var processedRunIDs = Set(updatedSnapshot.processedRunIDs)
        let totalRuns = runs.count
        let cutoffDate = Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? .distantPast

        for (offset, run) in runs.enumerated() where !processedRunIDs.contains(run.id) {
            let detail = try await healthKitService.fetchRunDetail(for: run)

            for distance in PersonalRecordDistance.allCases {
                guard let candidateDuration = bestDuration(for: distance.meters, in: detail.distanceTimeline) else { continue }

                let current = recordMap[distance]
                if run.startDate >= cutoffDate {
                    if current?.duration == nil || candidateDuration < (current?.duration ?? .greatestFiniteMagnitude) {
                        recordMap[distance] = PersonalRecordEntry(
                            distance: distance,
                            duration: candidateDuration,
                            date: run.startDate,
                            workoutID: run.id
                        )
                    }
                } else if candidateDuration < (current?.duration ?? .greatestFiniteMagnitude) {
                    let existingCandidate = candidateMap[distance]
                    if existingCandidate == nil || candidateDuration < (existingCandidate?.duration ?? .greatestFiniteMagnitude) {
                        candidateMap[distance] = PersonalRecordCandidate(
                            distance: distance,
                            duration: candidateDuration,
                            date: run.startDate,
                            workoutID: run.id
                        )
                    }
                }
            }

            processedRunIDs.insert(run.id)
            updatedSnapshot.records = PersonalRecordDistance.allCases.map {
                recordMap[$0] ?? PersonalRecordEntry(distance: $0, duration: nil, date: nil, workoutID: nil)
            }
            updatedSnapshot.pendingCandidates = PersonalRecordDistance.allCases.compactMap { distance in
                guard let candidate = candidateMap[distance] else { return nil }
                let currentDuration = recordMap[distance]?.duration ?? .greatestFiniteMagnitude
                return candidate.duration < currentDuration ? candidate : nil
            }
            updatedSnapshot.processedRunIDs = Array(processedRunIDs)
            updatedSnapshot.updatedAt = .now
            personalRecordSnapshot = updatedSnapshot
            personalRecords = updatedSnapshot.records
            pendingPersonalRecordCandidates = updatedSnapshot.pendingCandidates
            personalRecordProgress = Double(offset + 1) / Double(max(totalRuns, 1))
            personalRecordStore.save(updatedSnapshot)
        }

        updatedSnapshot.records = PersonalRecordDistance.allCases.map {
            recordMap[$0] ?? PersonalRecordEntry(distance: $0, duration: nil, date: nil, workoutID: nil)
        }
        updatedSnapshot.pendingCandidates = PersonalRecordDistance.allCases.compactMap { distance in
            guard let candidate = candidateMap[distance] else { return nil }
            let currentDuration = recordMap[distance]?.duration ?? .greatestFiniteMagnitude
            return candidate.duration < currentDuration ? candidate : nil
        }
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

    private func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
