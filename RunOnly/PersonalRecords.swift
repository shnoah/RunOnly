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
        case .halfMarathon: return L10n.tr("하프")
        case .marathon: return L10n.tr("풀")
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
        guard let date else { return L10n.tr("기록 없음") }
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

// 확정된 PR 경신 이력 한 건을 그래프와 축하 배너에서 함께 사용한다.
struct PersonalRecordHistoryEntry: Identifiable, Codable {
    let distance: PersonalRecordDistance
    var duration: TimeInterval
    var date: Date
    var workoutID: UUID

    var id: String { "\(distance.id)-\(workoutID.uuidString)" }

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
    var history: [PersonalRecordHistoryEntry]
    var processedRunIDs: [UUID]
    var updatedAt: Date?

    init(
        version: Int,
        records: [PersonalRecordEntry],
        pendingCandidates: [PersonalRecordCandidate],
        history: [PersonalRecordHistoryEntry],
        processedRunIDs: [UUID],
        updatedAt: Date?
    ) {
        self.version = version
        self.records = records
        self.pendingCandidates = pendingCandidates
        self.history = history
        self.processedRunIDs = processedRunIDs
        self.updatedAt = updatedAt
    }

    static func empty(version: Int) -> PersonalRecordSnapshot {
        PersonalRecordSnapshot(
            version: version,
            records: PersonalRecordEntry.placeholders,
            pendingCandidates: [],
            history: [],
            processedRunIDs: [],
            updatedAt: nil
        )
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case records
        case pendingCandidates
        case history
        case processedRunIDs
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        records = try container.decode([PersonalRecordEntry].self, forKey: .records)
        pendingCandidates = try container.decodeIfPresent([PersonalRecordCandidate].self, forKey: .pendingCandidates) ?? []
        history = try container.decodeIfPresent([PersonalRecordHistoryEntry].self, forKey: .history) ?? []
        processedRunIDs = try container.decodeIfPresent([UUID].self, forKey: .processedRunIDs) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(records, forKey: .records)
        try container.encode(pendingCandidates, forKey: .pendingCandidates)
        try container.encode(history, forKey: .history)
        try container.encode(processedRunIDs, forKey: .processedRunIDs)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

// HealthKit 파생 데이터는 백업 제외 저장소에 보관해 심사 리스크를 줄인다.
final class PersonalRecordStore {
    private let snapshotFilename = "personal-records.json"
    let version = 5

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
