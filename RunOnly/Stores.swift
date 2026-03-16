import SwiftUI

@MainActor
final class ShoeStore: ObservableObject {
    @Published private(set) var shoes: [RunningShoe] = []
    @Published private(set) var assignments: [ShoeAssignmentRecord] = []

    private let storageFilename = "shoe-store.json"

    init() {
        load()
    }

    func addShoe(_ shoe: RunningShoe) {
        shoes.insert(shoe, at: 0)
        save()
    }

    func updateShoe(_ shoe: RunningShoe) {
        guard let index = shoes.firstIndex(where: { $0.id == shoe.id }) else { return }
        shoes[index] = shoe
        save()
    }

    func shoe(for runID: UUID) -> RunningShoe? {
        guard let shoeID = assignments.first(where: { $0.runID == runID })?.shoeID else { return nil }
        return shoes.first(where: { $0.id == shoeID })
    }

    func assign(_ shoeID: UUID?, to runID: UUID) {
        assignments.removeAll { $0.runID == runID }
        if let shoeID {
            assignments.append(ShoeAssignmentRecord(runID: runID, shoeID: shoeID))
        }
        save()
    }

    func clearAllData() {
        shoes = []
        assignments = []
        save()
    }

    func distance(for shoeID: UUID, runs allRuns: [RunningWorkout]) -> Double {
        runs(for: shoeID, in: allRuns).reduce(0) { $0 + $1.distanceInKilometers }
    }

    func runCount(for shoeID: UUID) -> Int {
        assignments.filter { $0.shoeID == shoeID }.count
    }

    func runs(for shoeID: UUID, in runs: [RunningWorkout]) -> [RunningWorkout] {
        let runIDs = assignments.filter { $0.shoeID == shoeID }.map(\.runID)
        return runs.filter { runIDs.contains($0.id) }.sorted(by: { $0.startDate > $1.startDate })
    }

    func exportBackupFile() throws -> URL {
        let payload = ShoeBackupPayload(
            schemaVersion: ShoeBackupPayload.currentSchemaVersion,
            exportedAt: .now,
            appVersion: AppMetadata.versionText,
            assignmentReference: "healthkit_workout_uuid",
            shoes: shoes,
            assignments: assignments
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(payload)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let filename = "RunOnly-ShoeBackup-\(formatter.string(from: .now)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    func importBackupFile(from url: URL, strategy: ShoeImportStrategy) throws -> ShoeImportSummary {
        let didAccessSecurityScopedResource = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload: ShoeBackupPayload
        if let decoded = try? decoder.decode(ShoeBackupPayload.self, from: data) {
            payload = decoded
        } else if let legacyPayload = try? decoder.decode(LegacyShoeBackupPayload.self, from: data) {
            payload = ShoeBackupPayload(
                schemaVersion: 0,
                exportedAt: legacyPayload.exportedAt,
                appVersion: "legacy",
                assignmentReference: "healthkit_workout_uuid",
                shoes: legacyPayload.shoes,
                assignments: legacyPayload.assignments
            )
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard payload.schemaVersion <= ShoeBackupPayload.currentSchemaVersion else {
            throw ShoeBackupError.unsupportedSchemaVersion(payload.schemaVersion)
        }

        let importedShoes = deduplicatedShoes(payload.shoes)
        guard !importedShoes.isEmpty else {
            throw ShoeBackupError.emptyBackup
        }

        let validShoeIDs = Set(importedShoes.map(\.id))
        let importedAssignments = deduplicatedAssignments(
            payload.assignments.filter { validShoeIDs.contains($0.shoeID) }
        )

        switch strategy {
        case .replace:
            shoes = importedShoes
            assignments = importedAssignments
        case .merge:
            var shoeMap = Dictionary(uniqueKeysWithValues: shoes.map { ($0.id, $0) })
            for shoe in importedShoes {
                shoeMap[shoe.id] = shoe
            }

            var assignmentMap = Dictionary(uniqueKeysWithValues: assignments.map { ($0.runID, $0) })
            for assignment in importedAssignments {
                assignmentMap[assignment.runID] = assignment
            }

            let mergedShoes = deduplicatedShoes(Array(shoeMap.values))
            let mergedShoeIDs = Set(mergedShoes.map(\.id))
            shoes = mergedShoes
            assignments = deduplicatedAssignments(
                Array(assignmentMap.values).filter { mergedShoeIDs.contains($0.shoeID) }
            )
        }

        save()
        return ShoeImportSummary(
            strategy: strategy,
            shoeCount: importedShoes.count,
            assignmentCount: importedAssignments.count
        )
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let snapshot = try? AppStorage.load(ShoeStoreSnapshot.self, from: storageFilename, decoder: decoder) else {
            shoes = []
            assignments = []
            return
        }

        shoes = snapshot.shoes
        assignments = snapshot.assignments
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let snapshot = ShoeStoreSnapshot(shoes: shoes, assignments: assignments)
        try? AppStorage.save(snapshot, to: storageFilename, encoder: encoder)
    }

    private func deduplicatedShoes(_ shoes: [RunningShoe]) -> [RunningShoe] {
        let unique = Dictionary(uniqueKeysWithValues: shoes.map { ($0.id, $0) })
        return unique.values.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.displayName < rhs.displayName
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func deduplicatedAssignments(_ assignments: [ShoeAssignmentRecord]) -> [ShoeAssignmentRecord] {
        let unique = Dictionary(uniqueKeysWithValues: assignments.map { ($0.runID, $0) })
        return Array(unique.values).sorted { $0.runID.uuidString < $1.runID.uuidString }
    }
}

private struct ShoeBackupPayload: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let appVersion: String
    let assignmentReference: String
    let shoes: [RunningShoe]
    let assignments: [ShoeAssignmentRecord]
}

private struct LegacyShoeBackupPayload: Codable {
    let exportedAt: Date
    let shoes: [RunningShoe]
    let assignments: [ShoeAssignmentRecord]
}

enum ShoeImportStrategy {
    case merge
    case replace
}

struct ShoeImportSummary {
    let strategy: ShoeImportStrategy
    let shoeCount: Int
    let assignmentCount: Int

    var message: String {
        switch strategy {
        case .merge:
            return "신발 \(shoeCount)개와 연결 \(assignmentCount)건을 병합했습니다."
        case .replace:
            return "신발 \(shoeCount)개와 연결 \(assignmentCount)건으로 교체했습니다."
        }
    }
}

private enum ShoeBackupError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case emptyBackup

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "이 백업 파일은 더 새로운 형식(v\(version))이라 현재 앱에서 가져올 수 없습니다."
        case .emptyBackup:
            return "가져올 신발 데이터가 없습니다."
        }
    }
}

private struct ShoeStoreSnapshot: Codable {
    let shoes: [RunningShoe]
    let assignments: [ShoeAssignmentRecord]
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var defaultAppleOnlyFilter: Bool {
        didSet {
            UserDefaults.standard.set(defaultAppleOnlyFilter, forKey: defaultAppleOnlyFilterKey)
        }
    }

    private let defaultAppleOnlyFilterKey = "runonly.settings.defaultAppleOnlyFilter"

    init() {
        if UserDefaults.standard.object(forKey: defaultAppleOnlyFilterKey) == nil {
            UserDefaults.standard.set(true, forKey: defaultAppleOnlyFilterKey)
        }
        self.defaultAppleOnlyFilter = UserDefaults.standard.bool(forKey: defaultAppleOnlyFilterKey)
    }
}

@MainActor
final class MileageGoalStore: ObservableObject {
    @Published var monthlyGoalKilometers: Double {
        didSet {
            UserDefaults.standard.set(monthlyGoalKilometers, forKey: monthlyGoalKilometersKey)
        }
    }

    private let monthlyGoalKilometersKey = "runonly.goals.monthlyKilometers"

    init() {
        let storedValue = UserDefaults.standard.double(forKey: monthlyGoalKilometersKey)
        if storedValue <= 0 {
            UserDefaults.standard.set(60.0, forKey: monthlyGoalKilometersKey)
        }
        self.monthlyGoalKilometers = UserDefaults.standard.double(forKey: monthlyGoalKilometersKey)
    }
}
