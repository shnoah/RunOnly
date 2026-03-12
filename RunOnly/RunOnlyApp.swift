import Foundation
import SwiftUI

// 앱 전역에서 반복해서 쓰는 메타데이터와 외부 연락처를 한곳에서 관리한다.
enum AppMetadata {
    static let supportEmail = "shnoah@gmail.com"
    static let repositoryURL = URL(string: "https://github.com/shnoah/RunOnly")!

    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "RunOnly"
    }

    static var versionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(displayName) \(shortVersion) (\(buildNumber))"
    }

    static var supportMailURL: URL {
        let subject = "\(displayName) 문의".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(displayName)%20문의"
        return URL(string: "mailto:\(supportEmail)?subject=\(subject)")!
    }

    static let healthDataSummaryItems = [
        "러닝 workout",
        "러닝 경로",
        "심박",
        "안정시 심박",
        "VO2 Max",
        "거리 및 걸음 수",
        "러닝 파워 / 속도 / 보폭 / 수직진폭 / 지면접촉시간"
    ]
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
