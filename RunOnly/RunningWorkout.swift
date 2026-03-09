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

    var titleText: String {
        startDate.formatted(date: .abbreviated, time: .shortened)
    }
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
    let distanceMeters: Double?
}

struct RunDetail {
    let route: [RunRoutePoint]
    let heartRates: [HeartRateSample]
    let paceSamples: [PaceSample]
    let splits: [RunSplit]

    static let empty = RunDetail(route: [], heartRates: [], paceSamples: [], splits: [])
}

struct RunRoutePoint: Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let distanceMeters: Double
}

struct PaceSample: Identifiable {
    let id = UUID()
    let date: Date
    let distanceMeters: Double
    let secondsPerKilometer: Double
}

struct RunSplit: Identifiable {
    let id = UUID()
    let index: Int
    let distanceMeters: Double
    let duration: TimeInterval

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
    static let mockMissingRoute = RunDetail(
        route: [],
        heartRates: [
            HeartRateSample(date: .now.addingTimeInterval(-900), bpm: 138, distanceMeters: 0),
            HeartRateSample(date: .now.addingTimeInterval(-600), bpm: 149, distanceMeters: 1_200),
            HeartRateSample(date: .now.addingTimeInterval(-300), bpm: 156, distanceMeters: 2_300),
            HeartRateSample(date: .now, bpm: 152, distanceMeters: 3_100)
        ],
        paceSamples: [
            PaceSample(date: .now.addingTimeInterval(-900), distanceMeters: 0, secondsPerKilometer: 340),
            PaceSample(date: .now.addingTimeInterval(-600), distanceMeters: 1_200, secondsPerKilometer: 330),
            PaceSample(date: .now.addingTimeInterval(-300), distanceMeters: 2_300, secondsPerKilometer: 320),
            PaceSample(date: .now, distanceMeters: 3_100, secondsPerKilometer: 325)
        ],
        splits: [
            RunSplit(index: 1, distanceMeters: 1_000, duration: 340),
            RunSplit(index: 2, distanceMeters: 1_000, duration: 330)
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
        heartRates: [],
        paceSamples: [
            PaceSample(date: .now.addingTimeInterval(-900), distanceMeters: 0, secondsPerKilometer: 360),
            PaceSample(date: .now.addingTimeInterval(-600), distanceMeters: 950, secondsPerKilometer: 347),
            PaceSample(date: .now.addingTimeInterval(-300), distanceMeters: 1_960, secondsPerKilometer: 332),
            PaceSample(date: .now, distanceMeters: 2_940, secondsPerKilometer: 338)
        ],
        splits: [
            RunSplit(index: 1, distanceMeters: 1_000, duration: 360),
            RunSplit(index: 2, distanceMeters: 1_000, duration: 347)
        ]
    )
}
