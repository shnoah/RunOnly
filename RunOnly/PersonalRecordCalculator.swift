import Foundation

enum PersonalRecordCalculator {
    static func bestDuration(for targetDistance: Double, in timeline: [DistanceTimelinePoint]) -> TimeInterval? {
        guard timeline.count > 1, let lastDistance = timeline.last?.distanceMeters, lastDistance >= targetDistance else {
            return nil
        }

        var best: TimeInterval?
        var lowerIndex = 0

        for endIndex in timeline.indices {
            let endPoint = timeline[endIndex]
            guard endPoint.distanceMeters >= targetDistance else { continue }

            let startDistance = endPoint.distanceMeters - targetDistance
            while lowerIndex + 1 < timeline.count, timeline[lowerIndex + 1].distanceMeters < startDistance {
                lowerIndex += 1
            }

            let startElapsed = interpolatedElapsed(for: startDistance, in: timeline, lowerIndex: lowerIndex)
            let duration = endPoint.elapsed - startElapsed
            guard duration > 0 else { continue }

            if best == nil || duration < (best ?? .greatestFiniteMagnitude) {
                best = duration
            }
        }

        return best
    }

    private static func interpolatedElapsed(
        for distance: Double,
        in timeline: [DistanceTimelinePoint],
        lowerIndex: Int
    ) -> TimeInterval {
        let clampedIndex = min(max(lowerIndex, 0), timeline.count - 1)
        let lowerPoint = timeline[clampedIndex]
        guard clampedIndex + 1 < timeline.count else { return lowerPoint.elapsed }

        let upperPoint = timeline[clampedIndex + 1]
        let distanceSpan = upperPoint.distanceMeters - lowerPoint.distanceMeters
        guard distanceSpan > 0 else { return upperPoint.elapsed }

        let ratio = (distance - lowerPoint.distanceMeters) / distanceSpan
        let clampedRatio = min(max(ratio, 0), 1)
        return lowerPoint.elapsed + (upperPoint.elapsed - lowerPoint.elapsed) * clampedRatio
    }
}
