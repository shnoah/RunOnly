import Foundation
import HealthKit
import CoreLocation

extension HealthKitService {
    func buildPaceSamples(from timeline: [DistanceTimelinePoint]) -> [PaceSample] {
        guard timeline.count > 1 else { return [] }

        var samples: [PaceSample] = []
        let paceWindowSeconds: TimeInterval = 25
        let sampleIntervalSeconds: TimeInterval = 4
        var lastIncludedElapsed = timeline[0].elapsed - sampleIntervalSeconds

        for index in 1..<timeline.count {
            let currentPoint = timeline[index]
            guard currentPoint.elapsed - lastIncludedElapsed >= sampleIntervalSeconds else { continue }

            let segmentStartIndex = timeline[..<index].lastIndex(where: {
                $0.segmentIndex != currentPoint.segmentIndex
            }).map { $0 + 1 } ?? 0

            var lookbackIndex = index - 1
            while lookbackIndex > segmentStartIndex,
                  currentPoint.elapsed - timeline[lookbackIndex].elapsed < paceWindowSeconds {
                lookbackIndex -= 1
            }

            let startPoint = timeline[lookbackIndex]

            let distanceWindow = currentPoint.distanceMeters - startPoint.distanceMeters
            let durationWindow = currentPoint.elapsed - startPoint.elapsed
            guard distanceWindow >= 20, durationWindow >= 10 else { continue }

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
    func buildSplits(
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
    func distance(from start: RunRoutePoint, to end: RunRoutePoint) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLocation.distance(from: endLocation)
    }

    // 원시 route 포인트에 누적 거리와 고도를 붙여 앱 공용 모델로 정규화한다.
    func buildRoutePoints(from rawPoints: [RawRoutePoint]) -> [RunRoutePoint] {
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
    func buildDistanceTimeline(
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
    func buildDistanceTimeline(
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
    func buildDistanceTimeline(
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
    func finalizedDistanceTimeline(
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
    func monotonicDistanceTimeline(_ timeline: [DistanceTimelinePoint]) -> [DistanceTimelinePoint] {
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
    func buildActiveIntervals(for workout: HKWorkout) -> [ActiveInterval] {
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
    func activeElapsed(at date: Date, activeIntervals: [ActiveInterval]) -> TimeInterval {
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

    func overlapInterval(between lhs: DateInterval, and rhs: DateInterval) -> DateInterval? {
        let startDate = max(lhs.start, rhs.start)
        let endDate = min(lhs.end, rhs.end)
        guard endDate > startDate else { return nil }
        return DateInterval(start: startDate, end: endDate)
    }

    func activeInterval(containing date: Date, activeIntervals: [ActiveInterval]) -> ActiveInterval? {
        activeIntervals.first { interval in
            interval.dateInterval.contains(date) || date == interval.endDate
        }
    }

    // 심박 샘플을 가장 가까운 거리 포인트에 붙여 거리 기반 차트에서 재사용한다.
    func mapHeartRatesToDistanceTimeline(
        _ heartRates: [HeartRateSample],
        timeline: [DistanceTimelinePoint],
        activeIntervals: [ActiveInterval]
    ) -> [HeartRateSample] {
        guard !timeline.isEmpty else { return heartRates }
        let timelineLookup = TimelineLookup(timeline: timeline)

        return heartRates.compactMap { sample in
            guard let interval = activeInterval(containing: sample.date, activeIntervals: activeIntervals) else { return nil }
            let distancePoint = nearestTimelinePoint(
                to: sample.date,
                segmentIndex: interval.index,
                lookup: timelineLookup
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
    func buildRunningMetrics(
        stepSamples: [RawStepSample],
        powerSamples: [RawQuantitySample],
        speedSamples: [RawQuantitySample],
        strideLengthSamples: [RawQuantitySample],
        verticalOscillationSamples: [RawQuantitySample],
        groundContactTimeSamples: [RawQuantitySample],
        timeline: [DistanceTimelinePoint],
        activeIntervals: [ActiveInterval]
    ) -> RunningMetrics {
        let timelineLookup = TimelineLookup(timeline: timeline)

        return RunningMetrics(
            cadence: buildCadenceSamples(
                from: stepSamples,
                timelineLookup: timelineLookup,
                activeIntervals: activeIntervals
            ),
            power: mapRunningMetricSamples(
                powerSamples,
                timelineLookup: timelineLookup,
                activeIntervals: activeIntervals
            ),
            speed: mapRunningMetricSamples(
                speedSamples,
                timelineLookup: timelineLookup,
                activeIntervals: activeIntervals
            ),
            strideLength: mapRunningMetricSamples(
                strideLengthSamples,
                timelineLookup: timelineLookup,
                activeIntervals: activeIntervals
            ),
            verticalOscillation: mapRunningMetricSamples(
                verticalOscillationSamples,
                timelineLookup: timelineLookup,
                activeIntervals: activeIntervals
            ),
            groundContactTime: mapRunningMetricSamples(
                groundContactTimeSamples,
                timelineLookup: timelineLookup,
                activeIntervals: activeIntervals
            )
        )
    }

    func buildCadenceSamples(
        from stepSamples: [RawStepSample],
        timelineLookup: TimelineLookup,
        activeIntervals: [ActiveInterval]
    ) -> [RunningMetricSample] {
        guard !timelineLookup.isEmpty else { return [] }

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
                    lookup: timelineLookup
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

    func mapRunningMetricSamples(
        _ samples: [RawQuantitySample],
        timelineLookup: TimelineLookup,
        activeIntervals: [ActiveInterval]
    ) -> [RunningMetricSample] {
        guard !timelineLookup.isEmpty else { return [] }

        var mappedSamples: [RunningMetricSample] = []

        for sample in samples {
            if sample.endDate <= sample.startDate {
                guard let interval = activeInterval(containing: sample.startDate, activeIntervals: activeIntervals) else {
                    continue
                }
                let distancePoint = nearestTimelinePoint(
                    to: sample.startDate,
                    segmentIndex: interval.index,
                    lookup: timelineLookup
                )

                mappedSamples.append(
                    RunningMetricSample(
                        date: sample.startDate,
                        value: sample.value,
                        elapsed: activeElapsed(at: sample.startDate, activeIntervals: activeIntervals),
                        distanceMeters: distancePoint?.distanceMeters,
                        segmentIndex: interval.index
                    )
                )
                continue
            }

            let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
            let overlaps = activeIntervals.compactMap { interval -> (ActiveInterval, DateInterval)? in
                guard let overlap = overlapInterval(between: sampleInterval, and: interval.dateInterval) else { return nil }
                return (interval, overlap)
            }

            for (interval, overlap) in overlaps where overlap.duration > 0 {
                let distancePoint = nearestTimelinePoint(
                    to: overlap.end,
                    segmentIndex: interval.index,
                    lookup: timelineLookup
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

    func normalizedRunningMetricSamples(_ samples: [RunningMetricSample]) -> [RunningMetricSample] {
        samples.sorted { lhs, rhs in
            if lhs.elapsed == rhs.elapsed {
                return lhs.date < rhs.date
            }
            return (lhs.elapsed ?? .greatestFiniteMagnitude) < (rhs.elapsed ?? .greatestFiniteMagnitude)
        }
    }

    func nearestTimelinePoint(
        to date: Date,
        segmentIndex: Int,
        lookup: TimelineLookup
    ) -> DistanceTimelinePoint? {
        guard let points = lookup.pointsBySegment[segmentIndex], !points.isEmpty else { return nil }

        var lowerBound = 0
        var upperBound = points.count

        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2
            if points[middle].date < date {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        if lowerBound == 0 {
            return points[0]
        }

        if lowerBound == points.count {
            return points[points.count - 1]
        }

        let previousPoint = points[lowerBound - 1]
        let nextPoint = points[lowerBound]
        let previousDistance = abs(previousPoint.date.timeIntervalSince(date))
        let nextDistance = abs(nextPoint.date.timeIntervalSince(date))
        return previousDistance <= nextDistance ? previousPoint : nextPoint
    }

    func averageHeartRate(from heartRates: [HeartRateSample], elapsedRange: Range<TimeInterval>) -> Double? {
        let values = heartRates.compactMap { sample -> Double? in
            guard let elapsed = sample.elapsed, elapsedRange.contains(elapsed) else { return nil }
            return sample.bpm
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    func averageCadence(
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

    func dateIntervals(
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

    func overlapRange(
        between lhs: Range<TimeInterval>,
        and rhs: Range<TimeInterval>
    ) -> Range<TimeInterval>? {
        let lowerBound = max(lhs.lowerBound, rhs.lowerBound)
        let upperBound = min(lhs.upperBound, rhs.upperBound)
        guard upperBound > lowerBound else { return nil }
        return lowerBound..<upperBound
    }
}
