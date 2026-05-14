import Foundation
import HealthKit
import CoreLocation

extension HealthKitService {
    func requestReadAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.notAvailable
        }

        let workoutType = HKObjectType.workoutType()
        let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max)
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount)
        let workoutRouteType = HKSeriesType.workoutRoute()

        var readTypes: Set<HKObjectType> = [workoutType, workoutRouteType]
        if let vo2MaxType {
            readTypes.insert(vo2MaxType)
        }
        if let heartRateType {
            readTypes.insert(heartRateType)
        }
        if let restingHeartRateType {
            readTypes.insert(restingHeartRateType)
        }
        if let distanceType {
            readTypes.insert(distanceType)
        }
        if let stepCountType {
            readTypes.insert(stepCountType)
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    // 지정한 기간의 러닝 workout을 최신순으로 읽어 목록 화면에 넘긴다.
    func fetchRunningWorkouts(
        from startDate: Date,
        to endDate: Date,
        limit: Int = HKObjectQueryNoLimit
    ) async throws -> [RunningWorkout] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.notAvailable
        }

        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [runningPredicate, datePredicate])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                let runs = workouts.map(RunningWorkout.init(workout:))
                continuation.resume(returning: runs)
            }

            healthStore.execute(query)
        }
    }

    func fetchRunningWorkout(with id: UUID) async throws -> RunningWorkout? {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.notAvailable
        }

        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let objectPredicate = HKQuery.predicateForObject(with: id)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [runningPredicate, objectPredicate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let workout = (samples as? [HKWorkout])?.first
                continuation.resume(returning: workout.map(RunningWorkout.init(workout:)))
            }

            healthStore.execute(query)
        }
    }

    // 가장 오래된 러닝 날짜는 과거 기록 로딩과 PR 재계산의 시작점이 된다.
    func fetchOldestRunningWorkoutDate() async throws -> Date? {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.notAvailable
        }

        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let oldestDate = (samples as? [HKWorkout])?.first?.startDate
                continuation.resume(returning: oldestDate)
            }

            healthStore.execute(query)
        }
    }

    // 홈 화면에는 최신 VO2 Max 한 건만 보여주므로 가장 최근 샘플만 읽는다.
    func fetchLatestVO2Max() async throws -> VO2MaxSample? {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.notAvailable
        }

        guard let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2MaxType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let value = sample.quantity.doubleValue(for: HKUnit(from: "ml/kg*min"))
                continuation.resume(returning: VO2MaxSample(value: value, date: sample.startDate))
            }

            healthStore.execute(query)
        }
    }

    // 추세 차트용으로는 최근 2년의 VO2 Max 포인트를 시간순으로 읽는다.
    func fetchVO2MaxSamples(limit: Int = 60) async throws -> [VO2MaxSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.notAvailable
        }

        guard let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max) else {
            return []
        }

        let startDate = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2MaxType,
                predicate: predicate,
                limit: max(limit, 400),
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let result = ((samples as? [HKQuantitySample]) ?? []).map {
                    VO2MaxSample(
                        value: $0.quantity.doubleValue(for: HKUnit(from: "ml/kg*min")),
                        date: $0.startDate
                    )
                }
                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    // 상세 화면 첫 진입에서는 핵심 차트와 스플릿에 필요한 데이터만 우선 읽는다.
    func fetchRunDetail(
        for runningWorkout: RunningWorkout,
        trace: RunDetailPerformanceTrace? = nil
    ) async throws -> RunDetail {
        guard let workout = runningWorkout.workout else {
            throw HealthKitServiceError.missingWorkoutReference
        }

        trace?.mark("healthkit.initial_query_start")
        async let heartRateTask = fetchHeartRates(for: workout)
        async let distanceTask = fetchDistanceSamples(for: workout)
        async let stepCountTask = fetchStepCountSamples(for: workout)

        let activeIntervals = buildActiveIntervals(for: workout)
        trace?.mark("healthkit.active_intervals_built", detail: "count=\(activeIntervals.count)")
        let distanceSamples = try await distanceTask
        trace?.mark("healthkit.distance_done", detail: "samples=\(distanceSamples.count)")
        let route = distanceSamples.isEmpty ? (try await fetchRoute(for: workout)) : []
        if distanceSamples.isEmpty {
            trace?.mark("healthkit.route_fallback_done", detail: "points=\(route.count)")
        }
        let distanceTimeline = buildDistanceTimeline(
            from: distanceSamples,
            route: route,
            activeIntervals: activeIntervals,
            targetDistance: runningWorkout.distanceInMeters,
            totalDuration: runningWorkout.duration
        )
        trace?.mark("healthkit.timeline_built", detail: "points=\(distanceTimeline.count)")
        let heartRates = mapHeartRatesToDistanceTimeline(
            try await heartRateTask,
            timeline: distanceTimeline,
            activeIntervals: activeIntervals
        )
        trace?.mark("healthkit.heart_rate_mapped", detail: "points=\(heartRates.count)")
        let stepSamples = try await stepCountTask
        trace?.mark("healthkit.steps_done", detail: "samples=\(stepSamples.count)")
        let runningMetrics = buildRunningMetrics(
            stepSamples: stepSamples,
            timeline: distanceTimeline,
            activeIntervals: activeIntervals
        )
        trace?.mark("healthkit.cadence_built", detail: "points=\(runningMetrics.cadence.count)")
        let initialHeartRateZoneProfile = heartRates.map(\.bpm).max().map {
            HeartRateZoneProfile(
                method: .observedWorkoutMaximum,
                restingHeartRateBPM: nil,
                maximumHeartRateBPM: $0
            )
        }

        let detail = RunDetail(
            route: route,
            distanceTimeline: distanceTimeline,
            heartRates: heartRates,
            runningMetrics: runningMetrics,
            paceSamples: buildPaceSamples(from: distanceTimeline),
            splits: buildSplits(
                from: distanceTimeline,
                heartRates: heartRates,
                stepSamples: stepSamples,
                activeIntervals: activeIntervals,
                totalDistance: runningWorkout.distanceInMeters,
                totalDuration: runningWorkout.duration
            ),
            activeDuration: activeIntervals.reduce(0) { partialResult, interval in
                partialResult + interval.endDate.timeIntervalSince(interval.startDate)
            },
            heartRateZoneProfile: initialHeartRateZoneProfile
        )
        trace?.mark("healthkit.detail_built", detail: "splits=\(detail.splits.count)")
        return detail
    }

    // 지도와 심박 존은 첫 화면이 뜬 뒤 보강 로딩할 수 있게 별도 진입점을 둔다.
    func fetchRunRoute(for runningWorkout: RunningWorkout) async throws -> [RunRoutePoint] {
        guard let workout = runningWorkout.workout else {
            throw HealthKitServiceError.missingWorkoutReference
        }
        return try await fetchRoute(for: workout)
    }

    func fetchRunHeartRateZoneProfile(
        for runningWorkout: RunningWorkout,
        observedMaximumHeartRate: Double?
    ) async -> HeartRateZoneProfile? {
        try? await fetchHeartRateZoneProfile(
            referenceDate: runningWorkout.startDate,
            observedMaximumHeartRate: observedMaximumHeartRate
        )
    }

    func fetchRestingHeartRateSnapshot(referenceDate: Date = Date()) async throws -> RestingHeartRateSnapshot? {
        guard let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -14, to: referenceDate) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: referenceDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: restingHeartRateType,
                predicate: predicate,
                limit: 30,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }

            healthStore.execute(query)
        }

        guard samples.count >= 3, let latestSample = samples.first else {
            return nil
        }

        let latestAge = calendar.dateComponents([.day], from: latestSample.startDate, to: referenceDate).day ?? .max
        guard latestAge <= 7 else {
            return nil
        }

        let values = samples.map {
            $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }

        guard let baseline = median(values) else {
            return nil
        }

        return RestingHeartRateSnapshot(
            latestBPM: values[0],
            baselineBPM: baseline,
            measuredAt: latestSample.startDate,
            sampleCount: values.count
        )
    }

    // 심박 존 계산은 안정시 심박과 최근 최대 심박이 있으면 그 값을 우선 활용한다.
}
