import XCTest
@testable import RunOnly

final class CalculatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testPersonalRecordBestDurationUsesInterpolatedSlidingWindow() {
        let timeline = [
            DistanceTimelinePoint(date: date(day: 1, hour: 7, minute: 0), elapsed: 0, distanceMeters: 0, segmentIndex: 0),
            DistanceTimelinePoint(date: date(day: 1, hour: 7, minute: 2), elapsed: 120, distanceMeters: 500, segmentIndex: 0),
            DistanceTimelinePoint(date: date(day: 1, hour: 7, minute: 5), elapsed: 300, distanceMeters: 1_500, segmentIndex: 0),
            DistanceTimelinePoint(date: date(day: 1, hour: 7, minute: 7), elapsed: 420, distanceMeters: 2_000, segmentIndex: 0)
        ]

        let bestOneKilometer = PersonalRecordCalculator.bestDuration(for: 1_000, in: timeline)

        XCTAssertEqual(try XCTUnwrap(bestOneKilometer), 180, accuracy: 0.001)
    }

    func testPersonalRecordBestDurationReturnsNilWhenTimelineIsTooShort() {
        let timeline = [
            DistanceTimelinePoint(date: date(day: 1), elapsed: 0, distanceMeters: 0, segmentIndex: 0),
            DistanceTimelinePoint(date: date(day: 1, minute: 4), elapsed: 240, distanceMeters: 900, segmentIndex: 0)
        ]

        XCTAssertNil(PersonalRecordCalculator.bestDuration(for: 1_000, in: timeline))
    }

    func testMileageRecordMonthSummaryCountsDistanceDurationAndRunningDays() {
        let monthStart = date(day: 1)
        let runs = [
            makeRun(day: 2, duration: 1_800, distanceMeters: 5_000),
            makeRun(day: 2, duration: 900, distanceMeters: 2_000),
            makeRun(day: 8, duration: 2_400, distanceMeters: 8_000)
        ]

        let summary = MileageAggregator.recordMonthSummary(from: runs, monthStart: monthStart)

        XCTAssertEqual(summary.runCount, 3)
        XCTAssertEqual(summary.totalDistanceKilometers, 15, accuracy: 0.001)
        XCTAssertEqual(summary.totalDuration, 5_100, accuracy: 0.001)
        XCTAssertEqual(summary.runningDays, 2)
        XCTAssertGreaterThan(summary.weeklyRunFrequency, 0)
    }

    func testRecoveryReadinessRequiresAtLeastThreeRecentRuns() {
        let now = date(day: 20, hour: 12)
        let runs = [
            makeRun(day: 18, duration: 1_800, distanceMeters: 5_000),
            makeRun(day: 19, duration: 1_500, distanceMeters: 4_000)
        ]

        let readiness = RecoveryReadinessCalculator.build(
            from: runs,
            restingHeartRateSnapshot: nil,
            now: now
        )

        XCTAssertNil(readiness.score)
        XCTAssertFalse(readiness.isDataSufficient)
        XCTAssertEqual(readiness.dataRequirementText, L10n.tr("최근 28일 안에 최소 3회의 러닝이 필요합니다."))
    }

    func testRecoveryReadinessRequiresRecentTenDayRun() {
        let now = date(day: 30, hour: 12)
        let runs = [
            makeRun(day: 3, duration: 1_800, distanceMeters: 5_000),
            makeRun(day: 8, duration: 1_700, distanceMeters: 5_000),
            makeRun(day: 15, duration: 1_600, distanceMeters: 5_000)
        ]

        let readiness = RecoveryReadinessCalculator.build(
            from: runs,
            restingHeartRateSnapshot: nil,
            now: now
        )

        XCTAssertNil(readiness.score)
        XCTAssertFalse(readiness.isDataSufficient)
        XCTAssertEqual(readiness.dataRequirementText, L10n.tr("최근 10일 안에 러닝이 한 번 이상 필요합니다."))
    }

    func testRunningSummaryBuildsCurrentMonthAndYearDistances() {
        let now = date(month: 5, day: 20)
        let runs = [
            makeRun(month: 5, day: 2, duration: 1_800, distanceMeters: 5_000),
            makeRun(month: 5, day: 8, duration: 2_400, distanceMeters: 8_000),
            makeRun(month: 4, day: 12, duration: 1_500, distanceMeters: 4_000)
        ]

        let summary = RunningSummaryBuilder.build(
            from: runs,
            vo2Max: nil,
            restingHeartRateSnapshot: nil,
            now: now
        )

        XCTAssertEqual(summary.monthDistanceKilometers, 13, accuracy: 0.001)
        XCTAssertEqual(summary.yearDistanceKilometers, 17, accuracy: 0.001)
        XCTAssertEqual(summary.vo2MaxText, "-")
    }

    private func makeRun(
        month: Int = 5,
        day: Int,
        duration: TimeInterval,
        distanceMeters: Double
    ) -> RunningWorkout {
        RunningWorkout(
            startDate: date(month: month, day: day, hour: 7),
            duration: duration,
            distanceInMeters: distanceMeters,
            sourceName: "RunOnly Test",
            sourceBundleIdentifier: "com.apple.health",
            isIndoorWorkout: false
        )
    }

    private func date(month: Int = 5, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
}
