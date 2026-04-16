import SwiftUI

// 러닝 리스트에서는 신발이 연결됐는지 여부까지 같이 표시해야 해서 별도 표시 모델로 둔다.
struct RunShoeAssignmentDisplay: Equatable {
    let name: String
    let isAssigned: Bool

    static var unassigned: Self {
        Self(name: L10n.tr("신발 미선택"), isAssigned: false)
    }
}

// 신발 목록, 러닝 연결, 백업/복원까지 신발 관련 로컬 상태를 한곳에서 관리한다.
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

    // 새 신발은 최근 생성 순으로 보이게 앞쪽에 넣는다.
    func addShoe(_ shoe: RunningShoe) {
        shoes.insert(shoe, at: 0)
        rebuildLookups()
        save()
    }

    // 수정 후에는 lookup 캐시도 함께 다시 만들어 화면 조회 비용을 줄인다.
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

    // 한 러닝에는 신발 하나만 연결되도록 기존 연결을 먼저 비운 뒤 다시 기록한다.
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

    // 백업에는 앱이 계산 가능한 로컬 신발 데이터만 담고 HealthKit 원본은 넣지 않는다.
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

    // 가져오기는 최신 포맷과 예전 포맷 둘 다 받아 기존 사용자 데이터 복구를 돕는다.
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
            // 교체는 백업 파일 내용을 현재 로컬 상태로 그대로 덮어쓴다.
            shoes = importedShoes
            assignments = importedAssignments
        case .merge:
            // 병합은 동일 ID만 덮어쓰고 나머지는 유지해 여러 기기 데이터를 합칠 때 쓴다.
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

    // 앱 시작 시 저장된 스냅샷을 읽고 메모리 lookup 캐시까지 함께 복원한다.
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

    // 화면은 Published 배열을 보고, 조회는 dictionary 캐시를 보는 구조라 둘을 같이 저장한다.
    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let snapshot = ShoeStoreSnapshot(shoes: shoes, assignments: assignments)
        try? AppStorage.save(snapshot, to: storageFilename, encoder: encoder)
    }

    // runID -> shoe, shoeID -> shoe lookup을 미리 만들어 목록 렌더링 중 반복 탐색을 줄인다.
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

// 최신 백업 포맷은 버전과 참조 기준을 포함해 이후 포맷 확장에 대비한다.
private struct ShoeBackupPayload: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let appVersion: String
    let assignmentReference: String
    let shoes: [RunningShoe]
    let assignments: [ShoeAssignmentRecord]
}

// 예전 단순 백업 JSON도 복원할 수 있게 별도 디코더 모델을 남겨둔다.
private struct LegacyShoeBackupPayload: Codable {
    let exportedAt: Date
    let shoes: [RunningShoe]
    let assignments: [ShoeAssignmentRecord]
}

// 사용자는 병합/교체 두 흐름 중 하나만 고르면 되게 단순화했다.
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

// 백업 포맷 오류는 파일 손상과 버전 불일치 정도만 명확히 안내한다.
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

// 신발 저장소는 배열 스냅샷 형태로만 저장해 디버깅과 마이그레이션을 단순하게 유지한다.
private struct ShoeStoreSnapshot: Codable {
    let shoes: [RunningShoe]
    let assignments: [ShoeAssignmentRecord]
}

// 앱 설정은 전부 UserDefaults 기반이라 앱 재실행 후에도 바로 복원된다.
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
        // 기존 사용자에게는 갑작스러운 온보딩 재노출이 생기지 않도록 초기값을 분기한다.
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

    // 설정 탭에서 권한 소개를 다시 열 수 있게 별도 presentation 상태를 둔다.
    func presentHealthKitIntro() {
        isPresentingHealthKitIntro = true
    }

    func completeHealthKitIntro() {
        hasCompletedHealthKitIntro = true
        isPresentingHealthKitIntro = false
    }
}

// 월간 목표 거리는 아주 가벼운 단일 숫자 상태라 별도 파일 없이 defaults만 사용한다.
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

// 상세 화면 상단 요약 캐시는 버전형 스냅샷으로 저장해 이후 구조 변경에 대비한다.
private struct RunSummaryCacheSnapshot: Codable {
    let version: Int
    let entries: [RunSummaryCacheEntry]
}

private struct RunSummaryCacheEntry: Codable {
    let runID: UUID
    let metrics: RunSummaryMetrics
    let cachedAt: Date
}

// 상세를 다시 열 때 평균 심박/케이던스 같은 요약값을 즉시 보여주기 위한 로컬 캐시다.
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

    // 값이 하나도 없으면 저장하지 않아 빈 캐시 엔트리가 쌓이지 않게 한다.
    func save(_ metrics: RunSummaryMetrics, for runID: UUID) {
        guard metrics.hasAnyValue else { return }
        metricsByRunID[runID] = metrics
        persist()
    }

    func clearAllData() {
        metricsByRunID = [:]
        persist()
    }

    // 캐시 파일이 없거나 버전이 다르면 과감히 버리고 다시 채우는 쪽이 안전하다.
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

    // 저장 시에는 dictionary를 배열로 펼쳐 JSON 순서를 안정적으로 맞춘다.
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
