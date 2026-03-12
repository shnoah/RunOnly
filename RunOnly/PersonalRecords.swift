import Foundation

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

final class PersonalRecordStore {
    private let userDefaults: UserDefaults
    private let snapshotKey = "RunOnly.personalRecords.snapshot"
    let version = 2

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> PersonalRecordSnapshot {
        guard
            let data = userDefaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(PersonalRecordSnapshot.self, from: data),
            snapshot.version == version
        else {
            return .empty(version: version)
        }

        return snapshot
    }

    func save(_ snapshot: PersonalRecordSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: snapshotKey)
    }
}

func formatPersonalRecordDuration(_ duration: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = [.pad]
    return formatter.string(from: duration) ?? "-"
}
