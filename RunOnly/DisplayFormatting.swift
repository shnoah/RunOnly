import Foundation

enum L10n {
    static func tr(_ key: String) -> String {
        RunDisplayFormatter.localizedString(for: key)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: RunDisplayFormatter.currentAppLocale, arguments: arguments)
    }
}

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

    static func recordDate(_ date: Date, locale: Locale = currentAppLocale) -> String {
        localizedDate(date, locale: locale, template: "M d E a h:mm")
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

    private static func localizedDate(_ date: Date, locale: Locale, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
