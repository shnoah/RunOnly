import Foundation
import SwiftUI

// 앱 전역에서 반복해서 쓰는 메타데이터와 외부 연락처를 한곳에서 관리한다.
enum AppMetadata {
    static let supportEmail = "shnoah@gmail.com"
    static let repositoryURL = URL(string: "https://github.com/shnoah/RunOnly")!
    static let privacyPolicyURL = URL(string: "https://github.com/shnoah/RunOnly/blob/main/APP_STORE/PRIVACY_POLICY.md")!

    static var healthPermissionSettingsPath: String {
        L10n.tr("설정 > 건강 > 데이터 접근 및 기기 > RunOnly")
    }

    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "RunOnly"
    }

    static var versionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(displayName) \(shortVersion) (\(buildNumber))"
    }

    static var supportMailURL: URL {
        let subject = L10n.format("%@ 문의", displayName)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(displayName)%20문의"
        return URL(string: "mailto:\(supportEmail)?subject=\(subject)")!
    }

    static var healthDataSummaryItems: [String] {
        [
            L10n.tr("러닝 workout"),
            L10n.tr("러닝 경로"),
            L10n.tr("심박"),
            L10n.tr("안정시 심박"),
            L10n.tr("VO2 Max"),
            L10n.tr("거리 및 걸음 수")
        ]
    }

    static var healthUsageSummary: String {
        L10n.tr("Apple 건강의 러닝 기록, 경로, 심박, VO2 Max 같은 데이터를 iPhone 안에서 보기 쉽게 정리합니다.")
    }

    static var onboardingFeatureHighlights: [String] {
        [
            L10n.tr("• 거리, 시간, 평균 페이스, 심박, 케이던스, 상승 고도를 한눈에 정리합니다."),
            L10n.tr("• 경로, 차트, 스플릿, PR, 신발 기록을 러너 기준으로 다시 묶어 보여줍니다.")
        ]
    }

    static var privacyStorageHighlights: [String] {
        [
            L10n.tr("• Apple 건강에서 읽은 원본 러닝 데이터는 앱 서버로 복제하지 않습니다."),
            L10n.tr("• 평균 심박, 평균 케이던스, 상승 고도 같은 파생 요약값만 기기 내부 저장소에 캐시합니다."),
            L10n.tr("• 로컬 보조 데이터는 자동 iCloud/Finder 백업 대상에서 제외됩니다."),
            L10n.tr("• 현재 서버 업로드, 광고 추적, 외부 분석 SDK는 없습니다.")
        ]
    }

    static var nonMedicalNoticeLines: [String] {
        [
            L10n.tr("VO2 Max, 예상 기록, 러닝 준비도는 참고용 추정치이며 실제 경기력과 다를 수 있습니다."),
            L10n.tr("이 앱은 러닝 기록을 보기 쉽게 정리하는 용도이며, 의료적 판단이나 진단을 위한 앱이 아닙니다.")
        ]
    }

    static var homeIntroSummary: String {
        L10n.tr("애플워치 러닝 기록을 한눈에 정리해 보여주는 앱입니다.")
    }

    static var homeIntroDetails: [String] {
        [
            L10n.tr("• 거리, 시간, 평균 페이스, 심박, 케이던스, 상승 고도를 한눈에 정리합니다."),
            L10n.tr("• 경로, 차트, 스플릿, PR, 신발 기록을 러너 기준으로 다시 묶어 보여줍니다."),
            L10n.tr("VO2 Max, 예상 기록, 러닝 준비도는 참고용 추정치이며 실제 경기력과 다를 수 있습니다.")
        ]
    }
}

// HealthKit 파생 데이터를 포함한 로컬 파일을 앱 내부 저장소에 보관하고 백업 대상에서 제외한다.
enum AppStorage {
    static func fileURL(filename: String) throws -> URL {
        let fileManager = FileManager.default
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = applicationSupportURL.appendingPathComponent("RunOnly", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }

        try excludeFromBackup(directoryURL)
        return directoryURL.appendingPathComponent(filename)
    }

    static func save<Value: Encodable>(
        _ value: Value,
        to filename: String,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        let fileURL = try fileURL(filename: filename)
        let data = try encoder.encode(value)
        try data.write(to: fileURL, options: .atomic)
        try excludeFromBackup(fileURL)
    }

    static func load<Value: Decodable>(
        _ type: Value.Type,
        from filename: String,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> Value {
        let fileURL = try fileURL(filename: filename)
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(type, from: data)
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(resourceValues)
    }
}

// 앱의 진입점은 탭 기반 메인 화면 하나만 띄우도록 단순하게 유지한다.
@main
struct RunOnlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
