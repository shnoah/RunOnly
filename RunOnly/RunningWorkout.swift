import Foundation
import HealthKit

struct RunningWorkout: Identifiable {
    let id: UUID
    let workout: HKWorkout
    let startDate: Date
    let duration: TimeInterval
    let distanceInMeters: Double
    let sourceName: String
    let sourceBundleIdentifier: String

    init(workout: HKWorkout) {
        id = workout.uuid
        self.workout = workout
        startDate = workout.startDate
        duration = workout.duration
        distanceInMeters = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        sourceName = workout.sourceRevision.source.name
        sourceBundleIdentifier = workout.sourceRevision.source.bundleIdentifier
    }

    var distanceText: String {
        let distanceInKilometers = distanceInMeters / 1_000
        return distanceInKilometers.formatted(.number.precision(.fractionLength(2))) + " km"
    }

    var distanceInKilometers: Double {
        distanceInMeters / 1_000
    }

    var durationText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: duration) ?? "-"
    }

    var paceText: String {
        guard distanceInMeters > 0 else { return "-" }
        let secondsPerKilometer = duration / (distanceInMeters / 1_000)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return (formatter.string(from: secondsPerKilometer) ?? "-") + "/km"
    }

    var isAppleWorkout: Bool {
        sourceBundleIdentifier.lowercased().hasPrefix("com.apple.health")
    }

    var isIndoorWorkout: Bool? {
        guard let value = workout.metadata?[HKMetadataKeyIndoorWorkout] as? NSNumber else {
            return nil
        }
        return value.boolValue
    }

    var environmentText: String {
        switch isIndoorWorkout {
        case true:
            return "인도어"
        case false:
            return "아웃도어"
        case nil:
            return "구분 없음"
        }
    }

    var environmentShortText: String {
        switch isIndoorWorkout {
        case true:
            return "실내"
        case false:
            return "실외"
        case nil:
            return "미확인"
        }
    }

    var recordDateText: String {
        Self.recordDateFormatter.string(from: startDate)
    }

    var detailDateText: String {
        Self.detailDateFormatter.string(from: startDate)
    }

    var titleText: String {
        recordDateText
    }

    private static let recordDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E) a h:mm"
        return formatter
    }()

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E) a h:mm"
        return formatter
    }()
}

struct RunningSummary {
    let monthDistanceText: String
    let yearDistanceText: String
    let trainingStatus: String
    let trainingStatusDetail: String
    let vo2MaxText: String
    let vo2MaxDateText: String
    let predicted5KText: String
    let predicted10KText: String
    let predictedHalfText: String
    let predictedMarathonText: String

    static let empty = RunningSummary(
        monthDistanceText: "0 km",
        yearDistanceText: "0 km",
        trainingStatus: "준비중",
        trainingStatusDetail: "러닝 데이터가 쌓이면 상태를 계산합니다.",
        vo2MaxText: "-",
        vo2MaxDateText: "VO2 Max 데이터 없음",
        predicted5KText: "-",
        predicted10KText: "-",
        predictedHalfText: "-",
        predictedMarathonText: "-"
    )
}

struct VO2MaxSample {
    let value: Double
    let date: Date
}

struct HeartRateSample: Identifiable {
    let id = UUID()
    let date: Date
    let bpm: Double
    let elapsed: TimeInterval?
    let distanceMeters: Double?
    let segmentIndex: Int?
}

struct RunningMetricSample: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let elapsed: TimeInterval?
    let distanceMeters: Double?
    let segmentIndex: Int?
}

struct RunningMetrics {
    let cadence: [RunningMetricSample]
    let power: [RunningMetricSample]
    let speed: [RunningMetricSample]
    let strideLength: [RunningMetricSample]
    let verticalOscillation: [RunningMetricSample]
    let groundContactTime: [RunningMetricSample]

    static let empty = RunningMetrics(
        cadence: [],
        power: [],
        speed: [],
        strideLength: [],
        verticalOscillation: [],
        groundContactTime: []
    )
}

enum HeartRateZoneMethod: String {
    case heartRateReserve
    case maximumHeartRate
    case observedWorkoutMaximum

    var descriptionText: String {
        switch self {
        case .heartRateReserve:
            return "심박 예비량(HRR) 기준"
        case .maximumHeartRate:
            return "최근 최대심박 기준"
        case .observedWorkoutMaximum:
            return "이번 러닝 관측 최고심박 기준"
        }
    }
}

struct HeartRateZoneProfile {
    let method: HeartRateZoneMethod
    let restingHeartRateBPM: Double?
    let maximumHeartRateBPM: Double

    func bpmRange(lowerFraction: Double, upperFraction: Double) -> ClosedRange<Int> {
        switch method {
        case .heartRateReserve:
            let resting = restingHeartRateBPM ?? 0
            let reserve = max(maximumHeartRateBPM - resting, 1)
            let lower = Int((resting + reserve * lowerFraction).rounded())
            let upper = Int((resting + reserve * upperFraction).rounded())
            return lower...max(lower, upper)
        case .maximumHeartRate, .observedWorkoutMaximum:
            let lower = Int((maximumHeartRateBPM * lowerFraction).rounded())
            let upper = Int((maximumHeartRateBPM * upperFraction).rounded())
            return lower...max(lower, upper)
        }
    }
}

struct RunDetail {
    let route: [RunRoutePoint]
    let distanceTimeline: [DistanceTimelinePoint]
    let heartRates: [HeartRateSample]
    let runningMetrics: RunningMetrics
    let paceSamples: [PaceSample]
    let splits: [RunSplit]
    let activeDuration: TimeInterval
    let heartRateZoneProfile: HeartRateZoneProfile?

    init(
        route: [RunRoutePoint],
        distanceTimeline: [DistanceTimelinePoint],
        heartRates: [HeartRateSample],
        runningMetrics: RunningMetrics,
        paceSamples: [PaceSample],
        splits: [RunSplit],
        activeDuration: TimeInterval? = nil,
        heartRateZoneProfile: HeartRateZoneProfile? = nil
    ) {
        self.route = route
        self.distanceTimeline = distanceTimeline
        self.heartRates = heartRates
        self.runningMetrics = runningMetrics
        self.paceSamples = paceSamples
        self.splits = splits
        self.activeDuration = activeDuration ?? distanceTimeline.last?.elapsed ?? 0
        self.heartRateZoneProfile = heartRateZoneProfile
    }

    static let empty = RunDetail(
        route: [],
        distanceTimeline: [],
        heartRates: [],
        runningMetrics: .empty,
        paceSamples: [],
        splits: [],
        activeDuration: 0,
        heartRateZoneProfile: nil
    )
}

struct RunRoutePoint: Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let distanceMeters: Double
    let altitudeMeters: Double?

    init(
        latitude: Double,
        longitude: Double,
        timestamp: Date,
        distanceMeters: Double,
        altitudeMeters: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.distanceMeters = distanceMeters
        self.altitudeMeters = altitudeMeters
    }
}

struct DistanceTimelinePoint: Identifiable {
    let id: Double
    let date: Date
    let elapsed: TimeInterval
    let distanceMeters: Double
    let segmentIndex: Int

    init(date: Date, elapsed: TimeInterval, distanceMeters: Double, segmentIndex: Int) {
        self.id = elapsed
        self.date = date
        self.elapsed = elapsed
        self.distanceMeters = distanceMeters
        self.segmentIndex = segmentIndex
    }
}

struct PaceSample: Identifiable {
    let id = UUID()
    let date: Date
    let distanceMeters: Double
    let secondsPerKilometer: Double
    let segmentIndex: Int
}

struct RunSplit: Identifiable {
    let id = UUID()
    let index: Int
    let distanceMeters: Double
    let duration: TimeInterval
    let averageHeartRate: Double?
    let averageCadence: Double?

    var paceSecondsPerKilometer: Double {
        duration / max(distanceMeters / 1_000, 0.001)
    }

    var titleText: String {
        if distanceMeters >= 999.5 {
            return "\(index) km"
        }

        let distanceInKilometers = distanceMeters / 1_000
        return "\(distanceInKilometers.formatted(.number.precision(.fractionLength(2)))) km"
    }

    var paceText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return (formatter.string(from: paceSecondsPerKilometer) ?? "-") + "/km"
    }

    var durationText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: duration) ?? "-"
    }

    var heartRateText: String {
        guard let averageHeartRate else { return "-" }
        return averageHeartRate.formatted(.number.precision(.fractionLength(0))) + " bpm"
    }

    var cadenceText: String {
        guard let averageCadence else { return "-" }
        return averageCadence.formatted(.number.precision(.fractionLength(0))) + " spm"
    }
}

struct MileagePeriod: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let distanceText: String
}

struct RunningShoe: Identifiable, Codable, Equatable {
    let id: UUID
    var nickname: String
    var brand: String
    var model: String
    var startMileageKilometers: Double
    var retirementKilometers: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        nickname: String,
        brand: String,
        model: String,
        startMileageKilometers: Double = 0,
        retirementKilometers: Double = 600,
        createdAt: Date = .now
    ) {
        self.id = id
        self.nickname = nickname
        self.brand = brand
        self.model = model
        self.startMileageKilometers = startMileageKilometers
        self.retirementKilometers = retirementKilometers
        self.createdAt = createdAt
    }

    var displayName: String {
        if nickname.isEmpty {
            return [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        }

        return nickname
    }

    var brandModelText: String {
        let combined = [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? "브랜드/모델 미입력" : combined
    }
}

struct ShoeAssignmentRecord: Codable, Equatable {
    var runID: UUID
    var shoeID: UUID
}

extension RunDetail {
    private static func mockRunningMetrics() -> RunningMetrics {
        RunningMetrics(
            cadence: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 168, elapsed: 0, distanceMeters: 0, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-720), value: 172, elapsed: 180, distanceMeters: 620, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-540), value: 176, elapsed: 360, distanceMeters: 1_300, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-360), value: 178, elapsed: 540, distanceMeters: 2_080, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-180), value: 174, elapsed: 720, distanceMeters: 2_860, segmentIndex: 0)
            ],
            power: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 205, elapsed: 0, distanceMeters: 0, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-540), value: 228, elapsed: 360, distanceMeters: 1_300, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-180), value: 221, elapsed: 720, distanceMeters: 2_860, segmentIndex: 0)
            ],
            speed: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 2.8, elapsed: 0, distanceMeters: 0, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-540), value: 3.2, elapsed: 360, distanceMeters: 1_300, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-180), value: 3.1, elapsed: 720, distanceMeters: 2_860, segmentIndex: 0)
            ],
            strideLength: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 1.02, elapsed: 0, distanceMeters: 0, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-540), value: 1.08, elapsed: 360, distanceMeters: 1_300, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-180), value: 1.10, elapsed: 720, distanceMeters: 2_860, segmentIndex: 0)
            ],
            verticalOscillation: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 8.1, elapsed: 0, distanceMeters: 0, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-540), value: 8.5, elapsed: 360, distanceMeters: 1_300, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-180), value: 8.3, elapsed: 720, distanceMeters: 2_860, segmentIndex: 0)
            ],
            groundContactTime: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 256, elapsed: 0, distanceMeters: 0, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-540), value: 244, elapsed: 360, distanceMeters: 1_300, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-180), value: 248, elapsed: 720, distanceMeters: 2_860, segmentIndex: 0)
            ]
        )
    }

    static let mockMissingRoute = RunDetail(
        route: [],
        distanceTimeline: [
            DistanceTimelinePoint(date: .now.addingTimeInterval(-900), elapsed: 0, distanceMeters: 0, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-600), elapsed: 300, distanceMeters: 1_200, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-300), elapsed: 600, distanceMeters: 2_300, segmentIndex: 0),
            DistanceTimelinePoint(date: .now, elapsed: 900, distanceMeters: 3_100, segmentIndex: 0)
        ],
        heartRates: [
            HeartRateSample(date: .now.addingTimeInterval(-900), bpm: 138, elapsed: 0, distanceMeters: 0, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-600), bpm: 149, elapsed: 300, distanceMeters: 1_200, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-300), bpm: 156, elapsed: 600, distanceMeters: 2_300, segmentIndex: 0),
            HeartRateSample(date: .now, bpm: 152, elapsed: 900, distanceMeters: 3_100, segmentIndex: 0)
        ],
        runningMetrics: .empty,
        paceSamples: [
            PaceSample(date: .now.addingTimeInterval(-900), distanceMeters: 0, secondsPerKilometer: 340, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-600), distanceMeters: 1_200, secondsPerKilometer: 330, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-300), distanceMeters: 2_300, secondsPerKilometer: 320, segmentIndex: 0),
            PaceSample(date: .now, distanceMeters: 3_100, secondsPerKilometer: 325, segmentIndex: 0)
        ],
        splits: [
            RunSplit(index: 1, distanceMeters: 1_000, duration: 340, averageHeartRate: 144, averageCadence: 172),
            RunSplit(index: 2, distanceMeters: 1_000, duration: 330, averageHeartRate: 153, averageCadence: 176)
        ]
    )

    static let mockMissingHeartRate = RunDetail(
        route: [
            RunRoutePoint(latitude: 37.5664, longitude: 126.9780, timestamp: .now.addingTimeInterval(-900), distanceMeters: 0),
            RunRoutePoint(latitude: 37.5675, longitude: 126.9792, timestamp: .now.addingTimeInterval(-700), distanceMeters: 650),
            RunRoutePoint(latitude: 37.5681, longitude: 126.9806, timestamp: .now.addingTimeInterval(-500), distanceMeters: 1_420),
            RunRoutePoint(latitude: 37.5690, longitude: 126.9820, timestamp: .now.addingTimeInterval(-300), distanceMeters: 2_180),
            RunRoutePoint(latitude: 37.5698, longitude: 126.9831, timestamp: .now, distanceMeters: 2_940)
        ],
        distanceTimeline: [
            DistanceTimelinePoint(date: .now.addingTimeInterval(-900), elapsed: 0, distanceMeters: 0, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-600), elapsed: 300, distanceMeters: 950, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-300), elapsed: 600, distanceMeters: 1_960, segmentIndex: 0),
            DistanceTimelinePoint(date: .now, elapsed: 900, distanceMeters: 2_940, segmentIndex: 0)
        ],
        heartRates: [],
        runningMetrics: .empty,
        paceSamples: [
            PaceSample(date: .now.addingTimeInterval(-900), distanceMeters: 0, secondsPerKilometer: 360, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-600), distanceMeters: 950, secondsPerKilometer: 347, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-300), distanceMeters: 1_960, secondsPerKilometer: 332, segmentIndex: 0),
            PaceSample(date: .now, distanceMeters: 2_940, secondsPerKilometer: 338, segmentIndex: 0)
        ],
        splits: [
            RunSplit(index: 1, distanceMeters: 1_000, duration: 360, averageHeartRate: nil, averageCadence: 168),
            RunSplit(index: 2, distanceMeters: 1_000, duration: 347, averageHeartRate: nil, averageCadence: 170)
        ]
    )

    static let mockCompleteMetrics = RunDetail(
        route: [
            RunRoutePoint(latitude: 37.5664, longitude: 126.9780, timestamp: .now.addingTimeInterval(-900), distanceMeters: 0),
            RunRoutePoint(latitude: 37.5671, longitude: 126.9791, timestamp: .now.addingTimeInterval(-720), distanceMeters: 620),
            RunRoutePoint(latitude: 37.5678, longitude: 126.9804, timestamp: .now.addingTimeInterval(-540), distanceMeters: 1_300),
            RunRoutePoint(latitude: 37.5686, longitude: 126.9818, timestamp: .now.addingTimeInterval(-360), distanceMeters: 2_080),
            RunRoutePoint(latitude: 37.5694, longitude: 126.9830, timestamp: .now.addingTimeInterval(-180), distanceMeters: 2_860),
            RunRoutePoint(latitude: 37.5701, longitude: 126.9841, timestamp: .now, distanceMeters: 3_520)
        ],
        distanceTimeline: [
            DistanceTimelinePoint(date: .now.addingTimeInterval(-900), elapsed: 0, distanceMeters: 0, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-720), elapsed: 180, distanceMeters: 620, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-540), elapsed: 360, distanceMeters: 1_300, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-360), elapsed: 540, distanceMeters: 2_080, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-180), elapsed: 720, distanceMeters: 2_860, segmentIndex: 0),
            DistanceTimelinePoint(date: .now, elapsed: 900, distanceMeters: 3_520, segmentIndex: 0)
        ],
        heartRates: [
            HeartRateSample(date: .now.addingTimeInterval(-900), bpm: 134, elapsed: 0, distanceMeters: 0, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-720), bpm: 142, elapsed: 180, distanceMeters: 620, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-540), bpm: 148, elapsed: 360, distanceMeters: 1_300, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-360), bpm: 153, elapsed: 540, distanceMeters: 2_080, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-180), bpm: 157, elapsed: 720, distanceMeters: 2_860, segmentIndex: 0),
            HeartRateSample(date: .now, bpm: 151, elapsed: 900, distanceMeters: 3_520, segmentIndex: 0)
        ],
        runningMetrics: mockRunningMetrics(),
        paceSamples: [
            PaceSample(date: .now.addingTimeInterval(-900), distanceMeters: 0, secondsPerKilometer: 355, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-720), distanceMeters: 620, secondsPerKilometer: 335, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-540), distanceMeters: 1_300, secondsPerKilometer: 322, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-360), distanceMeters: 2_080, secondsPerKilometer: 318, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-180), distanceMeters: 2_860, secondsPerKilometer: 326, segmentIndex: 0),
            PaceSample(date: .now, distanceMeters: 3_520, secondsPerKilometer: 336, segmentIndex: 0)
        ],
        splits: [
            RunSplit(index: 1, distanceMeters: 1_000, duration: 342, averageHeartRate: 141, averageCadence: 171),
            RunSplit(index: 2, distanceMeters: 1_000, duration: 323, averageHeartRate: 151, averageCadence: 177),
            RunSplit(index: 3, distanceMeters: 1_000, duration: 321, averageHeartRate: 156, averageCadence: 176),
            RunSplit(index: 4, distanceMeters: 520, duration: 214, averageHeartRate: 152, averageCadence: 173)
        ]
    )

    static let mockPausedWorkout = RunDetail(
        route: [
            RunRoutePoint(latitude: 37.5659, longitude: 126.9775, timestamp: .now.addingTimeInterval(-1_080), distanceMeters: 0),
            RunRoutePoint(latitude: 37.5668, longitude: 126.9788, timestamp: .now.addingTimeInterval(-840), distanceMeters: 760),
            RunRoutePoint(latitude: 37.5676, longitude: 126.9802, timestamp: .now.addingTimeInterval(-660), distanceMeters: 1_380),
            RunRoutePoint(latitude: 37.5682, longitude: 126.9812, timestamp: .now.addingTimeInterval(-300), distanceMeters: 1_380),
            RunRoutePoint(latitude: 37.5692, longitude: 126.9828, timestamp: .now.addingTimeInterval(-150), distanceMeters: 2_100),
            RunRoutePoint(latitude: 37.5700, longitude: 126.9842, timestamp: .now, distanceMeters: 2_920)
        ],
        distanceTimeline: [
            DistanceTimelinePoint(date: .now.addingTimeInterval(-1_080), elapsed: 0, distanceMeters: 0, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-900), elapsed: 180, distanceMeters: 560, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-720), elapsed: 360, distanceMeters: 1_160, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-660), elapsed: 420, distanceMeters: 1_380, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-240), elapsed: 480, distanceMeters: 1_740, segmentIndex: 1),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-120), elapsed: 600, distanceMeters: 2_260, segmentIndex: 1),
            DistanceTimelinePoint(date: .now, elapsed: 720, distanceMeters: 2_920, segmentIndex: 1)
        ],
        heartRates: [
            HeartRateSample(date: .now.addingTimeInterval(-1_020), bpm: 136, elapsed: 60, distanceMeters: 180, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-780), bpm: 146, elapsed: 300, distanceMeters: 960, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-660), bpm: 149, elapsed: 420, distanceMeters: 1_380, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-180), bpm: 154, elapsed: 540, distanceMeters: 1_980, segmentIndex: 1),
            HeartRateSample(date: .now.addingTimeInterval(-60), bpm: 158, elapsed: 660, distanceMeters: 2_540, segmentIndex: 1)
        ],
        runningMetrics: RunningMetrics(
            cadence: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 169, elapsed: 180, distanceMeters: 560, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-720), value: 173, elapsed: 360, distanceMeters: 1_160, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-240), value: 176, elapsed: 480, distanceMeters: 1_740, segmentIndex: 1),
                RunningMetricSample(date: .now.addingTimeInterval(-60), value: 178, elapsed: 660, distanceMeters: 2_540, segmentIndex: 1)
            ],
            power: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 214, elapsed: 180, distanceMeters: 560, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-240), value: 232, elapsed: 480, distanceMeters: 1_740, segmentIndex: 1)
            ],
            speed: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 3.0, elapsed: 180, distanceMeters: 560, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-240), value: 3.3, elapsed: 480, distanceMeters: 1_740, segmentIndex: 1)
            ],
            strideLength: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 1.01, elapsed: 180, distanceMeters: 560, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-240), value: 1.07, elapsed: 480, distanceMeters: 1_740, segmentIndex: 1)
            ],
            verticalOscillation: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 8.4, elapsed: 180, distanceMeters: 560, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-240), value: 8.7, elapsed: 480, distanceMeters: 1_740, segmentIndex: 1)
            ],
            groundContactTime: [
                RunningMetricSample(date: .now.addingTimeInterval(-900), value: 252, elapsed: 180, distanceMeters: 560, segmentIndex: 0),
                RunningMetricSample(date: .now.addingTimeInterval(-240), value: 241, elapsed: 480, distanceMeters: 1_740, segmentIndex: 1)
            ]
        ),
        paceSamples: [
            PaceSample(date: .now.addingTimeInterval(-900), distanceMeters: 560, secondsPerKilometer: 321, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-720), distanceMeters: 1_160, secondsPerKilometer: 305, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-240), distanceMeters: 1_740, secondsPerKilometer: 334, segmentIndex: 1),
            PaceSample(date: .now.addingTimeInterval(-120), distanceMeters: 2_260, secondsPerKilometer: 288, segmentIndex: 1),
            PaceSample(date: .now, distanceMeters: 2_920, secondsPerKilometer: 296, segmentIndex: 1)
        ],
        splits: [
            RunSplit(index: 1, distanceMeters: 1_000, duration: 309, averageHeartRate: 143, averageCadence: 171),
            RunSplit(index: 2, distanceMeters: 1_000, duration: 293, averageHeartRate: 153, averageCadence: 177),
            RunSplit(index: 3, distanceMeters: 920, duration: 118, averageHeartRate: 157, averageCadence: 178)
        ]
    )

    static let mockMissingAdvancedMetrics = RunDetail(
        route: [
            RunRoutePoint(latitude: 37.5657, longitude: 126.9771, timestamp: .now.addingTimeInterval(-840), distanceMeters: 0),
            RunRoutePoint(latitude: 37.5666, longitude: 126.9789, timestamp: .now.addingTimeInterval(-630), distanceMeters: 710),
            RunRoutePoint(latitude: 37.5675, longitude: 126.9806, timestamp: .now.addingTimeInterval(-420), distanceMeters: 1_490),
            RunRoutePoint(latitude: 37.5684, longitude: 126.9821, timestamp: .now.addingTimeInterval(-210), distanceMeters: 2_250),
            RunRoutePoint(latitude: 37.5691, longitude: 126.9833, timestamp: .now, distanceMeters: 2_980)
        ],
        distanceTimeline: [
            DistanceTimelinePoint(date: .now.addingTimeInterval(-840), elapsed: 0, distanceMeters: 0, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-630), elapsed: 210, distanceMeters: 710, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-420), elapsed: 420, distanceMeters: 1_490, segmentIndex: 0),
            DistanceTimelinePoint(date: .now.addingTimeInterval(-210), elapsed: 630, distanceMeters: 2_250, segmentIndex: 0),
            DistanceTimelinePoint(date: .now, elapsed: 840, distanceMeters: 2_980, segmentIndex: 0)
        ],
        heartRates: [
            HeartRateSample(date: .now.addingTimeInterval(-840), bpm: 140, elapsed: 0, distanceMeters: 0, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-630), bpm: 148, elapsed: 210, distanceMeters: 710, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-420), bpm: 152, elapsed: 420, distanceMeters: 1_490, segmentIndex: 0),
            HeartRateSample(date: .now.addingTimeInterval(-210), bpm: 155, elapsed: 630, distanceMeters: 2_250, segmentIndex: 0),
            HeartRateSample(date: .now, bpm: 150, elapsed: 840, distanceMeters: 2_980, segmentIndex: 0)
        ],
        runningMetrics: .empty,
        paceSamples: [
            PaceSample(date: .now.addingTimeInterval(-840), distanceMeters: 0, secondsPerKilometer: 350, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-630), distanceMeters: 710, secondsPerKilometer: 334, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-420), distanceMeters: 1_490, secondsPerKilometer: 322, segmentIndex: 0),
            PaceSample(date: .now.addingTimeInterval(-210), distanceMeters: 2_250, secondsPerKilometer: 328, segmentIndex: 0),
            PaceSample(date: .now, distanceMeters: 2_980, secondsPerKilometer: 340, segmentIndex: 0)
        ],
        splits: [
            RunSplit(index: 1, distanceMeters: 1_000, duration: 338, averageHeartRate: 145, averageCadence: nil),
            RunSplit(index: 2, distanceMeters: 1_000, duration: 326, averageHeartRate: 154, averageCadence: nil),
            RunSplit(index: 3, distanceMeters: 980, duration: 176, averageHeartRate: 151, averageCadence: nil)
        ]
    )
}
