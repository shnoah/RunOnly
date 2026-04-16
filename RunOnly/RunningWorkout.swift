import Foundation
import HealthKit

// HealthKit workout을 앱 UI에서 쓰기 쉬운 형태로 감싼 모델이다.
struct RunningWorkout: Identifiable {
    let id: UUID
    let workout: HKWorkout?
    let startDate: Date
    let duration: TimeInterval
    let distanceInMeters: Double
    let sourceName: String
    let sourceBundleIdentifier: String
    private let indoorWorkoutOverride: Bool?

    init(workout: HKWorkout) {
        id = workout.uuid
        self.workout = workout
        startDate = workout.startDate
        duration = workout.duration
        distanceInMeters = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        sourceName = workout.sourceRevision.source.name
        sourceBundleIdentifier = workout.sourceRevision.source.bundleIdentifier
        indoorWorkoutOverride = nil
    }

    init(
        id: UUID = UUID(),
        startDate: Date,
        duration: TimeInterval,
        distanceInMeters: Double,
        sourceName: String,
        sourceBundleIdentifier: String,
        isIndoorWorkout: Bool?
    ) {
        self.id = id
        self.workout = nil
        self.startDate = startDate
        self.duration = duration
        self.distanceInMeters = distanceInMeters
        self.sourceName = sourceName
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.indoorWorkoutOverride = isIndoorWorkout
    }

    var distanceText: String {
        RunDisplayFormatter.distance(meters: distanceInMeters, fractionLength: 2)
    }

    var distanceInKilometers: Double {
        distanceInMeters / 1_000
    }

    var durationText: String {
        RunDisplayFormatter.duration(duration)
    }

    var paceText: String {
        RunDisplayFormatter.pace(duration: duration, distanceMeters: distanceInMeters)
    }

    var isAppleWorkout: Bool {
        sourceBundleIdentifier.lowercased().hasPrefix("com.apple.health")
    }

    var isDemoWorkout: Bool {
        sourceBundleIdentifier == "com.shnoah.RunOnly.demo"
    }

    var isIndoorWorkout: Bool? {
        if let workout, let value = workout.metadata?[HKMetadataKeyIndoorWorkout] as? NSNumber {
            return value.boolValue
        }
        return indoorWorkoutOverride
    }

    var environmentText: String {
        switch isIndoorWorkout {
        case true:
            return L10n.tr("실내")
        case false:
            return L10n.tr("실외")
        case nil:
            return L10n.tr("미확인")
        }
    }

    var environmentBadgeText: String {
        switch isIndoorWorkout {
        case true:
            return L10n.tr("실내 러닝")
        case false:
            return L10n.tr("실외 러닝")
        case nil:
            return L10n.tr("러닝 기록")
        }
    }

    var environmentShortText: String {
        switch isIndoorWorkout {
        case true:
            return L10n.tr("실내")
        case false:
            return L10n.tr("실외")
        case nil:
            return L10n.tr("미확인")
        }
    }

    var recordDateText: String {
        RunDisplayFormatter.recordDate(startDate)
    }

    var recordCompactDateText: String {
        RunDisplayFormatter.recordCompactDate(startDate)
    }

    var detailDateText: String {
        RunDisplayFormatter.detailDate(startDate)
    }

    var titleText: String {
        recordDateText
    }

    var sourceSummaryText: String {
        if isDemoWorkout {
            return L10n.tr("샘플 러닝으로 둘러보는 기록이에요.")
        }

        if isAppleWorkout {
            return L10n.tr("Apple 건강에 저장된 러닝 기록이에요.")
        }

        return L10n.format("%@에서 가져온 러닝 기록이에요.", sourceName)
    }

    static let demoSample = RunningWorkout(
        id: UUID(uuidString: "8A6D2A35-4222-4E7E-A4E1-7D3B57F593A1") ?? UUID(),
        startDate: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 7, minute: 30)) ?? .now,
        duration: 900,
        distanceInMeters: 3_520,
        sourceName: "RunOnly Demo",
        sourceBundleIdentifier: "com.shnoah.RunOnly.demo",
        isIndoorWorkout: false
    )
}

// 최근 러닝 몇 개를 바탕으로 대표 거리 기록을 보수적으로 추정하는 계산 규칙이다.
enum PredictionModel {
    static let lookbackDays = 120

    static func predictedSeconds(
        for targetDistance: Double,
        from runs: [RunningWorkout],
        referenceDate: Date = Date()
    ) -> Double? {
        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .day, value: -lookbackDays, to: referenceDate) ?? .distantPast
        // 목표 거리별 최소 기준보다 짧은 러닝은 예측 품질이 떨어져 제외한다.
        let windowRuns = runs.filter {
            $0.startDate >= windowStart &&
            $0.startDate <= referenceDate &&
            $0.distanceInMeters >= minimumEligibleDistance(for: targetDistance)
        }

        guard !windowRuns.isEmpty else {
            return nil
        }

        // 최근 후보 중 가장 빠른 값 몇 개만 보고 중앙값을 택해 과도한 낙관치를 줄인다.
        let projected = windowRuns
            .map { projectedSeconds(for: $0, targetDistance: targetDistance) }
            .sorted()
        let sampleCount = min(projected.count, 3)
        return median(Array(projected.prefix(sampleCount)))
    }

    static var eligibilitySummaryText: String {
        L10n.tr("5K는 3km, 10K는 5km, 하프는 8km, 풀은 10km 이상 러닝만 반영합니다.")
    }

    private static func projectedSeconds(for run: RunningWorkout, targetDistance: Double) -> Double {
        run.duration * pow(targetDistance / run.distanceInMeters, 1.06)
    }

    private static func minimumEligibleDistance(for targetDistance: Double) -> Double {
        switch targetDistance {
        case ..<7_500:
            return 3_000
        case ..<15_000:
            return 5_000
        case ..<30_000:
            return 8_000
        default:
            return 10_000
        }
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }
}

// 홈 대시보드에 표시할 핵심 요약 수치 묶음이다.
struct RunningSummary {
    let monthDistanceKilometers: Double
    let yearDistanceKilometers: Double
    let monthDistanceText: String
    let yearDistanceText: String
    let recoveryReadiness: RecoveryReadiness
    let vo2MaxText: String
    let vo2MaxDateText: String
    let predicted5KText: String
    let predicted10KText: String
    let predictedHalfText: String
    let predictedMarathonText: String

    static var empty: RunningSummary {
        RunningSummary(
        monthDistanceKilometers: 0,
        yearDistanceKilometers: 0,
        monthDistanceText: RunDisplayFormatter.distance(kilometers: 0),
        yearDistanceText: RunDisplayFormatter.distance(kilometers: 0),
        recoveryReadiness: .empty,
        vo2MaxText: "-",
        vo2MaxDateText: L10n.tr("VO2 Max 데이터 없음"),
        predicted5KText: "-",
        predicted10KText: "-",
        predictedHalfText: "-",
        predictedMarathonText: "-"
    )
    }
}

struct RecoveryLoadPoint: Identifiable, Equatable {
    let date: Date
    let load: Double

    var id: Date { date }

    var label: String {
        date.formatted(.dateTime.weekday(.narrow))
    }

    var dateText: String {
        RunDisplayFormatter.shortMonthDay(date)
    }

    var loadText: String {
        L10n.format("%d점", Int(load.rounded()))
    }
}

struct RecoveryReadiness {
    let score: Int?
    let status: String
    let detail: String
    let recommendationTitle: String
    let recommendationDetail: String
    let factors: [String]
    let confidenceText: String
    let recentLoadText: String
    let lastRunText: String
    let restingHeartRateText: String?
    let loadRatioText: String?
    let weeklyLoadChart: [RecoveryLoadPoint]
    let isDataSufficient: Bool
    let dataRequirementText: String?

    var scoreText: String {
        if let score {
            return L10n.format("%d점", score)
        }
        return "--"
    }

    var dashboardValueText: String {
        if score != nil {
            return scoreText
        }
        return status
    }

    var dashboardDetailText: String {
        if isDataSufficient {
            return detail
        }
        return dataRequirementText ?? recommendationTitle
    }

    static var empty: RecoveryReadiness {
        RecoveryReadiness(
            score: nil,
            status: L10n.tr("데이터 필요"),
            detail: L10n.tr("최근 러닝이 더 쌓이면 준비도를 계산합니다."),
            recommendationTitle: L10n.tr("러닝 데이터가 더 필요해요"),
            recommendationDetail: L10n.tr("최근 28일 안에 최소 3회의 러닝이 있으면 준비도를 보여드릴게요."),
            factors: [
                L10n.tr("최근 28일 러닝 3회 이상 필요"),
                L10n.tr("최근 10일 안 러닝 필요")
            ],
            confidenceText: L10n.tr("데이터가 더 쌓이면 계산"),
            recentLoadText: "-",
            lastRunText: "-",
            restingHeartRateText: nil,
            loadRatioText: nil,
            weeklyLoadChart: [],
            isDataSufficient: false,
            dataRequirementText: L10n.tr("최근 28일 안에 최소 3회의 러닝이 필요합니다.")
        )
    }
}

struct RestingHeartRateSnapshot {
    let latestBPM: Double
    let baselineBPM: Double
    let measuredAt: Date
    let sampleCount: Int

    var deltaFromBaseline: Double {
        latestBPM - baselineBPM
    }
}

// VO2 Max 한 점은 값과 측정 날짜만 있으면 충분하다.
struct VO2MaxSample {
    let value: Double
    let date: Date
}

// 심박 샘플은 상세 차트와 존 계산에서 함께 사용한다.
struct HeartRateSample: Identifiable {
    let id = UUID()
    let date: Date
    let bpm: Double
    let elapsed: TimeInterval?
    let distanceMeters: Double?
    let segmentIndex: Int?
}

// 케이던스/파워 같은 러닝 메트릭은 공통 구조로 다룬다.
struct RunningMetricSample: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let elapsed: TimeInterval?
    let distanceMeters: Double?
    let segmentIndex: Int?
}

// 상세 화면에서 지원하는 러닝 메트릭 모음이다.
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

// 상세 화면 상단 요약에 필요한 파생 수치를 공용 구조로 묶는다.
struct RunSummaryMetrics: Codable, Equatable {
    let averageHeartRate: Double?
    let averageCadence: Double?
    let elevationGainMeters: Double?

    var hasAnyValue: Bool {
        averageHeartRate != nil || averageCadence != nil || elevationGainMeters != nil
    }

    var averageHeartRateText: String? {
        RunDisplayFormatter.heartRate(averageHeartRate)
    }

    var averageCadenceText: String? {
        RunDisplayFormatter.cadence(averageCadence)
    }

    var elevationGainText: String? {
        RunDisplayFormatter.elevation(elevationGainMeters)
    }

    func mergingMissingValues(from fallback: RunSummaryMetrics?) -> RunSummaryMetrics {
        RunSummaryMetrics(
            averageHeartRate: averageHeartRate ?? fallback?.averageHeartRate,
            averageCadence: averageCadence ?? fallback?.averageCadence,
            elevationGainMeters: elevationGainMeters ?? fallback?.elevationGainMeters
        )
    }
}

// 심박 존 계산 기준은 데이터 가용성에 따라 달라진다.
enum HeartRateZoneMethod: String {
    case heartRateReserve
    case maximumHeartRate
    case observedWorkoutMaximum

    var descriptionText: String {
        switch self {
        case .heartRateReserve:
            return L10n.tr("심박 예비량(HRR) 기준")
        case .maximumHeartRate:
            return L10n.tr("최근 최대심박 기준")
        case .observedWorkoutMaximum:
            return L10n.tr("이번 러닝 관측 최고심박 기준")
        }
    }
}

// 심박 존 범위를 계산하기 위해 필요한 사용자 프로필 값이다.
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

// 러닝 상세 화면에 필요한 모든 가공 데이터를 한 번에 묶는다.
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

    // route 고도는 샘플이 촘촘해 미세 상승이 잘게 쪼개질 수 있어,
    // 거리 버킷 평균을 만든 뒤 valley/peak 기준으로 누적 상승고도를 계산한다.
    var elevationGainMeters: Double? {
        let altitudeSamples = bucketedAltitudeSamples
        guard altitudeSamples.count >= 2 else { return nil }

        let minimumClimbMeters = 1.0
        var totalGain: Double = 0
        var valley = altitudeSamples[0]
        var peak = altitudeSamples[0]

        for altitude in altitudeSamples.dropFirst() {
            if altitude > peak {
                peak = altitude
            }

            // valley에서 1m 이상 오른 뒤 다시 1m 이상 내려오면 한 번의 climb으로 확정한다.
            if peak - valley >= minimumClimbMeters, altitude <= peak - minimumClimbMeters {
                totalGain += peak - valley
                valley = altitude
                peak = altitude
                continue
            }

            if altitude < valley {
                valley = altitude
                peak = altitude
            }
        }

        let trailingClimb = peak - valley
        if trailingClimb >= minimumClimbMeters {
            totalGain += trailingClimb
        }

        return totalGain >= minimumClimbMeters ? totalGain : nil
    }

    var elevationGainText: String? {
        RunDisplayFormatter.elevation(elevationGainMeters)
    }

    var averageHeartRate: Double? {
        guard !heartRates.isEmpty else { return nil }
        return heartRates.map(\.bpm).reduce(0, +) / Double(heartRates.count)
    }

    var averageCadence: Double? {
        let weightedCadence = splits.reduce(into: (weighted: 0.0, duration: 0.0)) { partial, split in
            guard let cadence = split.averageCadence else { return }
            partial.weighted += cadence * split.duration
            partial.duration += split.duration
        }

        if weightedCadence.duration > 0 {
            return weightedCadence.weighted / weightedCadence.duration
        }

        guard !runningMetrics.cadence.isEmpty else { return nil }
        return runningMetrics.cadence.map(\.value).reduce(0, +) / Double(runningMetrics.cadence.count)
    }

    var summaryMetrics: RunSummaryMetrics {
        RunSummaryMetrics(
            averageHeartRate: averageHeartRate,
            averageCadence: averageCadence,
            elevationGainMeters: elevationGainMeters
        )
    }

    private var bucketedAltitudeSamples: [Double] {
        let samples = route.compactMap { point -> (distanceMeters: Double, altitudeMeters: Double)? in
            guard let altitudeMeters = point.altitudeMeters else { return nil }
            return (point.distanceMeters, altitudeMeters)
        }

        guard samples.count >= 2 else {
            return samples.map(\.altitudeMeters)
        }

        let bucketSizeMeters = 20.0
        var bucketAverages: [Double] = []
        var currentBucketIndex = Int(floor(samples[0].distanceMeters / bucketSizeMeters))
        var altitudeSum = 0.0
        var altitudeCount = 0

        func flushCurrentBucket() {
            guard altitudeCount > 0 else { return }
            bucketAverages.append(altitudeSum / Double(altitudeCount))
            altitudeSum = 0
            altitudeCount = 0
        }

        for sample in samples {
            let bucketIndex = Int(floor(sample.distanceMeters / bucketSizeMeters))
            if bucketIndex != currentBucketIndex {
                flushCurrentBucket()
                currentBucketIndex = bucketIndex
            }

            altitudeSum += sample.altitudeMeters
            altitudeCount += 1
        }

        flushCurrentBucket()
        return bucketAverages.count >= 2 ? bucketAverages : samples.map(\.altitudeMeters)
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

    func updatingSupplementary(
        route: [RunRoutePoint],
        heartRateZoneProfile: HeartRateZoneProfile?
    ) -> RunDetail {
        RunDetail(
            route: route.isEmpty ? self.route : route,
            distanceTimeline: distanceTimeline,
            heartRates: heartRates,
            runningMetrics: runningMetrics,
            paceSamples: paceSamples,
            splits: splits,
            activeDuration: activeDuration,
            heartRateZoneProfile: heartRateZoneProfile ?? self.heartRateZoneProfile
        )
    }
}

// 지도에 그릴 경로 포인트는 거리와 고도까지 함께 가진다.
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

// 거리 타임라인은 러닝 전체를 같은 축으로 연결하는 기준선이다.
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

// 페이스 샘플은 거리별 페이스 차트를 만들 때 사용한다.
struct PaceSample: Identifiable {
    let id = UUID()
    let date: Date
    let distanceMeters: Double
    let secondsPerKilometer: Double
    let segmentIndex: Int
}

// 스플릿은 구간별 평균값을 테이블에 뿌리기 쉽게 가공한 결과다.
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
        let fullSplitMeters = 1_000.0
        let isFullSplit = abs(distanceMeters - fullSplitMeters) < 0.5
        let displayedMeters = isFullSplit ? fullSplitMeters * Double(index) : distanceMeters
        let displayedValue = RunDisplayFormatter.displayedDistanceValue(
            kilometers: displayedMeters / 1_000,
            preference: RunDisplayFormatter.currentDistanceUnitPreference
        )

        return displayedValue.formatted(
            .number
                .locale(RunDisplayFormatter.currentAppLocale)
                .precision(.fractionLength(0...2))
        )
    }

    var paceText: String {
        RunDisplayFormatter.pace(secondsPerKilometer: paceSecondsPerKilometer)
    }

    var durationText: String {
        RunDisplayFormatter.duration(duration)
    }

    var heartRateText: String {
        RunDisplayFormatter.heartRate(averageHeartRate) ?? "-"
    }

    var cadenceText: String {
        RunDisplayFormatter.cadence(averageCadence) ?? "-"
    }
}

// 월/연 단위 누적 거리 카드 모델이다.
struct MileagePeriod: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let distanceText: String
}

enum MileageHistoryRange: String, CaseIterable, Identifiable {
    case currentYear
    case recentThreeYears
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .currentYear:
            return L10n.tr("올해")
        case .recentThreeYears:
            return L10n.tr("최근 3년")
        case .all:
            return L10n.tr("전체")
        }
    }
}

// 신발 정보는 사용자 입력 기반이므로 Codable로 저장한다.
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
        return combined.isEmpty ? L10n.tr("브랜드/모델 미입력") : combined
    }
}

// 러닝과 신발 연결 관계를 별도 레코드로 관리한다.
struct ShoeAssignmentRecord: Codable, Equatable {
    var runID: UUID
    var shoeID: UUID
}

// 아래 mock 데이터는 개발 중 상세 화면 레이아웃을 점검할 때 사용한다.
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
            RunRoutePoint(latitude: 37.5664, longitude: 126.9780, timestamp: .now.addingTimeInterval(-900), distanceMeters: 0, altitudeMeters: 11),
            RunRoutePoint(latitude: 37.5675, longitude: 126.9792, timestamp: .now.addingTimeInterval(-700), distanceMeters: 650, altitudeMeters: 15),
            RunRoutePoint(latitude: 37.5681, longitude: 126.9806, timestamp: .now.addingTimeInterval(-500), distanceMeters: 1_420, altitudeMeters: 18),
            RunRoutePoint(latitude: 37.5690, longitude: 126.9820, timestamp: .now.addingTimeInterval(-300), distanceMeters: 2_180, altitudeMeters: 22),
            RunRoutePoint(latitude: 37.5698, longitude: 126.9831, timestamp: .now, distanceMeters: 2_940, altitudeMeters: 24)
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
            RunRoutePoint(latitude: 37.5664, longitude: 126.9780, timestamp: .now.addingTimeInterval(-900), distanceMeters: 0, altitudeMeters: 18),
            RunRoutePoint(latitude: 37.5671, longitude: 126.9791, timestamp: .now.addingTimeInterval(-720), distanceMeters: 620, altitudeMeters: 22),
            RunRoutePoint(latitude: 37.5678, longitude: 126.9804, timestamp: .now.addingTimeInterval(-540), distanceMeters: 1_300, altitudeMeters: 27),
            RunRoutePoint(latitude: 37.5686, longitude: 126.9818, timestamp: .now.addingTimeInterval(-360), distanceMeters: 2_080, altitudeMeters: 31),
            RunRoutePoint(latitude: 37.5694, longitude: 126.9830, timestamp: .now.addingTimeInterval(-180), distanceMeters: 2_860, altitudeMeters: 34),
            RunRoutePoint(latitude: 37.5701, longitude: 126.9841, timestamp: .now, distanceMeters: 3_520, altitudeMeters: 33)
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
            RunRoutePoint(latitude: 37.5659, longitude: 126.9775, timestamp: .now.addingTimeInterval(-1_080), distanceMeters: 0, altitudeMeters: 12),
            RunRoutePoint(latitude: 37.5668, longitude: 126.9788, timestamp: .now.addingTimeInterval(-840), distanceMeters: 760, altitudeMeters: 18),
            RunRoutePoint(latitude: 37.5676, longitude: 126.9802, timestamp: .now.addingTimeInterval(-660), distanceMeters: 1_380, altitudeMeters: 24),
            RunRoutePoint(latitude: 37.5682, longitude: 126.9812, timestamp: .now.addingTimeInterval(-300), distanceMeters: 1_380, altitudeMeters: 24),
            RunRoutePoint(latitude: 37.5692, longitude: 126.9828, timestamp: .now.addingTimeInterval(-150), distanceMeters: 2_100, altitudeMeters: 31),
            RunRoutePoint(latitude: 37.5700, longitude: 126.9842, timestamp: .now, distanceMeters: 2_920, altitudeMeters: 35)
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
            RunRoutePoint(latitude: 37.5657, longitude: 126.9771, timestamp: .now.addingTimeInterval(-840), distanceMeters: 0, altitudeMeters: 9),
            RunRoutePoint(latitude: 37.5666, longitude: 126.9789, timestamp: .now.addingTimeInterval(-630), distanceMeters: 710, altitudeMeters: 14),
            RunRoutePoint(latitude: 37.5675, longitude: 126.9806, timestamp: .now.addingTimeInterval(-420), distanceMeters: 1_490, altitudeMeters: 19),
            RunRoutePoint(latitude: 37.5684, longitude: 126.9821, timestamp: .now.addingTimeInterval(-210), distanceMeters: 2_250, altitudeMeters: 25),
            RunRoutePoint(latitude: 37.5691, longitude: 126.9833, timestamp: .now, distanceMeters: 2_980, altitudeMeters: 28)
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
