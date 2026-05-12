import Foundation

enum MileageAggregator {
    static func monthlyPeriods(from runs: [RunningWorkout]) -> [MileagePeriod] {
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
                distanceText: formatDistance(distance)
            )
        }
    }

    static func yearlyPeriods(from runs: [RunningWorkout]) -> [MileagePeriod] {
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
                distanceText: formatDistance(distance)
            )
        }
    }

    static func recordMonthSummary(from monthRuns: [RunningWorkout], monthStart: Date) -> RecordMonthSummary {
        let totalDistanceKilometers = monthRuns.reduce(0) { $0 + $1.distanceInKilometers }
        let totalDuration = monthRuns.reduce(0) { $0 + $1.duration }
        let runningDays = Set(monthRuns.map { Calendar.current.startOfDay(for: $0.startDate) }).count
        let weeksInMonth = Double(max(Calendar.current.range(of: .weekOfMonth, in: .month, for: monthStart)?.count ?? 1, 1))

        return RecordMonthSummary(
            monthStart: monthStart,
            runCount: monthRuns.count,
            totalDistanceKilometers: totalDistanceKilometers,
            totalDuration: totalDuration,
            runningDays: runningDays,
            weeklyRunFrequency: Double(monthRuns.count) / weeksInMonth
        )
    }

    private static func formatDistance(_ kilometers: Double) -> String {
        RunDisplayFormatter.distance(kilometers: kilometers, fractionLength: 1)
    }
}
