import Foundation

final class RunDetailPerformanceTrace {
    private let runID: String
    private let startTime = ProcessInfo.processInfo.systemUptime
    private var previousTime: TimeInterval
    private let lock = NSLock()

    init(runID: UUID) {
        self.runID = String(runID.uuidString.prefix(8))
        self.previousTime = startTime
        mark("start")
    }

    func mark(_ event: String, detail: String = "") {
        #if DEBUG
        lock.lock()
        defer { lock.unlock() }

        let now = ProcessInfo.processInfo.systemUptime
        let totalMilliseconds = Int((now - startTime) * 1_000)
        let deltaMilliseconds = Int((now - previousTime) * 1_000)
        previousTime = now

        let suffix = detail.isEmpty ? "" : " \(detail)"
        let message = "PNR_DETAIL_PERF run=\(runID) event=\(event) total=\(totalMilliseconds)ms delta=\(deltaMilliseconds)ms\(suffix)"
        print(message)
        #endif
    }
}

enum RunDetailSupplementaryLoadState {
    case idle
    case loading
    case provisional
    case loaded
    case unavailable
    case failed
}

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
    @Published private(set) var routeLoadState: RunDetailSupplementaryLoadState = .idle
    @Published private(set) var heartRateZoneLoadState: RunDetailSupplementaryLoadState = .idle
    @Published private(set) var cachedSummary: RunSummaryMetrics?

    private let healthKitService = HealthKitService()
    private let summaryCacheStore = RunSummaryCacheStore.shared
    private let detailCacheStore = RunDetailCacheStore.shared
    private let heartRateZoneProfileCacheStore = HeartRateZoneProfileCacheStore.shared
    private let run: RunningWorkout
    private let initialScenario: DebugScenario?
    private var hasAppliedInitialScenario = false
    private var loadGeneration = 0
    private var heartRateZoneSettings: HeartRateZoneSettings {
        HeartRateZoneSettings.load()
    }

    init(run: RunningWorkout, initialScenario: DebugScenario? = nil) {
        self.run = run
        self.initialScenario = initialScenario
        cachedSummary = run.isDemoWorkout
            ? RunDetail.mockCompleteMetrics.summaryMetrics
            : summaryCacheStore.summary(for: run.id)
    }

    // 화면이 처음 나타났을 때만 실제 상세 데이터를 요청한다.
    func loadIfNeeded() async {
        guard case .idle = state else { return }
        if let initialScenario, !hasAppliedInitialScenario {
            hasAppliedInitialScenario = true
            await applyDebugScenario(initialScenario)
            return
        }

        if run.isDemoWorkout {
            await applyDebugScenario(.completeMetrics)
            return
        }

        await load()
    }

    // HealthKit 조회 결과를 상태에 반영한다. 샘플 러닝은 같은 mock detail을 항상 재사용한다.
    func load() async {
        if run.isDemoWorkout {
            await applyDebugScenario(.completeMetrics)
            return
        }

        loadGeneration += 1
        let currentGeneration = loadGeneration
        resetSupplementaryLoadStates()

        let trace = RunDetailPerformanceTrace(runID: run.id)
        let fixedProfile = heartRateZoneSettings.resolvedFixedProfile
        let cachedProfile = fixedProfile ?? heartRateZoneProfileCacheStore.freshProfile
        if cachedProfile != nil {
            trace.mark("zone_profile_cache_hit")
        } else {
            trace.mark("zone_profile_cache_miss")
        }

        let cachedDetail = detailCacheStore.detail(for: run, heartRateZoneProfile: cachedProfile)
        if let cachedDetail {
            trace.mark("cache_hit")
            updateCachedSummary(from: cachedDetail)
            state = .loaded(cachedDetail)
            trace.mark("cache_state_set", detail: "splits=\(cachedDetail.splits.count) hr=\(cachedDetail.heartRates.count)")
            trace.mark("detail_cache_skip_healthkit")
            await loadSupplementary(for: cachedDetail, generation: currentGeneration, trace: trace)
            trace.mark("view_model.done")
            return
        } else {
            trace.mark("cache_miss")
            state = .loading
        }

        do {
            let detail = try await healthKitService.fetchRunDetail(for: run, trace: trace)
            guard currentGeneration == loadGeneration else { return }
            trace.mark("view_model.initial_detail_ready", detail: "splits=\(detail.splits.count) hr=\(detail.heartRates.count) route=\(detail.route.count)")
            let profileAdjustedDetail = cachedProfile.map {
                detail.updatingSupplementary(route: [], heartRateZoneProfile: $0)
            } ?? detail
            let displayDetail = profileAdjustedDetail.mergingSupplementary(from: loadedDetail)
            updateCachedSummary(from: displayDetail)
            detailCacheStore.save(displayDetail, for: run)
            trace.mark("cache_save")
            state = .loaded(displayDetail)
            trace.mark("view_model.initial_state_set")
            await loadSupplementary(for: displayDetail, generation: currentGeneration, trace: trace)
            trace.mark("view_model.done")
        } catch {
            guard currentGeneration == loadGeneration else { return }
            if cachedDetail == nil {
                state = .failed(error.localizedDescription)
            }
            resetSupplementaryLoadStates()
        }
    }

    enum DebugScenario {
        case live
        case completeMetrics
        case pausedWorkout
        case missingRoute
        case missingHeartRate
        case missingCadence
        case empty
    }

    // 개발 중에는 실데이터 없이도 다양한 상세 화면 레이아웃을 점검할 수 있다.
    func applyDebugScenario(_ scenario: DebugScenario) async {
        loadGeneration += 1
        resetSupplementaryLoadStates()

        switch scenario {
        case .live:
            await load()
        case .completeMetrics:
            state = .loaded(.mockCompleteMetrics)
            cachedSummary = RunDetail.mockCompleteMetrics.summaryMetrics
            markSupplementaryLoaded(for: .mockCompleteMetrics)
        case .pausedWorkout:
            state = .loaded(.mockPausedWorkout)
            cachedSummary = RunDetail.mockPausedWorkout.summaryMetrics
            markSupplementaryLoaded(for: .mockPausedWorkout)
        case .missingRoute:
            state = .loaded(.mockMissingRoute)
            cachedSummary = RunDetail.mockMissingRoute.summaryMetrics
            markSupplementaryLoaded(for: .mockMissingRoute)
        case .missingHeartRate:
            state = .loaded(.mockMissingHeartRate)
            cachedSummary = RunDetail.mockMissingHeartRate.summaryMetrics
            markSupplementaryLoaded(for: .mockMissingHeartRate)
        case .missingCadence:
            state = .loaded(.mockMissingCadence)
            cachedSummary = RunDetail.mockMissingCadence.summaryMetrics
            markSupplementaryLoaded(for: .mockMissingCadence)
        case .empty:
            state = .loaded(.empty)
            cachedSummary = nil
            markSupplementaryLoaded(for: .empty)
        }
    }

    private func loadSupplementary(
        for detail: RunDetail,
        generation: Int,
        trace: RunDetailPerformanceTrace? = nil
    ) async {
        trace?.mark("supplementary.start")
        async let routeLoad: Void = loadRouteSupplementary(
            for: detail,
            generation: generation,
            trace: trace
        )
        async let zoneLoad: Void = loadHeartRateZoneSupplementary(
            for: detail,
            generation: generation,
            trace: trace
        )
        _ = await (routeLoad, zoneLoad)
        trace?.mark("supplementary.all_done")
    }

    private func loadRouteSupplementary(
        for detail: RunDetail,
        generation: Int,
        trace: RunDetailPerformanceTrace? = nil
    ) async {
        guard generation == loadGeneration else { return }
        if !detail.route.isEmpty {
            routeLoadState = .loaded
            trace?.mark("route.reused", detail: "points=\(detail.route.count)")
            return
        }

        routeLoadState = .loading
        trace?.mark("route.loading_start")
        do {
            let route = try await healthKitService.fetchRunRoute(for: run)
            guard generation == loadGeneration else { return }
            trace?.mark("route.query_done", detail: "points=\(route.count)")

            if route.isEmpty {
                routeLoadState = .unavailable
                trace?.mark("route.unavailable")
                return
            }

            applySupplementaryUpdate(
                route: route,
                heartRateZoneProfile: nil,
                generation: generation,
                shouldSaveDetail: true
            )
            routeLoadState = .loaded
            trace?.mark("route.state_set", detail: "route=\(route.count)")
        } catch {
            guard generation == loadGeneration else { return }
            routeLoadState = .failed
            trace?.mark("route.failed", detail: error.localizedDescription)
        }
    }

    private func loadHeartRateZoneSupplementary(
        for detail: RunDetail,
        generation: Int,
        trace: RunDetailPerformanceTrace? = nil
    ) async {
        guard generation == loadGeneration else { return }

        if detail.heartRates.count < 2 {
            heartRateZoneLoadState = .unavailable
            trace?.mark("zone.unavailable", detail: "heartRates=\(detail.heartRates.count)")
            return
        }

        if let fixedProfile = heartRateZoneSettings.resolvedFixedProfile {
            heartRateZoneLoadState = .loaded
            applySupplementaryUpdate(
                route: [],
                heartRateZoneProfile: fixedProfile,
                generation: generation,
                shouldSaveDetail: true
            )
            trace?.mark("zone.settings_profile_applied")
            return
        }

        if let cachedProfile = heartRateZoneProfileCacheStore.freshProfile {
            heartRateZoneLoadState = .loaded
            applySupplementaryUpdate(
                route: [],
                heartRateZoneProfile: cachedProfile,
                generation: generation,
                shouldSaveDetail: true
            )
            trace?.mark("zone.profile_cache_hit")
            return
        }

        heartRateZoneLoadState = detail.heartRateZoneDistribution == nil ? .loading : .provisional
        trace?.mark("zone.profile_loading_start")
        let heartRateZoneProfile = await healthKitService.fetchRunHeartRateZoneProfile(
            for: run,
            observedMaximumHeartRate: detail.heartRates.map(\.bpm).max()
        )
        heartRateZoneProfileCacheStore.save(heartRateZoneProfile)
        trace?.mark("zone.profile_query_done")

        guard generation == loadGeneration else { return }
        if let heartRateZoneProfile {
            applySupplementaryUpdate(
                route: [],
                heartRateZoneProfile: heartRateZoneProfile,
                generation: generation,
                shouldSaveDetail: true
            )
        }

        guard case .loaded(let currentDetail) = state else { return }
        heartRateZoneLoadState = currentDetail.heartRateZoneDistribution == nil ? .unavailable : .loaded
        trace?.mark("zone.profile_state_set")
    }

    private func applySupplementaryUpdate(
        route: [RunRoutePoint],
        heartRateZoneProfile: HeartRateZoneProfile?,
        generation: Int,
        shouldSaveDetail: Bool
    ) {
        guard generation == loadGeneration else { return }
        guard case .loaded(let currentDetail) = state else { return }
        let updatedDetail = currentDetail.updatingSupplementary(
            route: route,
            heartRateZoneProfile: heartRateZoneProfile
        )
        updateCachedSummary(from: updatedDetail)
        if shouldSaveDetail {
            detailCacheStore.save(updatedDetail, for: run)
        }
        state = .loaded(updatedDetail)
    }

    private func applySupplementaryUpdate(
        route: [RunRoutePoint],
        heartRateZoneProfile: HeartRateZoneProfile?,
        generation: Int
    ) {
        applySupplementaryUpdate(
            route: route,
            heartRateZoneProfile: heartRateZoneProfile,
            generation: generation,
            shouldSaveDetail: false
        )
    }

    private func resetSupplementaryLoadStates() {
        routeLoadState = .idle
        heartRateZoneLoadState = .idle
    }

    private func markSupplementaryLoaded(for detail: RunDetail) {
        routeLoadState = detail.route.isEmpty ? .unavailable : .loaded
        heartRateZoneLoadState = detail.heartRateZoneDistribution == nil ? .unavailable : .loaded
    }

    private var loadedDetail: RunDetail? {
        guard case .loaded(let detail) = state else { return nil }
        return detail
    }

    private func updateCachedSummary(from detail: RunDetail) {
        let mergedSummary = detail.summaryMetrics.mergingMissingValues(from: cachedSummary)
        guard mergedSummary.hasAnyValue else { return }
        cachedSummary = mergedSummary
        summaryCacheStore.save(mergedSummary, for: run.id)
    }
}
