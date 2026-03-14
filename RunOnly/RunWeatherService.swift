import Foundation

// 공유 이미지에는 러닝 시각에 가장 가까운 온도와 상태 한 줄이면 충분하다.
struct RunWeatherSnapshot: Equatable {
    let observationDate: Date
    let temperatureCelsius: Double
    let weatherCode: Int

    var shareText: String {
        "\(temperatureText) \(conditionText)"
    }

    var temperatureText: String {
        "\(Int(temperatureCelsius.rounded()))°C"
    }

    var conditionText: String {
        switch weatherCode {
        case 0:
            return "맑음"
        case 1:
            return "대체로 맑음"
        case 2:
            return "구름 조금"
        case 3:
            return "흐림"
        case 45, 48:
            return "안개"
        case 51, 53, 55, 56, 57:
            return "이슬비"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "비"
        case 71, 73, 75, 77, 85, 86:
            return "눈"
        case 95, 96, 99:
            return "뇌우"
        default:
            return "날씨"
        }
    }
}

enum RunWeatherServiceError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case missingHourlyData

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "날씨 요청을 만들지 못했습니다."
        case .invalidResponse:
            return "날씨 응답을 읽지 못했습니다."
        case .missingHourlyData:
            return "러닝 시간에 맞는 날씨 데이터가 없습니다."
        }
    }
}

// Open-Meteo archive API에서 러닝 시각과 가장 가까운 시간대 날씨를 가져온다.
actor RunWeatherService {
    static let shared = RunWeatherService()

    private var cache: [CacheKey: RunWeatherSnapshot] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWeather(
        latitude: Double,
        longitude: Double,
        referenceDate: Date
    ) async throws -> RunWeatherSnapshot {
        let cacheKey = CacheKey(latitude: latitude, longitude: longitude, referenceDate: referenceDate)
        if let cached = cache[cacheKey] {
            return cached
        }

        let request = try makeRequest(latitude: latitude, longitude: longitude, referenceDate: referenceDate)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw RunWeatherServiceError.invalidResponse
        }

        let payload = try JSONDecoder().decode(OpenMeteoArchiveResponse.self, from: data)
        guard let snapshot = payload.closestSnapshot(to: referenceDate) else {
            throw RunWeatherServiceError.missingHourlyData
        }

        cache[cacheKey] = snapshot
        return snapshot
    }

    private func makeRequest(
        latitude: Double,
        longitude: Double,
        referenceDate: Date
    ) throws -> URLRequest {
        guard var components = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive") else {
            throw RunWeatherServiceError.invalidRequest
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let startCandidate = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        let endCandidate = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        let today = Date()
        let endDate = min(endCandidate, today)
        let startDate = min(startCandidate, endDate)

        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "start_date", value: Self.requestDateFormatter.string(from: startDate)),
            URLQueryItem(name: "end_date", value: Self.requestDateFormatter.string(from: endDate)),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "timezone", value: "GMT")
        ]

        guard let url = components.url else {
            throw RunWeatherServiceError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("RunOnly/0.1", forHTTPHeaderField: "User-Agent")
        return request
    }

    private static let requestDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let hourlyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()

    private struct CacheKey: Hashable {
        let latitudeBucket: Int
        let longitudeBucket: Int
        let hourBucket: Int

        init(latitude: Double, longitude: Double, referenceDate: Date) {
            latitudeBucket = Int((latitude * 1_000).rounded())
            longitudeBucket = Int((longitude * 1_000).rounded())
            hourBucket = Int(referenceDate.timeIntervalSince1970 / 3_600)
        }
    }

    private struct OpenMeteoArchiveResponse: Decodable {
        let hourly: Hourly

        struct Hourly: Decodable {
            let time: [String]
            let temperature2m: [Double]
            let weatherCode: [Int]

            enum CodingKeys: String, CodingKey {
                case time
                case temperature2m = "temperature_2m"
                case weatherCode = "weather_code"
            }
        }

        func closestSnapshot(to referenceDate: Date) -> RunWeatherSnapshot? {
            let entries = zip(zip(hourly.time, hourly.temperature2m), hourly.weatherCode)
            let snapshots = entries.compactMap { item -> RunWeatherSnapshot? in
                let ((time, temperature), weatherCode) = item
                guard let date = RunWeatherService.hourlyDateFormatter.date(from: time) else {
                    return nil
                }
                return RunWeatherSnapshot(
                    observationDate: date,
                    temperatureCelsius: temperature,
                    weatherCode: weatherCode
                )
            }

            return snapshots.min {
                abs($0.observationDate.timeIntervalSince(referenceDate)) <
                    abs($1.observationDate.timeIntervalSince(referenceDate))
            }
        }
    }
}
