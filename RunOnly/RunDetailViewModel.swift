import Foundation

@MainActor
final class RunDetailViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(RunDetail)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let healthKitService = HealthKitService()
    private let run: RunningWorkout

    init(run: RunningWorkout) {
        self.run = run
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        state = .loading

        do {
            let detail = try await healthKitService.fetchRunDetail(for: run)
            state = .loaded(detail)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    enum DebugScenario {
        case live
        case missingRoute
        case missingHeartRate
        case empty
    }

    func applyDebugScenario(_ scenario: DebugScenario) async {
        switch scenario {
        case .live:
            await load()
        case .missingRoute:
            state = .loaded(.mockMissingRoute)
        case .missingHeartRate:
            state = .loaded(.mockMissingHeartRate)
        case .empty:
            state = .loaded(.empty)
        }
    }
}
