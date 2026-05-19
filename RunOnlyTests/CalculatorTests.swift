import XCTest
@testable import RunOnly

final class CalculatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let readinessBaselineBPM: Double = 52

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

    func testShoePerformanceAveragePaceUsesTotalDurationAndDistance() {
        let slowShort = makeRun(day: 2, duration: 600, distanceMeters: 1_000)
        let steadyLong = makeRun(day: 3, duration: 2_400, distanceMeters: 8_000)

        let summary = ShoePerformanceSummary.build(runs: [slowShort, steadyLong]) { _ in nil }

        XCTAssertEqual(summary.totalDuration, 3_000, accuracy: 0.001)
        XCTAssertEqual(summary.totalDistanceMeters, 9_000, accuracy: 0.001)
        XCTAssertEqual(summary.averagePaceText, RunDisplayFormatter.pace(duration: 3_000, distanceMeters: 9_000))
    }

    func testShoePerformanceAverageHeartRateIgnoresMissingValues() {
        let first = makeRun(day: 2, duration: 1_800, distanceMeters: 5_000)
        let second = makeRun(day: 3, duration: 1_700, distanceMeters: 5_000)
        let third = makeRun(day: 4, duration: 1_600, distanceMeters: 5_000)
        let heartRates: [UUID: Double] = [
            first.id: 140,
            third.id: 160
        ]

        let summary = ShoePerformanceSummary.build(runs: [first, second, third]) { heartRates[$0] }

        XCTAssertEqual(try XCTUnwrap(summary.averageHeartRate), 150, accuracy: 0.001)
    }

    func testHeartRateReserveProfileKeepsExistingZoneBoundaries() {
        let profile = HeartRateZoneProfile(
            method: .heartRateReserve,
            restingHeartRateBPM: 50,
            maximumHeartRateBPM: 190
        )

        XCTAssertEqual(profile.bpmRange(forZone: 0, lowerFraction: 0.50, upperFraction: 0.60), 120...134)
        XCTAssertEqual(profile.bpmRange(forZone: 4, lowerFraction: 0.90, upperFraction: 1.0), 176...190)
    }

    func testHeartRateZoneRowModelIncludesBPMRangeText() {
        let profile = HeartRateZoneProfile(
            method: .maxHeartRatePercent,
            restingHeartRateBPM: nil,
            maximumHeartRateBPM: 200,
            customRanges: HeartRateZoneSettings.maxHeartRateRanges(maximumHeartRateBPM: 200)
        )
        let distribution = HeartRateZoneDistribution(
            entries: [
                HeartRateZoneDistributionEntry(zoneIndex: 0, duration: 60, percentage: 0.1),
                HeartRateZoneDistributionEntry(zoneIndex: 1, duration: 120, percentage: 0.2),
                HeartRateZoneDistributionEntry(zoneIndex: 2, duration: 180, percentage: 0.3),
                HeartRateZoneDistributionEntry(zoneIndex: 3, duration: 120, percentage: 0.2),
                HeartRateZoneDistributionEntry(zoneIndex: 4, duration: 120, percentage: 0.2)
            ]
        )

        let rows = HeartRateZoneRowModel.build(
            distribution: distribution,
            heartRates: [],
            zoneProfile: profile,
            activeDuration: 600
        )

        XCTAssertEqual(rows.map(\.bpmRangeText), [
            "100-120 bpm",
            "120-140 bpm",
            "140-160 bpm",
            "160-180 bpm",
            "180-200 bpm"
        ])
    }

    func testMaxHeartRatePresetBuildsFivePercentRanges() {
        let settings = HeartRateZoneSettings(
            kind: .maxHeartRatePercent,
            maximumHeartRateBPM: 200,
            lactateThresholdBPM: 170,
            manualRanges: HeartRateZoneSettings.maxHeartRateRanges(maximumHeartRateBPM: 190)
        )

        XCTAssertEqual(settings.previewRanges.map(\.lowerBPM), [100, 120, 140, 160, 180])
        XCTAssertEqual(settings.previewRanges.map(\.upperBPM), [120, 140, 160, 180, 200])
        XCTAssertEqual(try XCTUnwrap(settings.resolvedFixedProfile).method, .maxHeartRatePercent)
    }

    func testRunningLTHRPresetUsesFrielStyleRanges() {
        let settings = HeartRateZoneSettings(
            kind: .lthrRunning,
            maximumHeartRateBPM: 190,
            lactateThresholdBPM: 170,
            manualRanges: HeartRateZoneSettings.maxHeartRateRanges(maximumHeartRateBPM: 190)
        )

        XCTAssertEqual(settings.previewRanges.map(\.lowerBPM), [1, 145, 153, 162, 170])
        XCTAssertEqual(settings.previewRanges.map(\.upperBPM), [143, 151, 160, 168, 204])
        XCTAssertEqual(try XCTUnwrap(settings.resolvedFixedProfile).method, .lthrRunning)
    }

    func testManualHeartRateZoneValidationRejectsInvertedAndOverlappingRanges() {
        var settings = HeartRateZoneSettings.default
        settings.kind = .manual
        settings.manualRanges[0].lowerBPM = 120
        settings.manualRanges[0].upperBPM = 100

        XCTAssertNotNil(settings.validationMessage)

        settings.manualRanges = [
            HeartRateZoneBPMRange(zoneIndex: 0, lowerBPM: 100, upperBPM: 120),
            HeartRateZoneBPMRange(zoneIndex: 1, lowerBPM: 120, upperBPM: 140),
            HeartRateZoneBPMRange(zoneIndex: 2, lowerBPM: 141, upperBPM: 160),
            HeartRateZoneBPMRange(zoneIndex: 3, lowerBPM: 161, upperBPM: 180),
            HeartRateZoneBPMRange(zoneIndex: 4, lowerBPM: 181, upperBPM: 200)
        ]

        XCTAssertNotNil(settings.validationMessage)

        settings.manualRanges[1].lowerBPM = 121

        XCTAssertNil(settings.validationMessage)
        XCTAssertEqual(try XCTUnwrap(settings.resolvedFixedProfile).method, .manual)
    }

    @MainActor
    func testHeartRateZoneSettingsChangeClearsProfileCache() {
        let originalSettings = HeartRateZoneSettings.load()
        defer {
            originalSettings.save()
            HeartRateZoneProfileCacheStore.shared.clearAllData()
        }

        let store = HeartRateZoneProfileCacheStore.shared
        store.save(
            HeartRateZoneProfile(
                method: .maximumHeartRate,
                restingHeartRateBPM: nil,
                maximumHeartRateBPM: 190
            )
        )
        XCTAssertNotNil(store.freshProfile)

        let appSettings = AppSettingsStore()
        appSettings.heartRateZoneSettings = HeartRateZoneSettings(
            kind: .maxHeartRatePercent,
            maximumHeartRateBPM: 200,
            lactateThresholdBPM: 170,
            manualRanges: HeartRateZoneSettings.maxHeartRateRanges(maximumHeartRateBPM: 190)
        )

        XCTAssertNil(store.freshProfile)
    }

    @MainActor
    func testShoeStoreManualReorderingPersistsArrayOrderInMemory() {
        let store = ShoeStore(loadFromDisk: false, persistsChanges: false)
        let first = RunningShoe(nickname: "First", brand: "", model: "")
        let second = RunningShoe(nickname: "Second", brand: "", model: "")
        let third = RunningShoe(nickname: "Third", brand: "", model: "")
        store.addShoe(third)
        store.addShoe(second)
        store.addShoe(first)

        store.moveShoes(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(store.shoes.map(\.displayName), ["Second", "Third", "First"])
    }

    @MainActor
    func testRunNoteStoreSavesUpdatesAndDeletesBlankNotes() {
        let store = RunNoteStore(loadFromDisk: false, persistsChanges: false)
        let runID = UUID()

        store.saveNote("  Felt smooth today  ", for: runID)
        XCTAssertEqual(store.note(for: runID)?.text, "Felt smooth today")

        store.saveNote("Easy next time", for: runID)
        XCTAssertEqual(store.note(for: runID)?.text, "Easy next time")
        XCTAssertEqual(store.notes.count, 1)

        store.saveNote("   ", for: runID)
        XCTAssertNil(store.note(for: runID))
        XCTAssertTrue(store.notes.isEmpty)
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

    func testRecoveryReadinessTreatsAppleEffortAsPrimaryLoadSignal() throws {
        let now = date(day: 20, hour: 12)
        let baseRuns = readinessBaseRuns()
        let easySixKilometers = baseRuns + [
            makeRun(day: 19, duration: 2_400, distanceMeters: 6_000, appleEffortScore: 4)
        ]
        let intervalFiveKilometers = baseRuns + [
            makeRun(day: 19, duration: 1_800, distanceMeters: 5_000, appleEffortScore: 8)
        ]

        let easyReadiness = RecoveryReadinessCalculator.build(
            from: easySixKilometers,
            restingHeartRateSnapshot: nil,
            now: now
        )
        let intervalReadiness = RecoveryReadinessCalculator.build(
            from: intervalFiveKilometers,
            restingHeartRateSnapshot: nil,
            now: now
        )

        XCTAssertLessThan(try XCTUnwrap(intervalReadiness.score), try XCTUnwrap(easyReadiness.score))
        XCTAssertEqual(easyReadiness.status, L10n.tr("보통"))
        XCTAssertEqual(intervalReadiness.status, L10n.tr("가볍게"))
        XCTAssertEqual(intervalReadiness.effortBasisText, L10n.format("Apple 노력 %d회", 4))
    }

    func testRecoveryReadinessRealisticAppleEffortScenariosStayOrdered() throws {
        let easySix = readinessScenario([
            makeRun(day: 19, duration: 2_400, distanceMeters: 6_000, appleEffortScore: 4)
        ])
        let intervalFive = readinessScenario([
            makeRun(day: 19, duration: 1_800, distanceMeters: 5_000, appleEffortScore: 8)
        ])
        let shortHard = readinessScenario([
            makeRun(day: 19, duration: 1_360, distanceMeters: 4_000, appleEffortScore: 9)
        ])
        let longEasy = readinessScenario([
            makeRun(day: 19, duration: 3_900, distanceMeters: 10_000, appleEffortScore: 4)
        ])
        let longRun = readinessScenario([
            makeRun(day: 19, duration: 5_760, distanceMeters: 16_000, appleEffortScore: 6)
        ])
        let tempoRun = readinessScenario([
            makeRun(day: 19, duration: 2_520, distanceMeters: 7_000, appleEffortScore: 7)
        ])
        let raceFive = readinessScenario([
            makeRun(day: 19, duration: 1_380, distanceMeters: 5_000, appleEffortScore: 10)
        ])
        let backToBack = readinessScenario([
            makeRun(day: 18, duration: 3_000, distanceMeters: 8_000, appleEffortScore: 6),
            makeRun(day: 19, duration: 1_800, distanceMeters: 5_000, appleEffortScore: 5)
        ])
        let singleSteadyFive = readinessScenario([
            makeRun(day: 19, duration: 1_800, distanceMeters: 5_000, appleEffortScore: 5)
        ])

        let easySixScore = try XCTUnwrap(easySix.score)
        let intervalFiveScore = try XCTUnwrap(intervalFive.score)
        let shortHardScore = try XCTUnwrap(shortHard.score)
        let longEasyScore = try XCTUnwrap(longEasy.score)
        let longRunScore = try XCTUnwrap(longRun.score)
        let tempoRunScore = try XCTUnwrap(tempoRun.score)
        let raceFiveScore = try XCTUnwrap(raceFive.score)
        let backToBackScore = try XCTUnwrap(backToBack.score)
        let singleSteadyFiveScore = try XCTUnwrap(singleSteadyFive.score)

        XCTAssertGreaterThan(easySixScore, intervalFiveScore)
        XCTAssertLessThanOrEqual(shortHardScore, intervalFiveScore)
        XCTAssertLessThan(longEasyScore, easySixScore)
        XCTAssertLessThan(longRunScore, longEasyScore)
        XCTAssertLessThan(tempoRunScore, easySixScore)
        XCTAssertLessThanOrEqual(raceFiveScore, intervalFiveScore)
        XCTAssertLessThan(backToBackScore, singleSteadyFiveScore)
        XCTAssertEqual(easySix.status, L10n.tr("보통"))
        XCTAssertEqual(intervalFive.status, L10n.tr("가볍게"))
        XCTAssertEqual(shortHard.status, L10n.tr("가볍게"))
        XCTAssertTrue([L10n.tr("보통"), L10n.tr("가볍게")].contains(longEasy.status))
        XCTAssertTrue([L10n.tr("가볍게"), L10n.tr("회복")].contains(longRun.status))
        XCTAssertTrue([L10n.tr("가볍게"), L10n.tr("회복")].contains(backToBack.status))

        [easySix, intervalFive, shortHard, longEasy, longRun, tempoRun, raceFive, singleSteadyFive].forEach {
            XCTAssertTrue($0.isDataSufficient)
            XCTAssertEqual($0.effortBasisText, L10n.format("Apple 노력 %d회", 4))
        }
        XCTAssertTrue(backToBack.isDataSufficient)
        XCTAssertEqual(backToBack.effortBasisText, L10n.format("Apple 노력 %d회", 5))
    }

    func testRecoveryReadinessRestingHeartRatePenaltyOnSameRun() throws {
        let normalHeartRate = readinessScenario(
            [makeRun(day: 19, duration: 2_400, distanceMeters: 6_000, appleEffortScore: 4)],
            restingHeartRateSnapshot: restingHeartRateSnapshot(latestBPM: 52)
        )
        let elevatedHeartRate = readinessScenario(
            [makeRun(day: 19, duration: 2_400, distanceMeters: 6_000, appleEffortScore: 4)],
            restingHeartRateSnapshot: restingHeartRateSnapshot(latestBPM: 58)
        )

        XCTAssertLessThan(try XCTUnwrap(elevatedHeartRate.score), try XCTUnwrap(normalHeartRate.score))
        XCTAssertTrue(try XCTUnwrap(elevatedHeartRate.restingHeartRateText).contains("58"))
    }

    func testRecoveryReadinessFallsBackToPNREstimateWithoutAppleEffort() throws {
        let fallbackReadiness = RecoveryReadinessCalculator.build(
            from: readinessBaseRuns(appleEffortScore: nil) + [
                makeRun(day: 19, duration: 1_800, distanceMeters: 5_000)
            ],
            restingHeartRateSnapshot: restingHeartRateSnapshot(latestBPM: 52),
            now: date(day: 20, hour: 12)
        )

        XCTAssertNotNil(fallbackReadiness.score)
        XCTAssertTrue(fallbackReadiness.isDataSufficient)
        XCTAssertEqual(fallbackReadiness.effortBasisText, L10n.tr("PNR 추정"))
        XCTAssertTrue(fallbackReadiness.factors.contains(L10n.tr("Apple 노력 점수가 없어 시간과 페이스로 강도를 추정했어요")))
    }

    func testRecoveryReadinessCorrectsMarathonTrainingEdgeCases() throws {
        let easyEight = readinessScenario([
            makeRun(day: 19, duration: 3_120, distanceMeters: 8_000, appleEffortScore: 4)
        ])
        let tenKilometerRace = readinessScenario([
            makeRun(day: 19, duration: 2_700, distanceMeters: 10_000, appleEffortScore: 10)
        ])
        let longTwenty = readinessScenario([
            makeRun(day: 19, duration: 7_200, distanceMeters: 20_000, appleEffortScore: 6)
        ])
        let longTwentyFour = readinessScenario([
            makeRun(day: 19, duration: 9_000, distanceMeters: 24_000, appleEffortScore: 6)
        ])
        let progressionEighteen = readinessScenario([
            makeRun(day: 19, duration: 6_000, distanceMeters: 18_000, appleEffortScore: 7)
        ])
        let trailTwelve = readinessScenario([
            makeRun(day: 19, duration: 4_800, distanceMeters: 12_000, appleEffortScore: 7)
        ])
        let restedEasy = RecoveryReadinessCalculator.build(
            from: readinessBaseRuns() + [
                makeRun(day: 16, duration: 2_400, distanceMeters: 6_000, appleEffortScore: 4)
            ],
            restingHeartRateSnapshot: restingHeartRateSnapshot(latestBPM: readinessBaselineBPM),
            now: date(day: 20, hour: 12)
        )
        let noHeartRateEasy = RecoveryReadinessCalculator.build(
            from: readinessBaseRuns() + [
                makeRun(day: 19, duration: 2_400, distanceMeters: 6_000, appleEffortScore: 4)
            ],
            restingHeartRateSnapshot: nil,
            now: date(day: 20, hour: 12)
        )
        let tempoThenEasy = readinessScenario([
            makeRun(day: 17, duration: 2_220, distanceMeters: 8_000, appleEffortScore: 7),
            makeRun(day: 18, duration: 1_980, distanceMeters: 5_000, appleEffortScore: 4),
            makeRun(day: 19, duration: 2_340, distanceMeters: 6_000, appleEffortScore: 4)
        ])
        let highEasyWeek = RecoveryReadinessCalculator.build(
            from: marathonReadinessBaseRuns() + [
                makeRun(day: 15, duration: 2_340, distanceMeters: 6_000, appleEffortScore: 4),
                makeRun(day: 16, duration: 3_120, distanceMeters: 8_000, appleEffortScore: 4),
                makeRun(day: 17, duration: 3_840, distanceMeters: 10_000, appleEffortScore: 5),
                makeRun(day: 18, duration: 2_340, distanceMeters: 6_000, appleEffortScore: 4),
                makeRun(day: 19, duration: 2_340, distanceMeters: 6_000, appleEffortScore: 4)
            ],
            restingHeartRateSnapshot: restingHeartRateSnapshot(latestBPM: readinessBaselineBPM),
            now: date(day: 20, hour: 12)
        )

        XCTAssertEqual(easyEight.status, L10n.tr("보통"))
        XCTAssertEqual(tenKilometerRace.status, L10n.tr("회복"))
        XCTAssertEqual(longTwenty.status, L10n.tr("회복"))
        XCTAssertEqual(longTwentyFour.status, L10n.tr("회복"))
        XCTAssertEqual(progressionEighteen.status, L10n.tr("회복"))
        XCTAssertEqual(trailTwelve.status, L10n.tr("회복"))
        XCTAssertTrue([L10n.tr("보통"), L10n.tr("좋음")].contains(restedEasy.status))
        XCTAssertEqual(noHeartRateEasy.status, L10n.tr("보통"))
        XCTAssertEqual(tempoThenEasy.status, L10n.tr("가볍게"))
        XCTAssertEqual(highEasyWeek.status, L10n.tr("가볍게"))
    }

    func testRecoveryReadinessBeginnerProfileStaysConservative() throws {
        let beginnerBaseRuns = beginnerReadinessBaseRuns()
        let easyThree = readinessScenario([
            makeRun(day: 19, duration: 1_500, distanceMeters: 3_000, appleEffortScore: 4)
        ], baseRuns: beginnerBaseRuns)
        let easyFive = readinessScenario([
            makeRun(day: 19, duration: 2_700, distanceMeters: 5_000, appleEffortScore: 4)
        ], baseRuns: beginnerBaseRuns)
        let easySix = readinessScenario([
            makeRun(day: 19, duration: 3_300, distanceMeters: 6_000, appleEffortScore: 4)
        ], baseRuns: beginnerBaseRuns)
        let easyEight = readinessScenario([
            makeRun(day: 19, duration: 4_800, distanceMeters: 8_000, appleEffortScore: 4)
        ], baseRuns: beginnerBaseRuns)
        let shortIntervals = readinessScenario([
            makeRun(day: 19, duration: 1_500, distanceMeters: 3_000, appleEffortScore: 8)
        ], baseRuns: beginnerBaseRuns)
        let fiveKilometerRace = readinessScenario([
            makeRun(day: 19, duration: 1_800, distanceMeters: 5_000, appleEffortScore: 10)
        ], baseRuns: beginnerBaseRuns)

        XCTAssertEqual(easyThree.status, L10n.tr("보통"))
        XCTAssertTrue([L10n.tr("보통"), L10n.tr("가볍게")].contains(easyFive.status))
        XCTAssertEqual(easySix.status, L10n.tr("가볍게"))
        XCTAssertTrue([L10n.tr("가볍게"), L10n.tr("회복")].contains(easyEight.status))
        XCTAssertEqual(shortIntervals.status, L10n.tr("가볍게"))
        XCTAssertEqual(fiveKilometerRace.status, L10n.tr("회복"))
    }

    func testRecoveryReadinessTenKProfileBalancesEasyAndLongRuns() throws {
        let easyFive = readinessScenario([
            makeRun(day: 19, duration: 2_000, distanceMeters: 5_000, appleEffortScore: 4)
        ])
        let easySeven = readinessScenario([
            makeRun(day: 19, duration: 2_700, distanceMeters: 7_000, appleEffortScore: 4)
        ])
        let easyTen = readinessScenario([
            makeRun(day: 19, duration: 3_900, distanceMeters: 10_000, appleEffortScore: 4)
        ])
        let tempoSix = readinessScenario([
            makeRun(day: 19, duration: 2_100, distanceMeters: 6_000, appleEffortScore: 7)
        ])
        let tenKilometerRace = readinessScenario([
            makeRun(day: 19, duration: 2_700, distanceMeters: 10_000, appleEffortScore: 10)
        ])
        let twelveKilometerLongRun = readinessScenario([
            makeRun(day: 19, duration: 4_800, distanceMeters: 12_000, appleEffortScore: 5)
        ])
        let fourteenKilometerLongRun = readinessScenario([
            makeRun(day: 19, duration: 5_600, distanceMeters: 14_000, appleEffortScore: 6)
        ])

        XCTAssertEqual(easyFive.status, L10n.tr("보통"))
        XCTAssertEqual(easySeven.status, L10n.tr("보통"))
        XCTAssertTrue([L10n.tr("보통"), L10n.tr("가볍게")].contains(easyTen.status))
        XCTAssertEqual(tempoSix.status, L10n.tr("가볍게"))
        XCTAssertEqual(tenKilometerRace.status, L10n.tr("회복"))
        XCTAssertEqual(twelveKilometerLongRun.status, L10n.tr("가볍게"))
        XCTAssertEqual(fourteenKilometerLongRun.status, L10n.tr("회복"))
    }

    func testRecoveryReadinessTwentyFiveKilometerWeekBecomesHalfReadyWithLongRunBase() throws {
        let halfReadyBaseRuns = halfReadyReadinessBaseRuns()
        let easyEight = readinessScenario([
            makeRun(day: 29, duration: 3_120, distanceMeters: 8_000, appleEffortScore: 4)
        ], baseRuns: halfReadyBaseRuns, now: date(day: 30, hour: 12))
        let steadyTwelve = readinessScenario([
            makeRun(day: 29, duration: 4_800, distanceMeters: 12_000, appleEffortScore: 5)
        ], baseRuns: halfReadyBaseRuns, now: date(day: 30, hour: 12))
        let longSixteen = readinessScenario([
            makeRun(day: 29, duration: 6_400, distanceMeters: 16_000, appleEffortScore: 6)
        ], baseRuns: halfReadyBaseRuns, now: date(day: 30, hour: 12))
        let tenKilometerRace = readinessScenario([
            makeRun(day: 29, duration: 2_700, distanceMeters: 10_000, appleEffortScore: 10)
        ], baseRuns: halfReadyBaseRuns, now: date(day: 30, hour: 12))
        let accumulatedEasyRuns = readinessScenario([
            makeRun(day: 27, duration: 3_120, distanceMeters: 8_000, appleEffortScore: 4),
            makeRun(day: 28, duration: 3_900, distanceMeters: 10_000, appleEffortScore: 4),
            makeRun(day: 29, duration: 3_120, distanceMeters: 8_000, appleEffortScore: 4)
        ], baseRuns: halfReadyBaseRuns, now: date(day: 30, hour: 12))

        XCTAssertEqual(easyEight.status, L10n.tr("보통"))
        XCTAssertTrue([L10n.tr("보통"), L10n.tr("가볍게")].contains(steadyTwelve.status))
        XCTAssertEqual(longSixteen.status, L10n.tr("가볍게"))
        XCTAssertEqual(tenKilometerRace.status, L10n.tr("회복"))
        XCTAssertEqual(accumulatedEasyRuns.status, L10n.tr("가볍게"))
    }

    func testRecoveryReadinessHalfFullProfileCapsMidLongBoundaryRuns() throws {
        let halfFullBaseRuns = halfFullReadinessBaseRuns()
        let easyFifteenPointFour = readinessScenario([
            makeRun(day: 29, duration: 5_775, distanceMeters: 15_400, appleEffortScore: 5)
        ], baseRuns: halfFullBaseRuns, now: date(day: 30, hour: 12))
        let easySixteen = readinessScenario([
            makeRun(day: 29, duration: 6_000, distanceMeters: 16_000, appleEffortScore: 5)
        ], baseRuns: halfFullBaseRuns, now: date(day: 30, hour: 12))

        XCTAssertTrue([L10n.tr("보통"), L10n.tr("가볍게")].contains(easyFifteenPointFour.status))
        XCTAssertEqual(easySixteen.status, L10n.tr("가볍게"))
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
        distanceMeters: Double,
        appleEffortScore: Double? = nil
    ) -> RunningWorkout {
        RunningWorkout(
            startDate: date(month: month, day: day, hour: 7),
            duration: duration,
            distanceInMeters: distanceMeters,
            sourceName: "RunOnly Test",
            sourceBundleIdentifier: "com.apple.health",
            isIndoorWorkout: false,
            appleEffort: appleEffortScore.map {
                WorkoutEffort(score: $0, source: .appleWorkout, measuredAt: date(month: month, day: day, hour: 8))
            }
        )
    }

    private func readinessScenario(
        _ additionalRuns: [RunningWorkout],
        baseRuns: [RunningWorkout]? = nil,
        restingHeartRateSnapshot: RestingHeartRateSnapshot? = nil,
        now: Date? = nil
    ) -> RecoveryReadiness {
        RecoveryReadinessCalculator.build(
            from: (baseRuns ?? readinessBaseRuns()) + additionalRuns,
            restingHeartRateSnapshot: restingHeartRateSnapshot ?? self.restingHeartRateSnapshot(latestBPM: readinessBaselineBPM),
            now: now ?? date(day: 20, hour: 12)
        )
    }

    private func readinessBaseRuns(appleEffortScore: Double? = 5) -> [RunningWorkout] {
        [
            makeRun(day: 7, duration: 2_660, distanceMeters: 7_000, appleEffortScore: appleEffortScore),
            makeRun(day: 10, duration: 3_040, distanceMeters: 8_000, appleEffortScore: appleEffortScore),
            makeRun(day: 13, duration: 3_900, distanceMeters: 10_000, appleEffortScore: appleEffortScore)
        ]
    }

    private func beginnerReadinessBaseRuns() -> [RunningWorkout] {
        [
            makeRun(day: 7, duration: 1_800, distanceMeters: 3_000, appleEffortScore: 4),
            makeRun(day: 10, duration: 2_400, distanceMeters: 4_000, appleEffortScore: 4),
            makeRun(day: 13, duration: 3_300, distanceMeters: 5_000, appleEffortScore: 5)
        ]
    }

    private func halfReadyReadinessBaseRuns() -> [RunningWorkout] {
        [
            makeRun(day: 3, duration: 3_200, distanceMeters: 8_000, appleEffortScore: 5),
            makeRun(day: 6, duration: 4_800, distanceMeters: 12_000, appleEffortScore: 5),
            makeRun(day: 9, duration: 5_600, distanceMeters: 14_000, appleEffortScore: 5),
            makeRun(day: 12, duration: 4_000, distanceMeters: 10_000, appleEffortScore: 5),
            makeRun(day: 15, duration: 4_800, distanceMeters: 12_000, appleEffortScore: 5),
            makeRun(day: 18, duration: 5_600, distanceMeters: 14_000, appleEffortScore: 5),
            makeRun(day: 21, duration: 6_400, distanceMeters: 16_000, appleEffortScore: 6),
            makeRun(day: 24, duration: 5_600, distanceMeters: 14_000, appleEffortScore: 5)
        ]
    }

    private func marathonReadinessBaseRuns() -> [RunningWorkout] {
        [
            makeRun(day: 1, duration: 2_340, distanceMeters: 6_000, appleEffortScore: 5),
            makeRun(day: 4, duration: 3_120, distanceMeters: 8_000, appleEffortScore: 5),
            makeRun(day: 7, duration: 4_560, distanceMeters: 12_000, appleEffortScore: 5),
            makeRun(day: 10, duration: 2_100, distanceMeters: 5_000, appleEffortScore: 4),
            makeRun(day: 13, duration: 3_120, distanceMeters: 8_000, appleEffortScore: 5)
        ]
    }

    private func halfFullReadinessBaseRuns() -> [RunningWorkout] {
        [
            makeRun(day: 3, duration: 3_750, distanceMeters: 10_000, appleEffortScore: 5),
            makeRun(day: 6, duration: 4_500, distanceMeters: 12_000, appleEffortScore: 5),
            makeRun(day: 9, duration: 5_250, distanceMeters: 14_000, appleEffortScore: 5),
            makeRun(day: 12, duration: 6_000, distanceMeters: 16_000, appleEffortScore: 5),
            makeRun(day: 15, duration: 6_750, distanceMeters: 18_000, appleEffortScore: 6),
            makeRun(day: 18, duration: 3_750, distanceMeters: 10_000, appleEffortScore: 5),
            makeRun(day: 21, duration: 4_500, distanceMeters: 12_000, appleEffortScore: 5),
            makeRun(day: 24, duration: 5_250, distanceMeters: 14_000, appleEffortScore: 5)
        ]
    }

    private func restingHeartRateSnapshot(latestBPM: Double) -> RestingHeartRateSnapshot {
        RestingHeartRateSnapshot(
            latestBPM: latestBPM,
            baselineBPM: readinessBaselineBPM,
            measuredAt: date(day: 20, hour: 6),
            sampleCount: 14
        )
    }

    private func date(month: Int = 5, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
}
