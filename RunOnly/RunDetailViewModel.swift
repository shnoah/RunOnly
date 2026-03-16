import Foundation

// 상세 화면은 한 번 선택한 러닝의 HealthKit 데이터를 비동기로 읽어 상태를 관리한다.
@MainActor
final class RunDetailViewModel: ObservableObject {
    // 화면에서 필요한 최소 상태만 노출해 View 분기를 단순하게 유지한다.
    enum State {
        case idle
        case loading
        case loaded(RunDetail)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var isLoadingSupplementary = false

    private let healthKitService = HealthKitService()
    private let run: RunningWorkout
    private var loadGeneration = 0

    init(run: RunningWorkout) {
        self.run = run
    }

    // 화면이 처음 나타났을 때만 실제 상세 데이터를 요청한다.
    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    // HealthKit 조회 결과를 그대로 상태에 반영한다.
    func load() async {
        loadGeneration += 1
        let currentGeneration = loadGeneration
        state = .loading
        isLoadingSupplementary = false

        do {
            let detail = try await healthKitService.fetchRunDetail(for: run)
            guard currentGeneration == loadGeneration else { return }
            state = .loaded(detail)
            await loadSupplementary(for: detail, generation: currentGeneration)
        } catch {
            guard currentGeneration == loadGeneration else { return }
            state = .failed(error.localizedDescription)
            isLoadingSupplementary = false
        }
    }

    enum DebugScenario {
        case live
        case completeMetrics
        case pausedWorkout
        case missingRoute
        case missingHeartRate
        case missingAdvancedMetrics
        case empty
    }

    // 개발 중에는 실데이터 없이도 다양한 상세 화면 레이아웃을 점검할 수 있다.
    func applyDebugScenario(_ scenario: DebugScenario) async {
        loadGeneration += 1
        isLoadingSupplementary = false

        switch scenario {
        case .live:
            await load()
        case .completeMetrics:
            state = .loaded(.mockCompleteMetrics)
        case .pausedWorkout:
            state = .loaded(.mockPausedWorkout)
        case .missingRoute:
            state = .loaded(.mockMissingRoute)
        case .missingHeartRate:
            state = .loaded(.mockMissingHeartRate)
        case .missingAdvancedMetrics:
            state = .loaded(.mockMissingAdvancedMetrics)
        case .empty:
            state = .loaded(.empty)
        }
    }

    private func loadSupplementary(for detail: RunDetail, generation: Int) async {
        isLoadingSupplementary = true
        defer {
            if generation == loadGeneration {
                isLoadingSupplementary = false
            }
        }

        async let heartRateZoneProfileTask = healthKitService.fetchRunHeartRateZoneProfile(
            for: run,
            observedMaximumHeartRate: detail.heartRates.map(\.bpm).max()
        )

        let route: [RunRoutePoint]
        if detail.route.isEmpty {
            route = (try? await healthKitService.fetchRunRoute(for: run)) ?? []
        } else {
            route = detail.route
        }

        let heartRateZoneProfile = await heartRateZoneProfileTask

        guard generation == loadGeneration else { return }
        guard case .loaded(let currentDetail) = state else { return }

        state = .loaded(
            currentDetail.updatingSupplementary(
                route: route,
                heartRateZoneProfile: heartRateZoneProfile
            )
        )
    }
}
