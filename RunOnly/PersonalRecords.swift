import Foundation

// 앱에서 지원하는 PR 거리 구간을 한곳에서 정의한다.
enum PersonalRecordDistance: String, CaseIterable, Codable, Identifiable {
    case meters400
    case meters800
    case kilometer1
    case kilometers5
    case kilometers10
    case halfMarathon
    case marathon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .meters400: return "400m"
        case .meters800: return "800m"
        case .kilometer1: return "1K"
        case .kilometers5: return "5K"
        case .kilometers10: return "10K"
        case .halfMarathon: return "하프"
        case .marathon: return "풀"
        }
    }

    var meters: Double {
        switch self {
        case .meters400: return 400
        case .meters800: return 800
        case .kilometer1: return 1_000
        case .kilometers5: return 5_000
        case .kilometers10: return 10_000
        case .halfMarathon: return 21_097.5
        case .marathon: return 42_195
        }
    }
}

// 사용자에게 보여줄 확정 PR 한 건을 담는다.
struct PersonalRecordEntry: Identifiable, Codable {
    let distance: PersonalRecordDistance
    var duration: TimeInterval?
    var date: Date?
    var workoutID: UUID?

    var id: String { distance.id }

    var valueText: String {
        guard let duration else { return "-" }
        return formatPersonalRecordDuration(duration)
    }

    var detailText: String {
        guard let date else { return "기록 없음" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static var placeholders: [PersonalRecordEntry] {
        PersonalRecordDistance.allCases.map {
            PersonalRecordEntry(distance: $0, duration: nil, date: nil, workoutID: nil)
        }
    }
}

// 기존 PR을 대체할 수 있는 후보 기록을 담는다.
struct PersonalRecordCandidate: Identifiable, Codable {
    let distance: PersonalRecordDistance
    var duration: TimeInterval
    var date: Date
    var workoutID: UUID

    var id: String { distance.id }

    var valueText: String {
        formatPersonalRecordDuration(duration)
    }

    var detailText: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

// PR 계산 결과와 처리 이력을 로컬에 저장하기 위한 스냅샷이다.
struct PersonalRecordSnapshot: Codable {
    var version: Int
    var records: [PersonalRecordEntry]
    var pendingCandidates: [PersonalRecordCandidate]
    var processedRunIDs: [UUID]
    var updatedAt: Date?

    static func empty(version: Int) -> PersonalRecordSnapshot {
        PersonalRecordSnapshot(
            version: version,
            records: PersonalRecordEntry.placeholders,
            pendingCandidates: [],
            processedRunIDs: [],
            updatedAt: nil
        )
    }
}

// HealthKit 파생 데이터는 백업 제외 저장소에 보관해 심사 리스크를 줄인다.
final class PersonalRecordStore {
    private let snapshotFilename = "personal-records.json"
    let version = 2

    func load() -> PersonalRecordSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard
            let snapshot = try? AppStorage.load(PersonalRecordSnapshot.self, from: snapshotFilename, decoder: decoder),
            snapshot.version == version
        else {
            return .empty(version: version)
        }

        return snapshot
    }

    func save(_ snapshot: PersonalRecordSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? AppStorage.save(snapshot, to: snapshotFilename, encoder: encoder)
    }
}

// PR 표시는 앱 전반에서 같은 포맷을 쓰도록 공통 함수로 분리한다.
func formatPersonalRecordDuration(_ duration: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = [.pad]
    return formatter.string(from: duration) ?? "-"
}
