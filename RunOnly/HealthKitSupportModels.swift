import Foundation
import HealthKit
import CoreLocation

// Route query 원본 좌표를 잠시 담아두는 중간 구조다.
struct RawRoutePoint {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let altitudeMeters: Double?
}

// 거리 샘플 원본은 시작/종료 시점과 누적 거리 계산용 값만 가진다.
struct RawDistanceSample {
    let startDate: Date
    let endDate: Date
    let distanceMeters: Double
}

// 걸음 수 원본 샘플은 cadence 계산 전용 보조 구조다.
struct RawStepSample {
    let startDate: Date
    let endDate: Date
    let count: Double
}

// 추가 러닝 메트릭 원본은 공통 숫자 구조로 통일한다.
struct RawQuantitySample {
    let startDate: Date
    let endDate: Date
    let value: Double
}

// pause/resume를 반영한 실제 활동 구간 하나를 뜻한다.
struct ActiveInterval {
    let index: Int
    let startDate: Date
    let endDate: Date

    var dateInterval: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }
}

struct TimelineLookup {
    let pointsBySegment: [Int: [DistanceTimelinePoint]]

    init(timeline: [DistanceTimelinePoint]) {
        pointsBySegment = Dictionary(grouping: timeline, by: \.segmentIndex)
            .mapValues { points in
                points.sorted { $0.date < $1.date }
            }
    }

    var isEmpty: Bool {
        pointsBySegment.isEmpty
    }
}
