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
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        let workoutRouteType = HKSeriesType.workoutRoute()

        var readTypes: Set<HKObjectType> = [workoutType, workoutRouteType]
        if let vo2MaxType {
            readTypes.insert(vo2MaxType)
        }
        if let heartRateType {
            readTypes.insert(heartRateType)
        }
        if let distanceType {
            readTypes.insert(distanceType)
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
        async let distanceTask = fetchDistanceSamples(for: runningWorkout.workout)

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

        return RunDetail(
            route: route,
            distanceTimeline: distanceTimeline,
            heartRates: heartRates,
            paceSamples: buildPaceSamples(from: distanceTimeline),
            splits: buildSplits(
                from: distanceTimeline,
                heartRates: heartRates,
                totalDistance: runningWorkout.distanceInMeters,
                totalDuration: runningWorkout.duration
            )
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
                        distanceMeters: nil,
                        segmentIndex: nil
                    )
                }

                continuation.resume(returning: heartRates)
            }

            healthStore.execute(query)
        }
    }

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

    private func buildSplits(
        from timeline: [DistanceTimelinePoint],
        heartRates: [HeartRateSample],
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
                            range: segmentStartDistance..<nextSplitDistance
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
                        range: Double(splits.count) * 1_000..<totalDistance + 0.5
                    )
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

    private func mapHeartRatesToDistanceTimeline(
        _ heartRates: [HeartRateSample],
        timeline: [DistanceTimelinePoint],
        activeIntervals: [ActiveInterval]
    ) -> [HeartRateSample] {
        guard !timeline.isEmpty else { return heartRates }

        return heartRates.compactMap { sample in
            guard let interval = activeInterval(containing: sample.date, activeIntervals: activeIntervals) else { return nil }
            let distancePoint = timeline
                .filter { $0.segmentIndex == interval.index }
                .min(by: {
                    abs($0.date.timeIntervalSince(sample.date)) < abs($1.date.timeIntervalSince(sample.date))
                })

            return HeartRateSample(
                date: sample.date,
                bpm: sample.bpm,
                distanceMeters: distancePoint?.distanceMeters,
                segmentIndex: interval.index
            )
        }
    }

    private func averageHeartRate(from heartRates: [HeartRateSample], range: Range<Double>) -> Double? {
        let values = heartRates.compactMap { sample -> Double? in
            guard let distanceMeters = sample.distanceMeters, range.contains(distanceMeters) else { return nil }
            return sample.bpm
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

private struct RawRoutePoint {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

private struct RawDistanceSample {
    let startDate: Date
    let endDate: Date
    let distanceMeters: Double
}

private struct ActiveInterval {
    let index: Int
    let startDate: Date
    let endDate: Date

    var dateInterval: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }
}
