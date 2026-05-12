import Foundation
import HealthKit
import CoreLocation

extension HealthKitService {
    func fetchHeartRateZoneProfile(
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
    func fetchLatestRestingHeartRate(before referenceDate: Date) async throws -> Double? {
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
    func fetchRecentMaximumHeartRate(before referenceDate: Date) async throws -> Double? {
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

    func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }

    // 여러 workout route를 하나의 경로 배열로 모아 지도에 바로 쓸 수 있게 만든다.
    func fetchRoute(for workout: HKWorkout) async throws -> [RunRoutePoint] {
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
    func fetchLocations(for route: HKWorkoutRoute) async throws -> [RawRoutePoint] {
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
    func fetchHeartRates(for workout: HKWorkout) async throws -> [HeartRateSample] {
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
    func fetchDistanceSamples(for workout: HKWorkout) async throws -> [RawDistanceSample] {
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
    func fetchStepCountSamples(for workout: HKWorkout) async throws -> [RawStepSample] {
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
    func fetchQuantitySamples(
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
}
