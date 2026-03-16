import Foundation
import HealthKit
import CoreLocation

// HealthKit을 사용할 수 없는 기기에서 보여줄 공통 오류다.
enum HealthKitServiceError: Equatable, LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "이 기기에서는 HealthKit을 사용할 수 없습니다."
        }
    }
}

// HealthKit 쿼리와 후처리를 한곳에 모아 ViewModel이 화면 상태 관리에만 집중하게 한다.
final class HealthKitService {
    private let healthStore = HKHealthStore()

    // 앱이 실제로 사용하는 모든 읽기 권한을 한 번에 요청한다.
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
        let runningPowerType = HKObjectType.quantityType(forIdentifier: .runningPower)
        let runningSpeedType = HKObjectType.quantityType(forIdentifier: .runningSpeed)
        let strideLengthType = HKObjectType.quantityType(forIdentifier: .runningStrideLength)
        let verticalOscillationType = HKObjectType.quantityType(forIdentifier: .runningVerticalOscillation)
        let groundContactTimeType = HKObjectType.quantityType(forIdentifier: .runningGroundContactTime)
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
        if let runningPowerType {
            readTypes.insert(runningPowerType)
        }
        if let runningSpeedType {
            readTypes.insert(runningSpeedType)
        }
        if let strideLengthType {
            readTypes.insert(strideLengthType)
        }
        if let verticalOscillationType {
            readTypes.insert(verticalOscillationType)
        }
        if let groundContactTimeType {
            readTypes.insert(groundContactTimeType)
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

    // 상세 화면은 여러 HealthKit 쿼리를 병렬 실행한 뒤 하나의 RunDetail로 합친다.
    func fetchRunDetail(for runningWorkout: RunningWorkout) async throws -> RunDetail {
        async let routeTask = fetchRoute(for: runningWorkout.workout)
        async let heartRateTask = fetchHeartRates(for: runningWorkout.workout)
        async let distanceTask = fetchDistanceSamples(for: runningWorkout.workout)
        async let stepCountTask = fetchStepCountSamples(for: runningWorkout.workout)
        async let runningPowerTask = fetchQuantitySamples(
            for: runningWorkout.workout,
            identifier: .runningPower,
            unit: .watt()
        )
        async let runningSpeedTask = fetchQuantitySamples(
            for: runningWorkout.workout,
            identifier: .runningSpeed,
            unit: HKUnit.meter().unitDivided(by: .second())
        )
        async let strideLengthTask = fetchQuantitySamples(
            for: runningWorkout.workout,
            identifier: .runningStrideLength,
            unit: .meter()
        )
        async let verticalOscillationTask = fetchQuantitySamples(
            for: runningWorkout.workout,
            identifier: .runningVerticalOscillation,
            unit: HKUnit.meterUnit(with: .centi)
        )
        async let groundContactTimeTask = fetchQuantitySamples(
            for: runningWorkout.workout,
            identifier: .runningGroundContactTime,
            unit: HKUnit.secondUnit(with: .milli)
        )

        let activeIntervals = buildActiveIntervals(for: runningWorkout.workout)
        let route = try await routeTask
        let distanceTimeline = buildDistanceTimeline(
            from: try await distanceTask,
            route: route,
            activeIntervals: activeIntervals,
            targetDistance: runningWorkout.distanceInMeters,
            totalDuration: runningWorkout.duration
        )
        let heartRates = mapHeartRatesToDistanceTimeline(
            try await heartRateTask,
            timeline: distanceTimeline,
            activeIntervals: activeIntervals
        )
        let stepSamples = try await stepCountTask
        let runningMetrics = buildRunningMetrics(
            stepSamples: stepSamples,
            powerSamples: try await runningPowerTask,
            speedSamples: try await runningSpeedTask,
            strideLengthSamples: try await strideLengthTask,
            verticalOscillationSamples: try await verticalOscillationTask,
            groundContactTimeSamples: try await groundContactTimeTask,
            timeline: distanceTimeline,
            activeIntervals: activeIntervals
        )
        let observedMaximumHeartRate = heartRates.map(\.bpm).max()
        let heartRateZoneProfile = try? await fetchHeartRateZoneProfile(
            referenceDate: runningWorkout.startDate,
            observedMaximumHeartRate: observedMaximumHeartRate
        )

        return RunDetail(
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
            heartRateZoneProfile: heartRateZoneProfile
        )
    }

    // 심박 존 계산은 안정시 심박과 최근 최대 심박이 있으면 그 값을 우선 활용한다.
    private func fetchHeartRateZoneProfile(
        referenceDate: Date,
        observedMaximumHeartRate: Double?
    ) async throws -> HeartRateZoneProfile? {
        async let restingHeartRateTask = fetchLatestRestingHeartRate(before: referenceDate)
        async let recentMaximumHeartRateTask = fetchRecentMaximumHeartRate(before: referenceDate)

        let restingHeartRate = try await restingHeartRateTask
        let recentMaximumHeartRate = try await recentMaximumHeartRateTask

        if let recentMaximumHeartRate,
           let restingHeartRate,
           recentMaximumHeartRate > restingHeartRate + 20 {
            return HeartRateZoneProfile(
                method: .heartRateReserve,
                restingHeartRateBPM: restingHeartRate,
                maximumHeartRateBPM: recentMaximumHeartRate
            )
        }

        if let recentMaximumHeartRate {
            return HeartRateZoneProfile(
                method: .maximumHeartRate,
                restingHeartRateBPM: restingHeartRate,
                maximumHeartRateBPM: recentMaximumHeartRate
            )
        }

        if let observedMaximumHeartRate {
            return HeartRateZoneProfile(
                method: .observedWorkoutMaximum,
                restingHeartRateBPM: nil,
                maximumHeartRateBPM: observedMaximumHeartRate
            )
        }

        return nil
    }

    // HRR 방식 계산을 위해 최근 안정시 심박 한 건을 가져온다.
    private func fetchLatestRestingHeartRate(before referenceDate: Date) async throws -> Double? {
        guard let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }

        let startDate = Calendar.current.date(byAdding: .month, value: -6, to: referenceDate) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: referenceDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: restingHeartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = (samples as? [HKQuantitySample])?.first else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(
                    returning: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                )
            }

            healthStore.execute(query)
        }
    }

    // 최근 1년 최대 심박을 구해 심박 존 상한값을 보다 현실적으로 잡는다.
    private func fetchRecentMaximumHeartRate(before referenceDate: Date) async throws -> Double? {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }

        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: referenceDate) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: referenceDate, options: .strictEndDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteMax
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let maximumHeartRate = statistics?
                    .maximumQuantity()?
                    .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: maximumHeartRate)
            }

            healthStore.execute(query)
        }
    }

    // 여러 workout route를 하나의 경로 배열로 모아 지도에 바로 쓸 수 있게 만든다.
    private func fetchRoute(for workout: HKWorkout) async throws -> [RunRoutePoint] {
        let predicate = HKQuery.predicateForObjects(from: workout)

        let routeSamples: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }

            healthStore.execute(query)
        }

        var rawPoints: [RawRoutePoint] = []
        for routeSample in routeSamples {
            let routePoints = try await fetchLocations(for: routeSample)
            rawPoints.append(contentsOf: routePoints)
        }

        let sortedPoints = rawPoints.sorted(by: { $0.timestamp < $1.timestamp })
        return buildRoutePoints(from: sortedPoints)
    }

    // route query는 여러 번 콜백되므로 done 시점까지 좌표를 누적한다.
    private func fetchLocations(for route: HKWorkoutRoute) async throws -> [RawRoutePoint] {
        try await withCheckedThrowingContinuation { continuation in
            var collected: [RawRoutePoint] = []
            let query = HKWorkoutRouteQuery(route: route) { _, locationsOrNil, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let locationsOrNil {
                    collected.append(contentsOf: locationsOrNil.map {
                        RawRoutePoint(
                            latitude: $0.coordinate.latitude,
                            longitude: $0.coordinate.longitude,
                            timestamp: $0.timestamp,
                            altitudeMeters: $0.verticalAccuracy >= 0 ? $0.altitude : nil
                        )
                    })
                }

                if done {
                    continuation.resume(returning: collected)
                }
            }

            healthStore.execute(query)
        }
    }

    // 심박은 우선 시간순 원본 배열로 가져온 뒤, 나중에 거리 타임라인에 맞춰 붙인다.
    private func fetchHeartRates(for workout: HKWorkout) async throws -> [HeartRateSample] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        let predicate = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let heartRates = ((samples as? [HKQuantitySample]) ?? []).map {
                    HeartRateSample(
                        date: $0.startDate,
                        bpm: $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                        elapsed: nil,
                        distanceMeters: nil,
                        segmentIndex: nil
                    )
                }

                continuation.resume(returning: heartRates)
            }

            healthStore.execute(query)
        }
    }

    // 거리 샘플은 페이스/스플릿 계산의 가장 정확한 기준 데이터다.
    private func fetchDistanceSamples(for workout: HKWorkout) async throws -> [RawDistanceSample] {
        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return []
        }

        let predicate = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: distanceType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let distanceSamples = ((samples as? [HKQuantitySample]) ?? []).compactMap { sample -> RawDistanceSample? in
                    let distanceMeters = sample.quantity.doubleValue(for: .meter())
                    guard distanceMeters > 0, sample.endDate > sample.startDate else { return nil }
                    return RawDistanceSample(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        distanceMeters: distanceMeters
                    )
                }

                continuation.resume(returning: distanceSamples)
            }

            healthStore.execute(query)
        }
    }

    // 걸음 수는 케이던스 계산용 보조 데이터로 사용한다.
    private func fetchStepCountSamples(for workout: HKWorkout) async throws -> [RawStepSample] {
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return []
        }

        let predicate = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepCountType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let stepSamples = ((samples as? [HKQuantitySample]) ?? []).compactMap { sample -> RawStepSample? in
                    let stepCount = sample.quantity.doubleValue(for: .count())
                    guard stepCount > 0, sample.endDate > sample.startDate else { return nil }
                    return RawStepSample(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        count: stepCount
                    )
                }

                continuation.resume(returning: stepSamples)
            }

            healthStore.execute(query)
        }
    }

    // 파워, 속도, 보폭 등 추가 메트릭은 공통 쿼리 함수 하나로 읽는다.
    private func fetchQuantitySamples(
        for workout: HKWorkout,
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> [RawQuantitySample] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let predicate = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let quantitySamples = ((samples as? [HKQuantitySample]) ?? []).compactMap { sample -> RawQuantitySample? in
                    let value = sample.quantity.doubleValue(for: unit)
                    guard value.isFinite, sample.endDate > sample.startDate else { return nil }
                    return RawQuantitySample(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        value: value
                    )
                }

                continuation.resume(returning: quantitySamples)
            }

            healthStore.execute(query)
        }
    }

    // 거리 타임라인에서 일정 간격의 페이스 샘플만 추려 차트 노이즈를 줄인다.
    private func buildPaceSamples(from timeline: [DistanceTimelinePoint]) -> [PaceSample] {
        guard timeline.count > 1 else { return [] }

        var samples: [PaceSample] = []
        var lastIncludedElapsed = timeline[0].elapsed - 10

        for index in 1..<timeline.count {
            let currentPoint = timeline[index]
            guard currentPoint.elapsed - lastIncludedElapsed >= 1 else { continue }

            let segmentStartIndex = timeline[..<index].lastIndex(where: {
                $0.segmentIndex != currentPoint.segmentIndex
            }).map { $0 + 1 } ?? 0

            var lookbackIndex = index - 1
            while lookbackIndex > segmentStartIndex,
                  currentPoint.elapsed - timeline[lookbackIndex].elapsed < 10 {
                lookbackIndex -= 1
            }

            let startPoint = timeline[lookbackIndex]

            let distanceWindow = currentPoint.distanceMeters - startPoint.distanceMeters
            let durationWindow = currentPoint.elapsed - startPoint.elapsed
            guard distanceWindow >= 10, durationWindow >= 5 else { continue }

            let secondsPerKilometer = durationWindow / (distanceWindow / 1_000)
            guard secondsPerKilometer.isFinite, (150...900).contains(secondsPerKilometer) else { continue }

            samples.append(
                PaceSample(
                    date: currentPoint.date,
                    distanceMeters: currentPoint.distanceMeters,
                    secondsPerKilometer: secondsPerKilometer,
                    segmentIndex: currentPoint.segmentIndex
                )
            )
            lastIncludedElapsed = currentPoint.elapsed
        }

        return samples
    }

    // 거리/심박/걸음 수를 조합해 km 스플릿 테이블 데이터를 만든다.
    private func buildSplits(
        from timeline: [DistanceTimelinePoint],
        heartRates: [HeartRateSample],
        stepSamples: [RawStepSample],
        activeIntervals: [ActiveInterval],
        totalDistance: Double,
        totalDuration: TimeInterval
    ) -> [RunSplit] {
        guard timeline.count > 1, totalDistance > 0 else { return [] }

        var splits: [RunSplit] = []
        var nextSplitDistance: Double = 1_000
        var splitStartElapsed: TimeInterval = 0

        for index in 1..<timeline.count {
            let previous = timeline[index - 1]
            let current = timeline[index]
            let segmentStartDistance = previous.distanceMeters
            let accumulatedDistance = current.distanceMeters
            let segmentDistance = accumulatedDistance - segmentStartDistance
            let segmentDuration = current.elapsed - previous.elapsed
            guard segmentDistance > 0, segmentDuration > 0 else { continue }

            while accumulatedDistance >= nextSplitDistance {
                let distanceIntoSegment = nextSplitDistance - segmentStartDistance
                let ratio = distanceIntoSegment / segmentDistance
                let splitElapsed = previous.elapsed + (segmentDuration * ratio)
                let splitDuration = splitElapsed - splitStartElapsed

                splits.append(
                    RunSplit(
                        index: splits.count + 1,
                        distanceMeters: 1_000,
                        duration: splitDuration,
                        averageHeartRate: averageHeartRate(
                            from: heartRates,
                            elapsedRange: splitStartElapsed..<splitElapsed
                        ),
                        averageCadence: averageCadence(
                            from: stepSamples,
                            activeIntervals: activeIntervals,
                            elapsedRange: splitStartElapsed..<splitElapsed
                        )
                    )
                )

                splitStartElapsed = splitElapsed
                nextSplitDistance += 1_000
            }
        }

        let remainderDistance = totalDistance - Double(splits.count) * 1_000
        if remainderDistance > 0.5 {
            splits.append(
                RunSplit(
                    index: splits.count + 1,
                    distanceMeters: remainderDistance,
                    duration: max(totalDuration - splitStartElapsed, 0),
                    averageHeartRate: averageHeartRate(
                        from: heartRates,
                        elapsedRange: splitStartElapsed..<totalDuration + 0.5
                    ),
                    averageCadence: averageCadence(
                        from: stepSamples,
                        activeIntervals: activeIntervals,
                        elapsedRange: splitStartElapsed..<totalDuration + 0.5
                    )
                )
            )
        }

        return splits
    }

    // 지도 경로의 누적 거리는 CoreLocation 거리 계산을 그대로 사용한다.
    private func distance(from start: RunRoutePoint, to end: RunRoutePoint) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLocation.distance(from: endLocation)
    }

    // 원시 route 포인트에 누적 거리와 고도를 붙여 앱 공용 모델로 정규화한다.
    private func buildRoutePoints(from rawPoints: [RawRoutePoint]) -> [RunRoutePoint] {
        guard let first = rawPoints.first else { return [] }

        var cumulativeDistance: Double = 0
        var builtPoints: [RunRoutePoint] = [
            RunRoutePoint(
                latitude: first.latitude,
                longitude: first.longitude,
                timestamp: first.timestamp,
                distanceMeters: 0,
                altitudeMeters: first.altitudeMeters
            )
        ]

        for index in 1..<rawPoints.count {
            let previous = rawPoints[index - 1]
            let current = rawPoints[index]
            cumulativeDistance += distance(
                from: RunRoutePoint(
                    latitude: previous.latitude,
                    longitude: previous.longitude,
                    timestamp: previous.timestamp,
                    distanceMeters: cumulativeDistance,
                    altitudeMeters: previous.altitudeMeters
                ),
                to: RunRoutePoint(
                    latitude: current.latitude,
                    longitude: current.longitude,
                    timestamp: current.timestamp,
                    distanceMeters: cumulativeDistance,
                    altitudeMeters: current.altitudeMeters
                )
            )

            builtPoints.append(
                RunRoutePoint(
                    latitude: current.latitude,
                    longitude: current.longitude,
                    timestamp: current.timestamp,
                    distanceMeters: cumulativeDistance,
                    altitudeMeters: current.altitudeMeters
                )
            )
        }

        return builtPoints
    }

    // 거리 타임라인은 거리 샘플 우선, 없으면 route 기반 근사값으로 대체한다.
    private func buildDistanceTimeline(
        from distanceSamples: [RawDistanceSample],
        route: [RunRoutePoint],
        activeIntervals: [ActiveInterval],
        targetDistance: Double,
        totalDuration: TimeInterval
    ) -> [DistanceTimelinePoint] {
        let timelineFromSamples = buildDistanceTimeline(from: distanceSamples, activeIntervals: activeIntervals)

        if timelineFromSamples.count > 1 {
            return finalizedDistanceTimeline(
                timelineFromSamples,
                activeIntervals: activeIntervals,
                targetDistance: targetDistance,
                totalDuration: totalDuration
            )
        }

        let routeTimeline = buildDistanceTimeline(from: route, activeIntervals: activeIntervals)
        return finalizedDistanceTimeline(
            routeTimeline,
            activeIntervals: activeIntervals,
            targetDistance: targetDistance,
            totalDuration: totalDuration
        )
    }

    // HealthKit 거리 샘플이 있을 때 가장 정확한 거리 타임라인을 만든다.
    private func buildDistanceTimeline(
        from samples: [RawDistanceSample],
        activeIntervals: [ActiveInterval]
    ) -> [DistanceTimelinePoint] {
        guard !samples.isEmpty else { return [] }

        var cumulativeDistance: Double = 0
        var timeline: [DistanceTimelinePoint] = []

        if let firstStartDate = activeIntervals.first?.startDate {
            timeline.append(
                DistanceTimelinePoint(
                    date: firstStartDate,
                    elapsed: 0,
                    distanceMeters: 0,
                    segmentIndex: activeIntervals.first?.index ?? 0
                )
            )
        }

        for sample in samples {
            let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
            let sampleDuration = sampleInterval.duration
            guard sampleDuration > 0 else { continue }

            let overlaps = activeIntervals.compactMap { interval -> (ActiveInterval, DateInterval)? in
                guard let overlap = overlapInterval(between: sampleInterval, and: interval.dateInterval) else { return nil }
                return (interval, overlap)
            }

            for (interval, overlap) in overlaps where overlap.duration > 0 {
                let overlapRatio = overlap.duration / sampleDuration
                cumulativeDistance += sample.distanceMeters * overlapRatio
                timeline.append(
                    DistanceTimelinePoint(
                        date: overlap.end,
                        elapsed: activeElapsed(at: overlap.end, activeIntervals: activeIntervals),
                        distanceMeters: cumulativeDistance,
                        segmentIndex: interval.index
                    )
                )
            }
        }

        return monotonicDistanceTimeline(timeline)
    }

    // 거리 샘플이 없을 때는 route 좌표를 시간순으로 사용해 근사 타임라인을 만든다.
    private func buildDistanceTimeline(
        from route: [RunRoutePoint],
        activeIntervals: [ActiveInterval]
    ) -> [DistanceTimelinePoint] {
        guard !route.isEmpty else { return [] }

        let filteredPoints = route.compactMap { point -> DistanceTimelinePoint? in
            guard let interval = activeInterval(containing: point.timestamp, activeIntervals: activeIntervals) else { return nil }
            return DistanceTimelinePoint(
                date: point.timestamp,
                elapsed: activeElapsed(at: point.timestamp, activeIntervals: activeIntervals),
                distanceMeters: point.distanceMeters,
                segmentIndex: interval.index
            )
        }

        return monotonicDistanceTimeline(filteredPoints)
    }

    // 마지막 포인트를 workout 요약 거리/시간과 맞춰 화면 표기값을 일관되게 만든다.
    private func finalizedDistanceTimeline(
        _ timeline: [DistanceTimelinePoint],
        activeIntervals: [ActiveInterval],
        targetDistance: Double,
        totalDuration: TimeInterval
    ) -> [DistanceTimelinePoint] {
        guard !timeline.isEmpty else { return [] }

        let recordedDistance = timeline.last?.distanceMeters ?? 0
        let distanceScale = targetDistance > 0 && recordedDistance > 0 ? targetDistance / recordedDistance : 1
        let normalized = timeline.map {
            DistanceTimelinePoint(
                date: $0.date,
                elapsed: $0.elapsed,
                distanceMeters: $0.distanceMeters * distanceScale,
                segmentIndex: $0.segmentIndex
            )
        }

        let endDate = activeIntervals.last?.endDate ?? normalized.last?.date ?? .now
        let endPoint = DistanceTimelinePoint(
            date: endDate,
            elapsed: totalDuration,
            distanceMeters: targetDistance,
            segmentIndex: activeIntervals.last?.index ?? normalized.last?.segmentIndex ?? 0
        )

        if let last = normalized.last,
           abs(last.elapsed - totalDuration) <= 0.5,
           abs(last.distanceMeters - targetDistance) <= 0.5 {
            return monotonicDistanceTimeline(Array(normalized.dropLast()) + [endPoint])
        }

        return monotonicDistanceTimeline(normalized + [endPoint])
    }

    // 일부 샘플 오차로 거리가 뒤로 가지 않도록 단조 증가 형태로 보정한다.
    private func monotonicDistanceTimeline(_ timeline: [DistanceTimelinePoint]) -> [DistanceTimelinePoint] {
        guard !timeline.isEmpty else { return [] }

        let sorted = timeline.sorted { lhs, rhs in
            if lhs.elapsed == rhs.elapsed {
                return lhs.distanceMeters < rhs.distanceMeters
            }
            return lhs.elapsed < rhs.elapsed
        }

        var result: [DistanceTimelinePoint] = []
        for point in sorted {
            guard point.elapsed.isFinite, point.distanceMeters.isFinite else { continue }

            if let last = result.last {
                let elapsed = max(point.elapsed, last.elapsed)
                let distance = max(point.distanceMeters, last.distanceMeters)

                if abs(elapsed - last.elapsed) <= 0.01 {
                    result[result.count - 1] = DistanceTimelinePoint(
                        date: point.date,
                        elapsed: elapsed,
                        distanceMeters: distance,
                        segmentIndex: point.segmentIndex
                    )
                } else {
                    result.append(
                        DistanceTimelinePoint(
                            date: point.date,
                            elapsed: elapsed,
                            distanceMeters: distance,
                            segmentIndex: point.segmentIndex
                        )
                    )
                }
            } else {
                result.append(
                    DistanceTimelinePoint(
                        date: point.date,
                        elapsed: max(point.elapsed, 0),
                        distanceMeters: max(point.distanceMeters, 0),
                        segmentIndex: point.segmentIndex
                    )
                )
            }
        }

        return result
    }

    // pause/auto-pause가 있는 운동도 정확히 계산하기 위해 활성 구간을 분리한다.
    private func buildActiveIntervals(for workout: HKWorkout) -> [ActiveInterval] {
        let events = (workout.workoutEvents ?? []).sorted { $0.dateInterval.start < $1.dateInterval.start }
        var intervals: [(Date, Date)] = []
        var cursor = workout.startDate
        var isPaused = false

        for event in events {
            let eventDate = min(max(event.dateInterval.start, workout.startDate), workout.endDate)

            switch event.type {
            case .pause, .motionPaused:
                guard !isPaused else { continue }
                if eventDate > cursor {
                    intervals.append((cursor, eventDate))
                }
                isPaused = true
            case .resume, .motionResumed:
                guard isPaused else { continue }
                cursor = eventDate
                isPaused = false
            default:
                continue
            }
        }

        if !isPaused, workout.endDate > cursor {
            intervals.append((cursor, workout.endDate))
        }

        if intervals.isEmpty, workout.endDate > workout.startDate {
            return [ActiveInterval(index: 0, startDate: workout.startDate, endDate: workout.endDate)]
        }

        return intervals.enumerated().map { index, interval in
            ActiveInterval(index: index, startDate: interval.0, endDate: interval.1)
        }
    }

    // 특정 시점이 실제 러닝한 누적 시간에서 어디쯤인지 계산한다.
    private func activeElapsed(at date: Date, activeIntervals: [ActiveInterval]) -> TimeInterval {
        var elapsed: TimeInterval = 0

        for interval in activeIntervals {
            if date >= interval.endDate {
                elapsed += interval.endDate.timeIntervalSince(interval.startDate)
            } else if date > interval.startDate {
                elapsed += date.timeIntervalSince(interval.startDate)
                break
            } else {
                break
            }
        }

        return elapsed
    }

    private func overlapInterval(between lhs: DateInterval, and rhs: DateInterval) -> DateInterval? {
        let startDate = max(lhs.start, rhs.start)
        let endDate = min(lhs.end, rhs.end)
        guard endDate > startDate else { return nil }
        return DateInterval(start: startDate, end: endDate)
    }

    private func activeInterval(containing date: Date, activeIntervals: [ActiveInterval]) -> ActiveInterval? {
        activeIntervals.first { interval in
            interval.dateInterval.contains(date) || date == interval.endDate
        }
    }

    // 심박 샘플을 가장 가까운 거리 포인트에 붙여 거리 기반 차트에서 재사용한다.
    private func mapHeartRatesToDistanceTimeline(
        _ heartRates: [HeartRateSample],
        timeline: [DistanceTimelinePoint],
        activeIntervals: [ActiveInterval]
    ) -> [HeartRateSample] {
        guard !timeline.isEmpty else { return heartRates }

        return heartRates.compactMap { sample in
            guard let interval = activeInterval(containing: sample.date, activeIntervals: activeIntervals) else { return nil }
            let distancePoint = nearestTimelinePoint(
                to: sample.date,
                segmentIndex: interval.index,
                timeline: timeline
            )

            return HeartRateSample(
                date: sample.date,
                bpm: sample.bpm,
                elapsed: activeElapsed(at: sample.date, activeIntervals: activeIntervals),
                distanceMeters: distancePoint?.distanceMeters,
                segmentIndex: interval.index
            )
        }
    }

    // 추가 러닝 메트릭도 모두 같은 거리 타임라인 기준으로 맞춘다.
    private func buildRunningMetrics(
        stepSamples: [RawStepSample],
        powerSamples: [RawQuantitySample],
        speedSamples: [RawQuantitySample],
        strideLengthSamples: [RawQuantitySample],
        verticalOscillationSamples: [RawQuantitySample],
        groundContactTimeSamples: [RawQuantitySample],
        timeline: [DistanceTimelinePoint],
        activeIntervals: [ActiveInterval]
    ) -> RunningMetrics {
        RunningMetrics(
            cadence: buildCadenceSamples(
                from: stepSamples,
                timeline: timeline,
                activeIntervals: activeIntervals
            ),
            power: mapRunningMetricSamples(
                powerSamples,
                timeline: timeline,
                activeIntervals: activeIntervals
            ),
            speed: mapRunningMetricSamples(
                speedSamples,
                timeline: timeline,
                activeIntervals: activeIntervals
            ),
            strideLength: mapRunningMetricSamples(
                strideLengthSamples,
                timeline: timeline,
                activeIntervals: activeIntervals
            ),
            verticalOscillation: mapRunningMetricSamples(
                verticalOscillationSamples,
                timeline: timeline,
                activeIntervals: activeIntervals
            ),
            groundContactTime: mapRunningMetricSamples(
                groundContactTimeSamples,
                timeline: timeline,
                activeIntervals: activeIntervals
            )
        )
    }

    private func buildCadenceSamples(
        from stepSamples: [RawStepSample],
        timeline: [DistanceTimelinePoint],
        activeIntervals: [ActiveInterval]
    ) -> [RunningMetricSample] {
        guard !timeline.isEmpty else { return [] }

        var samples: [RunningMetricSample] = []

        for stepSample in stepSamples {
            let stepInterval = DateInterval(start: stepSample.startDate, end: stepSample.endDate)
            let sampleDuration = stepInterval.duration
            guard sampleDuration > 0 else { continue }

            let overlaps = activeIntervals.compactMap { interval -> (ActiveInterval, DateInterval)? in
                guard let overlap = overlapInterval(between: stepInterval, and: interval.dateInterval) else { return nil }
                return (interval, overlap)
            }

            for (interval, overlap) in overlaps where overlap.duration > 0 {
                let cadence = (stepSample.count * (overlap.duration / sampleDuration)) / (overlap.duration / 60)
                guard cadence.isFinite, cadence > 0 else { continue }
                let distancePoint = nearestTimelinePoint(
                    to: overlap.end,
                    segmentIndex: interval.index,
                    timeline: timeline
                )

                samples.append(
                    RunningMetricSample(
                        date: overlap.end,
                        value: cadence,
                        elapsed: activeElapsed(at: overlap.end, activeIntervals: activeIntervals),
                        distanceMeters: distancePoint?.distanceMeters,
                        segmentIndex: interval.index
                    )
                )
            }
        }

        return normalizedRunningMetricSamples(samples)
    }

    private func mapRunningMetricSamples(
        _ samples: [RawQuantitySample],
        timeline: [DistanceTimelinePoint],
        activeIntervals: [ActiveInterval]
    ) -> [RunningMetricSample] {
        guard !timeline.isEmpty else { return [] }

        var mappedSamples: [RunningMetricSample] = []

        for sample in samples {
            let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
            let overlaps = activeIntervals.compactMap { interval -> (ActiveInterval, DateInterval)? in
                guard let overlap = overlapInterval(between: sampleInterval, and: interval.dateInterval) else { return nil }
                return (interval, overlap)
            }

            for (interval, overlap) in overlaps where overlap.duration > 0 {
                let distancePoint = nearestTimelinePoint(
                    to: overlap.end,
                    segmentIndex: interval.index,
                    timeline: timeline
                )

                mappedSamples.append(
                    RunningMetricSample(
                        date: overlap.end,
                        value: sample.value,
                        elapsed: activeElapsed(at: overlap.end, activeIntervals: activeIntervals),
                        distanceMeters: distancePoint?.distanceMeters,
                        segmentIndex: interval.index
                    )
                )
            }
        }

        return normalizedRunningMetricSamples(mappedSamples)
    }

    private func normalizedRunningMetricSamples(_ samples: [RunningMetricSample]) -> [RunningMetricSample] {
        samples.sorted { lhs, rhs in
            if lhs.elapsed == rhs.elapsed {
                return lhs.date < rhs.date
            }
            return (lhs.elapsed ?? .greatestFiniteMagnitude) < (rhs.elapsed ?? .greatestFiniteMagnitude)
        }
    }

    private func nearestTimelinePoint(
        to date: Date,
        segmentIndex: Int,
        timeline: [DistanceTimelinePoint]
    ) -> DistanceTimelinePoint? {
        timeline
            .filter { $0.segmentIndex == segmentIndex }
            .min(by: {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            })
    }

    private func averageHeartRate(from heartRates: [HeartRateSample], elapsedRange: Range<TimeInterval>) -> Double? {
        let values = heartRates.compactMap { sample -> Double? in
            guard let elapsed = sample.elapsed, elapsedRange.contains(elapsed) else { return nil }
            return sample.bpm
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func averageCadence(
        from stepSamples: [RawStepSample],
        activeIntervals: [ActiveInterval],
        elapsedRange: Range<TimeInterval>
    ) -> Double? {
        let dateIntervals = dateIntervals(for: elapsedRange, activeIntervals: activeIntervals)
        guard !dateIntervals.isEmpty else { return nil }

        var overlappedStepCount: Double = 0
        var overlappedDuration: TimeInterval = 0

        for stepSample in stepSamples {
            let stepInterval = DateInterval(start: stepSample.startDate, end: stepSample.endDate)
            let sampleDuration = stepInterval.duration
            guard sampleDuration > 0 else { continue }

            for dateInterval in dateIntervals {
                guard let overlap = overlapInterval(between: stepInterval, and: dateInterval) else { continue }
                let overlapRatio = overlap.duration / sampleDuration
                overlappedStepCount += stepSample.count * overlapRatio
                overlappedDuration += overlap.duration
            }
        }

        guard overlappedStepCount > 0, overlappedDuration > 0 else { return nil }
        return overlappedStepCount / (overlappedDuration / 60)
    }

    private func dateIntervals(
        for elapsedRange: Range<TimeInterval>,
        activeIntervals: [ActiveInterval]
    ) -> [DateInterval] {
        guard elapsedRange.upperBound > elapsedRange.lowerBound else { return [] }

        var intervals: [DateInterval] = []
        var accumulatedElapsed: TimeInterval = 0

        for activeInterval in activeIntervals {
            let duration = activeInterval.endDate.timeIntervalSince(activeInterval.startDate)
            let intervalElapsedRange = accumulatedElapsed..<(accumulatedElapsed + duration)

            if let overlap = overlapRange(between: elapsedRange, and: intervalElapsedRange) {
                intervals.append(
                    DateInterval(
                        start: activeInterval.startDate.addingTimeInterval(overlap.lowerBound - accumulatedElapsed),
                        end: activeInterval.startDate.addingTimeInterval(overlap.upperBound - accumulatedElapsed)
                    )
                )
            }

            accumulatedElapsed += duration
            if accumulatedElapsed >= elapsedRange.upperBound {
                break
            }
        }

        return intervals
    }

    private func overlapRange(
        between lhs: Range<TimeInterval>,
        and rhs: Range<TimeInterval>
    ) -> Range<TimeInterval>? {
        let lowerBound = max(lhs.lowerBound, rhs.lowerBound)
        let upperBound = min(lhs.upperBound, rhs.upperBound)
        guard upperBound > lowerBound else { return nil }
        return lowerBound..<upperBound
    }
}

// Route query 원본 좌표를 잠시 담아두는 중간 구조다.
private struct RawRoutePoint {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let altitudeMeters: Double?
}

// 거리 샘플 원본은 시작/종료 시점과 누적 거리 계산용 값만 가진다.
private struct RawDistanceSample {
    let startDate: Date
    let endDate: Date
    let distanceMeters: Double
}

// 걸음 수 원본 샘플은 cadence 계산 전용 보조 구조다.
private struct RawStepSample {
    let startDate: Date
    let endDate: Date
    let count: Double
}

// 추가 러닝 메트릭 원본은 공통 숫자 구조로 통일한다.
private struct RawQuantitySample {
    let startDate: Date
    let endDate: Date
    let value: Double
}

// pause/resume를 반영한 실제 활동 구간 하나를 뜻한다.
private struct ActiveInterval {
    let index: Int
    let startDate: Date
    let endDate: Date

    var dateInterval: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }
}
