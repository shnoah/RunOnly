import Foundation
import HealthKit
import CoreLocation
// HealthKit을 사용할 수 없는 기기에서 보여줄 공통 오류다.
enum HealthKitServiceError: Equatable, LocalizedError {
    case notAvailable
    case missingWorkoutReference

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return L10n.tr("이 기기에서는 Apple 건강 데이터를 사용할 수 없습니다.")
        case .missingWorkoutReference:
            return L10n.tr("이 러닝의 원본 운동 데이터를 찾을 수 없습니다.")
        }
    }
}


// HealthKitService owns the store; query and detail-building responsibilities live in focused extensions.
final class HealthKitService {
    let healthStore = HKHealthStore()
}
