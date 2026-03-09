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

    private(set) var allRuns: [RunningWorkout] = []
    private var latestVO2Max: VO2MaxSample?
    private var oldestRunningWorkoutDate: Date?
    private var nextHistoryMonthStart: Date?

    private let healthKitService = HealthKitService()

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
        } catch {
            state = .failed(error.localizedDescription)
        }
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

    private func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
