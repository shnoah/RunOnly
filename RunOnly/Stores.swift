import SwiftUI

struct RunShoeAssignmentDisplay: Equatable {
    let name: String
    let isAssigned: Bool

    static var unassigned: Self {
        Self(name: L10n.tr("신발 미선택"), isAssigned: false)
    }
}

@MainActor
final class ShoeStore: ObservableObject {
    @Published private(set) var shoes: [RunningShoe] = []
    @Published private(set) var assignments: [ShoeAssignmentRecord] = []

    private let storageFilename = "shoe-store.json"
    private var shoesByID: [UUID: RunningShoe] = [:]
    private var shoeByRunID: [UUID: RunningShoe] = [:]

    init() {
        load()
    }

    func addShoe(_ shoe: RunningShoe) {
        shoes.insert(shoe, at: 0)
        rebuildLookups()
        save()
    }

    func updateShoe(_ shoe: RunningShoe) {
        guard let index = shoes.firstIndex(where: { $0.id == shoe.id }) else { return }
        shoes[index] = shoe
        rebuildLookups()
        save()
    }

    func shoe(for runID: UUID) -> RunningShoe? {
        shoeByRunID[runID]
    }

    func shoeAssignmentDisplay(for runID: UUID) -> RunShoeAssignmentDisplay {
        guard let shoe = shoeByRunID[runID] else {
            return .unassigned
        }
        return RunShoeAssignmentDisplay(name: shoe.displayName, isAssigned: true)
    }

    func assign(_ shoeID: UUID?, to runID: UUID) {
        assignments.removeAll { $0.runID == runID }
        if let shoeID {
            assignments.append(ShoeAssignmentRecord(runID: runID, shoeID: shoeID))
        }
        rebuildLookups()
        save()
    }

    func clearAllData() {
        shoes = []
        assignments = []
        rebuildLookups()
        save()
    }

    func distance(for shoeID: UUID, runs allRuns: [RunningWorkout]) -> Double {
        runs(for: shoeID, in: allRuns).reduce(0) { $0 + $1.distanceInKilometers }
    }

    func runCount(for shoeID: UUID) -> Int {
        assignments.filter { $0.shoeID == shoeID }.count
    }

    func runs(for shoeID: UUID, in runs: [RunningWorkout]) -> [RunningWorkout] {
        let runIDs = Set(assignments.filter { $0.shoeID == shoeID }.map(\.runID))
        guard !runIDs.isEmpty else { return [] }
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

        rebuildLookups()
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
            rebuildLookups()
            return
        }

        shoes = snapshot.shoes
        assignments = snapshot.assignments
        rebuildLookups()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let snapshot = ShoeStoreSnapshot(shoes: shoes, assignments: assignments)
        try? AppStorage.save(snapshot, to: storageFilename, encoder: encoder)
    }

    private func rebuildLookups() {
        shoesByID = Dictionary(uniqueKeysWithValues: shoes.map { ($0.id, $0) })
        shoeByRunID = assignments.reduce(into: [:]) { partial, assignment in
            guard let shoe = shoesByID[assignment.shoeID] else { return }
            partial[assignment.runID] = shoe
        }
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
            return L10n.format("신발 %d개와 연결 %d건을 병합했습니다.", shoeCount, assignmentCount)
        case .replace:
            return L10n.format("신발 %d개와 연결 %d건으로 교체했습니다.", shoeCount, assignmentCount)
        }
    }
}

private enum ShoeBackupError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case emptyBackup

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return L10n.format("이 백업 파일은 더 새로운 형식(v%d)이라 현재 앱에서 가져올 수 없습니다.", version)
        case .emptyBackup:
            return L10n.tr("가져올 신발 데이터가 없습니다.")
        }
    }
}

private struct ShoeStoreSnapshot: Codable {
    let shoes: [RunningShoe]
    let assignments: [ShoeAssignmentRecord]
}

@MainActor
final class AppSettingsStore: ObservableObject {
    static let defaultAppleOnlyFilterKey = "runonly.settings.defaultAppleOnlyFilter"
    static let hasCompletedHealthKitIntroKey = "runonly.settings.hasCompletedHealthKitIntro"
    static let appLanguagePreferenceKey = "runonly.settings.appLanguagePreference"
    static let distanceUnitPreferenceKey = "runonly.settings.distanceUnitPreference"

    @Published var defaultAppleOnlyFilter: Bool {
        didSet {
            UserDefaults.standard.set(defaultAppleOnlyFilter, forKey: Self.defaultAppleOnlyFilterKey)
        }
    }

    @Published var hasCompletedHealthKitIntro: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedHealthKitIntro, forKey: Self.hasCompletedHealthKitIntroKey)
        }
    }

    @Published var isPresentingHealthKitIntro = false

    @Published var appLanguagePreference: AppLanguagePreference {
        didSet {
            UserDefaults.standard.set(appLanguagePreference.rawValue, forKey: Self.appLanguagePreferenceKey)
        }
    }

    @Published var distanceUnitPreference: DistanceUnitPreference {
        didSet {
            UserDefaults.standard.set(distanceUnitPreference.rawValue, forKey: Self.distanceUnitPreferenceKey)
        }
    }

    var appLocale: Locale {
        RunDisplayFormatter.locale(for: appLanguagePreference)
    }

    init() {
        let hadExistingDefaultAppleOnlySetting = UserDefaults.standard.object(forKey: Self.defaultAppleOnlyFilterKey) != nil
        if UserDefaults.standard.object(forKey: Self.defaultAppleOnlyFilterKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.defaultAppleOnlyFilterKey)
        }
        if UserDefaults.standard.object(forKey: Self.hasCompletedHealthKitIntroKey) == nil {
            UserDefaults.standard.set(hadExistingDefaultAppleOnlySetting, forKey: Self.hasCompletedHealthKitIntroKey)
        }
        if UserDefaults.standard.object(forKey: Self.appLanguagePreferenceKey) == nil {
            UserDefaults.standard.set(AppLanguagePreference.korean.rawValue, forKey: Self.appLanguagePreferenceKey)
        }
        if UserDefaults.standard.object(forKey: Self.distanceUnitPreferenceKey) == nil {
            UserDefaults.standard.set(DistanceUnitPreference.system.rawValue, forKey: Self.distanceUnitPreferenceKey)
        }
        self.defaultAppleOnlyFilter = UserDefaults.standard.bool(forKey: Self.defaultAppleOnlyFilterKey)
        self.hasCompletedHealthKitIntro = UserDefaults.standard.bool(forKey: Self.hasCompletedHealthKitIntroKey)
        self.appLanguagePreference = AppLanguagePreference(
            rawValue: UserDefaults.standard.string(forKey: Self.appLanguagePreferenceKey) ?? ""
        ) ?? .korean
        self.distanceUnitPreference = DistanceUnitPreference(
            rawValue: UserDefaults.standard.string(forKey: Self.distanceUnitPreferenceKey) ?? ""
        ) ?? .system
    }

    func presentHealthKitIntro() {
        isPresentingHealthKitIntro = true
    }

    func completeHealthKitIntro() {
        hasCompletedHealthKitIntro = true
        isPresentingHealthKitIntro = false
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

private struct RunSummaryCacheSnapshot: Codable {
    let version: Int
    let entries: [RunSummaryCacheEntry]
}

private struct RunSummaryCacheEntry: Codable {
    let runID: UUID
    let metrics: RunSummaryMetrics
    let cachedAt: Date
}

@MainActor
final class RunSummaryCacheStore {
    static let shared = RunSummaryCacheStore()

    private let storageFilename = "run-summary-cache.json"
    private let version = 1
    private var metricsByRunID: [UUID: RunSummaryMetrics] = [:]

    private init() {
        load()
    }

    func summary(for runID: UUID) -> RunSummaryMetrics? {
        metricsByRunID[runID]
    }

    func save(_ metrics: RunSummaryMetrics, for runID: UUID) {
        guard metrics.hasAnyValue else { return }
        metricsByRunID[runID] = metrics
        persist()
    }

    func clearAllData() {
        metricsByRunID = [:]
        persist()
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard
            let snapshot = try? AppStorage.load(RunSummaryCacheSnapshot.self, from: storageFilename, decoder: decoder),
            snapshot.version == version
        else {
            metricsByRunID = [:]
            return
        }

        metricsByRunID = Dictionary(uniqueKeysWithValues: snapshot.entries.map { ($0.runID, $0.metrics) })
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let entries = metricsByRunID
            .map { RunSummaryCacheEntry(runID: $0.key, metrics: $0.value, cachedAt: .now) }
            .sorted { $0.runID.uuidString < $1.runID.uuidString }
        let snapshot = RunSummaryCacheSnapshot(version: version, entries: entries)
        try? AppStorage.save(snapshot, to: storageFilename, encoder: encoder)
    }
}
