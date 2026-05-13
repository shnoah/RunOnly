import SwiftUI

enum AppStoreScreenshotMode: String, CaseIterable {
    case home
    case records
    case charts
    case routeSplits = "route-splits"
    case share

    static var current: AppStoreScreenshotMode? {
        let processInfo = ProcessInfo.processInfo
        let arguments = processInfo.arguments
        if let index = arguments.firstIndex(of: "--pnr-screenshot"),
           arguments.indices.contains(index + 1),
           let mode = AppStoreScreenshotMode(rawValue: arguments[index + 1]) {
            return mode
        }

        if let rawValue = processInfo.environment["PNR_SCREENSHOT_MODE"] {
            return AppStoreScreenshotMode(rawValue: rawValue)
        }

        return nil
    }
}

struct AppStoreScreenshotDemoRootView: View {
    let mode: AppStoreScreenshotMode
    @StateObject private var viewModel = RunningWorkoutsViewModel()
    @StateObject private var shoeStore = ShoeStore()
    @StateObject private var appSettings = AppSettingsStore()
    @StateObject private var mileageGoalStore = MileageGoalStore()

    var body: some View {
        Group {
            switch mode {
            case .home:
                HomeTabView(viewModel: viewModel)
            case .records:
                RecordTabView(viewModel: viewModel)
            case .charts:
                AppStoreDetailChartsDemoView()
            case .routeSplits:
                AppStoreRouteSplitsDemoView()
            case .share:
                RunShareComposerView(
                    run: AppStoreScreenshotFixtures.heroRun,
                    detail: .mockCompleteMetrics,
                    summary: RunDetail.mockCompleteMetrics.summaryMetrics
                )
            }
        }
        .environmentObject(viewModel)
        .environmentObject(shoeStore)
        .environmentObject(appSettings)
        .environmentObject(mileageGoalStore)
        .environment(\.locale, appSettings.appLocale)
        .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
        .onAppear {
            appSettings.completeHealthKitIntro()
            viewModel.loadAppStoreScreenshotData()
        }
    }
}

private struct AppStoreDetailChartsDemoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    RunOverviewMetricsSection(
                        run: AppStoreScreenshotFixtures.heroRun,
                        summary: RunDetail.mockCompleteMetrics.summaryMetrics
                    )
                    PerformanceChartSection(
                        run: AppStoreScreenshotFixtures.heroRun,
                        detail: .mockCompleteMetrics
                    )
                    HeartRateZoneSection(detail: .mockCompleteMetrics, isLoadingSupplementary: false)
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("상세 차트")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AppStoreRouteSplitsDemoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    RunOverviewMetricsSection(
                        run: AppStoreScreenshotFixtures.heroRun,
                        summary: RunDetail.mockCompleteMetrics.summaryMetrics
                    )
                    RunRouteSection(detail: .mockCompleteMetrics, isLoadingSupplementary: false)
                    RunSplitSection(detail: .mockCompleteMetrics)
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("경로와 스플릿")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

enum AppStoreScreenshotFixtures {
    static let referenceDate = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2026, month: 3, day: 18, hour: 9)
    ) ?? RunningWorkout.demoSampleStartDate

    static let heroRun = RunningWorkout.demoSample

    static var runs: [RunningWorkout] {
        [
            heroRun,
            run(
                id: "E341D60D-B25F-4A4F-9ED7-AE37257678D1",
                dayOffset: -2,
                hour: 6,
                minute: 58,
                duration: 2_665,
                distance: 8_120,
                indoor: false
            ),
            run(
                id: "285EF4DC-83B4-47B9-80D1-480DB7F71074",
                dayOffset: -5,
                hour: 19,
                minute: 12,
                duration: 1_935,
                distance: 6_240,
                indoor: false
            ),
            run(
                id: "59E50446-59DE-455D-9D73-9016C9C2979B",
                dayOffset: -7,
                hour: 7,
                minute: 4,
                duration: 3_220,
                distance: 10_030,
                indoor: false
            ),
            run(
                id: "1D1EE84C-3BBE-4A68-829F-1697F7C124D0",
                dayOffset: -10,
                hour: 20,
                minute: 16,
                duration: 1_812,
                distance: 5_050,
                indoor: true
            ),
            run(
                id: "82403518-A6A0-4575-8157-4E6F24CA938C",
                dayOffset: -13,
                hour: 7,
                minute: 32,
                duration: 4_560,
                distance: 14_180,
                indoor: false
            )
        ]
        .sorted { $0.startDate > $1.startDate }
    }

    static var vo2MaxSamples: [VO2MaxSample] {
        [
            VO2MaxSample(value: 48.8, date: date(dayOffset: -12, hour: 7, minute: 10)),
            VO2MaxSample(value: 49.4, date: date(dayOffset: -7, hour: 7, minute: 30)),
            VO2MaxSample(value: 50.1, date: date(dayOffset: -2, hour: 7, minute: 42))
        ]
    }

    static var restingHeartRateSnapshot: RestingHeartRateSnapshot {
        RestingHeartRateSnapshot(
            latestBPM: 51,
            baselineBPM: 52,
            measuredAt: date(dayOffset: 0, hour: 6, minute: 0),
            sampleCount: 14
        )
    }

    static var personalRecords: [PersonalRecordEntry] {
        PersonalRecordDistance.allCases.map { distance in
            let duration: TimeInterval?
            switch distance {
            case .meters400: duration = 74
            case .meters800: duration = 159
            case .kilometer1: duration = 205
            case .kilometers5: duration = 1_465
            case .kilometers10: duration = 3_220
            case .halfMarathon: duration = 7_320
            case .marathon: duration = nil
            }
            return PersonalRecordEntry(
                distance: distance,
                duration: duration,
                date: duration == nil ? nil : heroRun.startDate,
                workoutID: duration == nil ? nil : heroRun.id
            )
        }
    }

    static var personalRecordHistory: [PersonalRecordHistoryEntry] {
        [
            PersonalRecordHistoryEntry(
                distance: .kilometers5,
                duration: 1_465,
                date: heroRun.startDate,
                workoutID: heroRun.id
            ),
            PersonalRecordHistoryEntry(
                distance: .kilometer1,
                duration: 205,
                date: heroRun.startDate,
                workoutID: heroRun.id
            )
        ]
    }

    static func date(dayOffset: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let baseDay = calendar.startOfDay(for: referenceDate)
        let day = calendar.date(byAdding: .day, value: dayOffset, to: baseDay) ?? baseDay
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private static func run(
        id: String,
        dayOffset: Int,
        hour: Int,
        minute: Int,
        duration: TimeInterval,
        distance: Double,
        indoor: Bool
    ) -> RunningWorkout {
        RunningWorkout(
            id: UUID(uuidString: id) ?? UUID(),
            startDate: date(dayOffset: dayOffset, hour: hour, minute: minute),
            duration: duration,
            distanceInMeters: distance,
            sourceName: "Apple Watch",
            sourceBundleIdentifier: "com.apple.health",
            isIndoorWorkout: indoor
        )
    }
}
