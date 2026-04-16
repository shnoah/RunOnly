import Foundation

// 문자열 번역과 포맷 치환을 한 줄 호출로 감싸 UI 코드가 길어지지 않게 한다.
enum L10n {
    static func tr(_ key: String) -> String {
        RunDisplayFormatter.localizedString(for: key)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: RunDisplayFormatter.currentAppLocale, arguments: arguments)
    }
}

// 앱 내부 언어 설정은 현재 한국어/영어 두 가지로만 단순하게 관리한다.
enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case korean
    case english

    var id: String { rawValue }

    var label: String {
        switch self {
        case .korean:
            return "한국어"
        case .english:
            return "English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .korean:
            return "ko_KR"
        case .english:
            return "en"
        }
    }
}

// 거리 단위는 시스템 설정을 따르거나 사용자가 강제로 고정할 수 있다.
enum DistanceUnitPreference: String, CaseIterable, Identifiable {
    case system
    case kilometers
    case miles

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return L10n.tr("시스템")
        case .kilometers:
            return "km"
        case .miles:
            return "mi"
        }
    }
}

// 실제 표시 단계에서는 km/mi 둘 중 하나로 확정된 단위만 다루도록 분리한다.
enum DisplayDistanceUnit {
    case kilometers
    case miles

    var distanceSymbol: String {
        switch self {
        case .kilometers:
            return "km"
        case .miles:
            return "mi"
        }
    }

    var paceSymbol: String {
        switch self {
        case .kilometers:
            return "/km"
        case .miles:
            return "/mi"
        }
    }

    var elevationSymbol: String {
        switch self {
        case .kilometers:
            return "m"
        case .miles:
            return "ft"
        }
    }

    var distanceInputSuffix: String {
        switch self {
        case .kilometers:
            return "km"
        case .miles:
            return "mi"
        }
    }
}

// 날짜, 거리, 페이스 같은 모든 표시 문자열을 한곳에서 통일해 화면별 표기 차이를 줄인다.
enum RunDisplayFormatter {
    private static let metersPerKilometer = 1_000.0
    private static let metersPerMile = 1_609.344
    private static let feetPerMeter = 3.28084
    private static let appLanguagePreferenceDefaultsKey = "runonly.settings.appLanguagePreference"
    private static let distanceUnitPreferenceDefaultsKey = "runonly.settings.distanceUnitPreference"

    static var currentAppLanguagePreference: AppLanguagePreference {
        let rawValue = UserDefaults.standard.string(forKey: appLanguagePreferenceDefaultsKey)
        return AppLanguagePreference(rawValue: rawValue ?? "") ?? .korean
    }

    static var currentAppLocale: Locale {
        Locale(identifier: currentAppLanguagePreference.localeIdentifier)
    }

    static var currentDistanceUnitPreference: DistanceUnitPreference {
        let rawValue = UserDefaults.standard.string(forKey: distanceUnitPreferenceDefaultsKey)
        return DistanceUnitPreference(rawValue: rawValue ?? "") ?? .system
    }

    static func locale(for preference: AppLanguagePreference) -> Locale {
        Locale(identifier: preference.localeIdentifier)
    }

    // 영어 선택 시에는 en.lproj를 우선 보고, 없으면 기본 번들을 fallback으로 사용한다.
    static func localizedString(for key: String, preference: AppLanguagePreference = currentAppLanguagePreference) -> String {
        let bundle: Bundle
        switch preference {
        case .korean:
            bundle = Bundle.main
        case .english:
            if
                let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                let localizedBundle = Bundle(path: path)
            {
                bundle = localizedBundle
            } else {
                bundle = Bundle.main
            }
        }

        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    // 시스템 단위를 따를 때는 현재 로케일의 measurement system을 기준으로 km/mi를 결정한다.
    static func resolvedDistanceUnit(
        for preference: DistanceUnitPreference = currentDistanceUnitPreference,
        locale: Locale = .autoupdatingCurrent
    ) -> DisplayDistanceUnit {
        switch preference {
        case .system:
            if locale.measurementSystem == .metric {
                return .kilometers
            }
            return .miles
        case .kilometers:
            return .kilometers
        case .miles:
            return .miles
        }
    }

    // 내부 계산은 km 기준으로 유지하고, 화면에 뿌릴 때만 선택 단위로 바꾼다.
    static func displayedDistanceValue(
        kilometers: Double,
        preference: DistanceUnitPreference = currentDistanceUnitPreference
    ) -> Double {
        let unit = resolvedDistanceUnit(for: preference)
        switch unit {
        case .kilometers:
            return kilometers
        case .miles:
            return kilometers / 1.609344
        }
    }

    // 입력 폼에서 사용자가 본 값은 다시 앱 내부 기준 단위인 km로 되돌려 저장한다.
    static func kilometers(
        fromDisplayedDistance value: Double,
        preference: DistanceUnitPreference = currentDistanceUnitPreference
    ) -> Double {
        let unit = resolvedDistanceUnit(for: preference)
        switch unit {
        case .kilometers:
            return value
        case .miles:
            return value * 1.609344
        }
    }

    static func monthOnly(_ date: Date, locale: Locale = currentAppLocale) -> String {
        date.formatted(
            .dateTime
                .locale(locale)
                .month(.wide)
        )
    }

    // 일반 거리 표기는 "숫자 + 단위" 형태를 모든 화면에서 재사용한다.
    static func distance(
        kilometers: Double,
        preference: DistanceUnitPreference = currentDistanceUnitPreference,
        fractionLength: Int = 1
    ) -> String {
        let unit = resolvedDistanceUnit(for: preference)
        let displayedValue = displayedDistanceValue(kilometers: kilometers, preference: preference)
        return number(displayedValue, fractionLength: fractionLength) + " " + unit.distanceSymbol
    }

    static func distance(
        meters: Double,
        preference: DistanceUnitPreference = currentDistanceUnitPreference,
        fractionLength: Int = 2
    ) -> String {
        distance(kilometers: meters / metersPerKilometer, preference: preference, fractionLength: fractionLength)
    }

    // 스플릿은 정규 1km/1mi 구간일 때 소수점을 줄여 더 빨리 읽히게 만든다.
    static func splitDistance(
        meters: Double,
        preference: DistanceUnitPreference = currentDistanceUnitPreference
    ) -> String {
        let unit = resolvedDistanceUnit(for: preference)
        let fractionLength = unit == .kilometers && abs(meters - metersPerKilometer) < 0.5 ? 0 : 2
        return distance(meters: meters, preference: preference, fractionLength: fractionLength)
    }

    static func axisDistance(
        kilometers: Double,
        preference: DistanceUnitPreference = currentDistanceUnitPreference
    ) -> String {
        let displayedValue = displayedDistanceValue(kilometers: kilometers, preference: preference)
        let hasFraction = abs(displayedValue.rounded() - displayedValue) > 0.001
        let fractionLength = hasFraction ? 2 : 1
        return number(displayedValue, fractionLength: fractionLength)
    }

    // 평균 페이스는 먼저 sec/km로 계산한 뒤, 필요하면 sec/mi로 변환한다.
    static func pace(
        duration: TimeInterval,
        distanceMeters: Double,
        preference: DistanceUnitPreference = currentDistanceUnitPreference
    ) -> String {
        guard distanceMeters > 0 else { return "-" }
        let secondsPerKilometer = duration / max(distanceMeters / metersPerKilometer, 0.001)
        return pace(secondsPerKilometer: secondsPerKilometer, preference: preference)
    }

    static func pace(
        secondsPerKilometer: Double,
        preference: DistanceUnitPreference = currentDistanceUnitPreference
    ) -> String {
        let unit = resolvedDistanceUnit(for: preference)
        let secondsPerUnit: Double
        switch unit {
        case .kilometers:
            secondsPerUnit = secondsPerKilometer
        case .miles:
            secondsPerUnit = secondsPerKilometer * 1.609344
        }

        return duration(secondsPerUnit) + unit.paceSymbol
    }

    // 1시간 이상이면 시:분:초, 아니면 분:초만 쓰도록 해 러닝 기록 표기가 간결하게 유지된다.
    static func duration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: seconds) ?? "-"
    }

    static func signedDuration(_ seconds: TimeInterval) -> String {
        let sign = seconds > 0 ? "+" : seconds < 0 ? "-" : ""
        return sign + duration(abs(seconds))
    }

    static func heartRate(_ bpm: Double?) -> String? {
        guard let bpm else { return nil }
        return number(bpm, fractionLength: 0) + " bpm"
    }

    static func cadence(_ spm: Double?) -> String? {
        guard let spm else { return nil }
        return number(spm, fractionLength: 0) + " spm"
    }

    static func elevation(_ meters: Double?) -> String? {
        guard let meters else { return nil }
        let unit = resolvedDistanceUnit()
        let displayedValue: Double
        switch unit {
        case .kilometers:
            displayedValue = meters
        case .miles:
            displayedValue = meters * feetPerMeter
        }
        return number(displayedValue, fractionLength: 0) + " " + unit.elevationSymbol
    }

    // 리스트/상세/공유 화면은 각각 보는 맥락이 달라 날짜 포맷도 따로 둔다.
    static func recordDate(_ date: Date, locale: Locale = currentAppLocale) -> String {
        localizedDate(date, locale: locale, template: "M d E a h:mm")
    }

    static func recordCompactDate(_ date: Date, locale: Locale = currentAppLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .current
        formatter.dateFormat = "M/d E a h:mm"
        return formatter.string(from: date)
    }

    static func detailDate(_ date: Date, locale: Locale = currentAppLocale) -> String {
        localizedDate(date, locale: locale, template: "y M d E a h:mm")
    }

    static func shareDate(_ date: Date, locale: Locale = currentAppLocale) -> String {
        localizedDate(date, locale: locale, template: "y M d HH:mm")
    }

    static func monthLabel(_ date: Date, locale: Locale = currentAppLocale) -> String {
        date.formatted(
            .dateTime
                .locale(locale)
                .year()
                .month(.wide)
        )
    }

    static func dayLabel(_ date: Date, locale: Locale = currentAppLocale) -> String {
        date.formatted(
            .dateTime
                .locale(locale)
                .month(.wide)
                .day()
                .weekday(.abbreviated)
        )
    }

    static func shortMonthDay(_ date: Date, locale: Locale = currentAppLocale) -> String {
        date.formatted(
            .dateTime
                .locale(locale)
                .month(.wide)
                .day()
        )
    }

    private static func number(_ value: Double, fractionLength: Int) -> String {
        value.formatted(
            .number
                .locale(currentAppLocale)
                .precision(.fractionLength(fractionLength))
        )
    }

    // DateFormatter 생성을 한곳에 모아 지역화 규칙이 바뀌어도 수정 지점을 줄인다.
    private static func localizedDate(_ date: Date, locale: Locale, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
