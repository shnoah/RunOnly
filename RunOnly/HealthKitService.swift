import Foundation
import HealthKit
import CoreLocation

enum HealthKitServiceError: Equatable, LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "이 기기에서는 HealthKit을 사용할 수 없습니다."
        }
    }
}

final class HealthKitService {
    private let healthStore = HKHealthStore()

    func requestReadAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.notAvailable
        }

        let workoutType = HKObjectType.workoutType()
        let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max)
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        let workoutRouteType = HKSeriesType.workoutRoute()

        var readTypes: Set<HKObjectType> = [workoutType, workoutRouteType]
        if let vo2MaxType {
            readTypes.insert(vo2MaxType)
        }
        if let heartRateType {
            readTypes.insert(heartRateType)
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

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

    func fetchRunDetail(for runningWorkout: RunningWorkout) async throws -> RunDetail {
        async let routeTask = fetchRoute(for: runningWorkout.workout)
        async let heartRateTask = fetchHeartRates(for: runningWorkout.workout)

        let route = try await routeTask
        let heartRates = mapHeartRatesToRoute(try await heartRateTask, route: route)

        return RunDetail(
            route: route,
            heartRates: heartRates,
            paceSamples: buildPaceSamples(from: route),
            splits: buildSplits(from: route)
        )
    }

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
                            timestamp: $0.timestamp
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
                        distanceMeters: nil
                    )
                }

                continuation.resume(returning: heartRates)
            }

            healthStore.execute(query)
        }
    }

    private func buildPaceSamples(from route: [RunRoutePoint]) -> [PaceSample] {
        guard route.count > 1 else { return [] }

        var samples: [PaceSample] = []
        var lastIncludedDate = route[0].timestamp.addingTimeInterval(-15)

        for index in 1..<route.count {
            let currentPoint = route[index]
            guard currentPoint.timestamp.timeIntervalSince(lastIncludedDate) >= 5 else { continue }

            var lookbackIndex = index - 1
            while lookbackIndex > 0,
                  currentPoint.timestamp.timeIntervalSince(route[lookbackIndex].timestamp) < 15 {
                lookbackIndex -= 1
            }

            let startPoint = route[lookbackIndex]

            let distanceWindow = currentPoint.distanceMeters - startPoint.distanceMeters
            let durationWindow = currentPoint.timestamp.timeIntervalSince(startPoint.timestamp)
            guard distanceWindow >= 20, durationWindow >= 10 else { continue }

            let secondsPerKilometer = durationWindow / (distanceWindow / 1_000)
            guard secondsPerKilometer.isFinite, (150...900).contains(secondsPerKilometer) else { continue }

            samples.append(
                PaceSample(
                    date: currentPoint.timestamp,
                    distanceMeters: currentPoint.distanceMeters,
                    secondsPerKilometer: secondsPerKilometer
                )
            )
            lastIncludedDate = currentPoint.timestamp
        }

        return samples
    }

    private func buildSplits(from route: [RunRoutePoint]) -> [RunSplit] {
        guard route.count > 1 else { return [] }

        var splits: [RunSplit] = []
        var accumulatedDistance: Double = 0
        var nextSplitDistance: Double = 1_000
        let runStartTime = route[0].timestamp
        var splitStartTime = runStartTime

        for index in 1..<route.count {
            let previous = route[index - 1]
            let current = route[index]
            let segmentDistance = distance(from: previous, to: current)
            let segmentDuration = current.timestamp.timeIntervalSince(previous.timestamp)
            guard segmentDistance > 0, segmentDuration > 0 else { continue }

            let segmentStartDistance = accumulatedDistance
            accumulatedDistance += segmentDistance

            while accumulatedDistance >= nextSplitDistance {
                let distanceIntoSegment = nextSplitDistance - segmentStartDistance
                let ratio = distanceIntoSegment / segmentDistance
                let splitTime = previous.timestamp.addingTimeInterval(segmentDuration * ratio)
                let splitDuration = splitTime.timeIntervalSince(splitStartTime)

                splits.append(
                    RunSplit(
                        index: splits.count + 1,
                        distanceMeters: 1_000,
                        duration: splitDuration
                    )
                )

                splitStartTime = splitTime
                nextSplitDistance += 1_000
            }
        }

        let remainderDistance = accumulatedDistance - Double(splits.count) * 1_000
        if remainderDistance >= 100, let lastPoint = route.last {
            splits.append(
                RunSplit(
                    index: splits.count + 1,
                    distanceMeters: remainderDistance,
                    duration: lastPoint.timestamp.timeIntervalSince(splitStartTime)
                )
            )
        }

        return splits
    }

    private func distance(from start: RunRoutePoint, to end: RunRoutePoint) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLocation.distance(from: endLocation)
    }

    private func buildRoutePoints(from rawPoints: [RawRoutePoint]) -> [RunRoutePoint] {
        guard let first = rawPoints.first else { return [] }

        var cumulativeDistance: Double = 0
        var builtPoints: [RunRoutePoint] = [
            RunRoutePoint(
                latitude: first.latitude,
                longitude: first.longitude,
                timestamp: first.timestamp,
                distanceMeters: 0
            )
        ]

        for index in 1..<rawPoints.count {
            let previous = rawPoints[index - 1]
            let current = rawPoints[index]
            cumulativeDistance += distance(
                from: RunRoutePoint(latitude: previous.latitude, longitude: previous.longitude, timestamp: previous.timestamp, distanceMeters: cumulativeDistance),
                to: RunRoutePoint(latitude: current.latitude, longitude: current.longitude, timestamp: current.timestamp, distanceMeters: cumulativeDistance)
            )

            builtPoints.append(
                RunRoutePoint(
                    latitude: current.latitude,
                    longitude: current.longitude,
                    timestamp: current.timestamp,
                    distanceMeters: cumulativeDistance
                )
            )
        }

        return builtPoints
    }

    private func mapHeartRatesToRoute(_ heartRates: [HeartRateSample], route: [RunRoutePoint]) -> [HeartRateSample] {
        guard !route.isEmpty else { return heartRates }

        return heartRates.map { sample in
            let distanceMeters = route.min(by: {
                abs($0.timestamp.timeIntervalSince(sample.date)) < abs($1.timestamp.timeIntervalSince(sample.date))
            })?.distanceMeters

            return HeartRateSample(date: sample.date, bpm: sample.bpm, distanceMeters: distanceMeters)
        }
    }
}

private struct RawRoutePoint {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}
