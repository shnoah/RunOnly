import SwiftUI

enum AppStoreScreenshotMode: String, CaseIterable {
    case onboarding
    case home
    case records
    case calendar
    case personalRecords = "personal-records"
    case charts
    case routeSplits = "route-splits"
    case shoes
    case shoeDetail = "shoe-detail"
    case settings
    case privacy
    case dataPermissions = "data-permissions"
    case share
    case readinessTest = "readiness-test"

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
    @StateObject private var shoeStore = ShoeStore(loadFromDisk: false, persistsChanges: false)
    @StateObject private var appSettings = AppSettingsStore()
    @StateObject private var mileageGoalStore = MileageGoalStore()

    var body: some View {
        Group {
            switch mode {
            case .onboarding:
                NavigationStack {
                    HealthKitOnboardingView(showsDismissButton: false) {}
                }
            case .home:
                HomeTabView(viewModel: viewModel)
            case .records:
                RecordTabView(viewModel: viewModel)
            case .calendar:
                RecordCalendarSheet(viewModel: viewModel)
            case .personalRecords:
                NavigationStack {
                    PersonalRecordsManagementView(
                        currentRecords: viewModel.personalRecords,
                        pendingCandidates: viewModel.pendingPersonalRecordCandidates,
                        isRefreshingRecords: viewModel.isRefreshingPersonalRecords,
                        personalRecordProgress: viewModel.personalRecordProgress,
                        onApproveCandidate: viewModel.approvePersonalRecordCandidate,
                        onDismissCandidate: viewModel.dismissPersonalRecordCandidate,
                        onResetAndReloadRecords: viewModel.resetAndReloadPersonalRecords
                    )
                }
            case .charts:
                AppStoreDetailChartsDemoView()
            case .routeSplits:
                AppStoreRouteSplitsDemoView()
            case .shoes:
                ShoesTabView(runs: viewModel.allRuns)
            case .shoeDetail:
                NavigationStack {
                    ShoeDetailView(
                        shoe: AppStoreScreenshotFixtures.sampleShoe,
                        runs: AppStoreScreenshotFixtures.runs
                    )
                }
            case .settings:
                SettingsTabView()
            case .privacy:
                NavigationStack {
                    PrivacyPolicyView()
                }
            case .dataPermissions:
                NavigationStack {
                    DataPermissionsView()
                }
            case .share:
                ShareTabView(viewModel: viewModel)
            case .readinessTest:
                ReadinessFormulaTestDemoView()
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
            loadSampleShoesIfNeeded()
        }
    }

    private func loadSampleShoesIfNeeded() {
        guard shoeStore.shoes.isEmpty else { return }
        let trainer = AppStoreScreenshotFixtures.sampleShoe
        shoeStore.addShoe(trainer)
        if let latestRun = AppStoreScreenshotFixtures.runs.first {
            shoeStore.assign(trainer.id, to: latestRun.id)
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
                    HeartRateZoneSection(detail: .mockCompleteMetrics, loadState: .loaded)
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
                    RunRouteSection(detail: .mockCompleteMetrics, loadState: .loaded)
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

private struct ReadinessFormulaTestDemoView: View {
    private let referenceDate = AppStoreScreenshotFixtures.referenceDate

    private var cases: [ReadinessFormulaCase] {
        [
            ReadinessFormulaCase(title: "살살 6km", subtitle: "40분 · 노력 4", tint: Color(red: 0.42, green: 0.76, blue: 1.0), runs: [
                readinessRun(id: "9C361B5F-A799-4F1D-A3D1-B43F65F9E006", dayOffset: -1, duration: 2_400, distance: 6_000, effort: 4)
            ]),
            ReadinessFormulaCase(title: "인터벌 3km + 조깅 2km", subtitle: "30분 · 노력 8", tint: Color(red: 0.95, green: 0.59, blue: 0.32), runs: [
                readinessRun(id: "A9138452-569F-42D3-8896-A4B50F62A2D1", dayOffset: -1, duration: 1_800, distance: 5_000, effort: 8)
            ]),
            ReadinessFormulaCase(title: "짧은 고강도 4km", subtitle: "22분 40초 · 노력 9", tint: Color(red: 0.94, green: 0.41, blue: 0.45), runs: [
                readinessRun(id: "8B372734-BBFE-4532-B6D6-BC2368F3B115", dayOffset: -1, duration: 1_360, distance: 4_000, effort: 9)
            ]),
            ReadinessFormulaCase(title: "긴 이지런 10km", subtitle: "65분 · 노력 4", tint: Color(red: 0.50, green: 0.82, blue: 0.67), runs: [
                readinessRun(id: "0359F4BF-24F6-4832-9CC3-BF8992C07D74", dayOffset: -1, duration: 3_900, distance: 10_000, effort: 4)
            ]),
            ReadinessFormulaCase(title: "롱런 16km", subtitle: "96분 · 노력 6", tint: Color(red: 0.73, green: 0.62, blue: 0.97), runs: [
                readinessRun(id: "C411B25F-D973-4556-A056-1145B7708BAE", dayOffset: -1, duration: 5_760, distance: 16_000, effort: 6)
            ]),
            ReadinessFormulaCase(title: "백투백 8km + 5km", subtitle: "어제+오늘 · 노력 6/5", tint: Color(red: 0.98, green: 0.78, blue: 0.34), runs: [
                readinessRun(id: "D428B172-B029-431B-A09A-20113477B477", dayOffset: -2, duration: 3_000, distance: 8_000, effort: 6),
                readinessRun(id: "095484A7-C92B-4B1D-B660-636735C2ECF1", dayOffset: -1, duration: 1_800, distance: 5_000, effort: 5)
            ])
        ]
    }

    private var readinessBaseRuns: [RunningWorkout] {
        [
            readinessRun(id: "4E64F6D2-3F92-4583-B271-55C7636AC017", dayOffset: -16, duration: 1_800, distance: 5_000, effort: 5),
            readinessRun(id: "3E8F3017-FA4D-45FC-B916-1567105B1B61", dayOffset: -12, duration: 1_820, distance: 5_000, effort: 5),
            readinessRun(id: "7B5EE136-6C0C-48D6-80E5-B23EFD7804AF", dayOffset: -8, duration: 1_780, distance: 5_000, effort: 5)
        ]
    }

    private var didPass: Bool {
        guard let easyScore = readiness(for: cases[0]).score,
              let intervalScore = readiness(for: cases[1]).score else {
            return false
        }
        return intervalScore < easyScore
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        FeatureToneBadge(
                            text: didPass ? "테스트 통과" : "확인 필요",
                            tint: didPass ? Color(red: 0.29, green: 0.88, blue: 0.63) : Color(red: 0.94, green: 0.41, blue: 0.45),
                            foreground: .white
                        )

                        Text("준비도 계산 비교")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("실제 러닝 패턴별 Apple 노력 반영 결과")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(.top, 4)

                    LazyVStack(spacing: 10) {
                        ForEach(cases) { testCase in
                            ReadinessFormulaResultRow(
                                testCase: testCase,
                                readiness: readiness(for: testCase)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AppBackground())
            .navigationTitle("준비도 테스트")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func readiness(for testCase: ReadinessFormulaCase) -> RecoveryReadiness {
        RecoveryReadinessCalculator.build(
            from: readinessBaseRuns + testCase.runs,
            restingHeartRateSnapshot: AppStoreScreenshotFixtures.restingHeartRateSnapshot,
            now: referenceDate
        )
    }

    private func readinessRun(
        id: String,
        dayOffset: Int,
        duration: TimeInterval,
        distance: Double,
        effort: Double
    ) -> RunningWorkout {
        let startDate = AppStoreScreenshotFixtures.date(dayOffset: dayOffset, hour: 7, minute: 0)
        return RunningWorkout(
            id: UUID(uuidString: id) ?? UUID(),
            startDate: startDate,
            duration: duration,
            distanceInMeters: distance,
            sourceName: "Apple Watch",
            sourceBundleIdentifier: "com.apple.health",
            isIndoorWorkout: false,
            appleEffort: WorkoutEffort(
                score: effort,
                source: .appleWorkout,
                measuredAt: startDate.addingTimeInterval(duration)
            )
        )
    }
}

private struct ReadinessFormulaCase: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let tint: Color
    let runs: [RunningWorkout]
}

private struct ReadinessFormulaResultRow: View {
    let testCase: ReadinessFormulaCase
    let readiness: RecoveryReadiness

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(testCase.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 6) {
                    Text(testCase.subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(testCase.tint.opacity(0.95))
                    Text(readiness.effortBasisText ?? readiness.confidenceText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Text(readiness.factors.dropFirst(2).first ?? readiness.detail)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(readiness.scoreText)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(readiness.status)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(testCase.tint.opacity(0.34))
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 78)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(testCase.tint.opacity(0.24), lineWidth: 1)
                )
        )
    }
}

private struct ReadinessFormulaResultCard: View {
    let title: String
    let subtitle: String
    let readiness: RecoveryReadiness
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.95))
                }

                Spacer()

                FeatureToneBadge(text: readiness.status, tint: tint, foreground: .white)
            }

            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(readiness.scoreText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(readiness.confidenceText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(readiness.factors.prefix(3).enumerated()), id: \.offset) { _, factor in
                    RecoveryReasonRow(text: factor, tint: tint)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                )
        )
    }
}

enum AppStoreScreenshotFixtures {
    static let referenceDate = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2026, month: 3, day: 18, hour: 9)
    ) ?? RunningWorkout.demoSampleStartDate

    static let heroRun = RunningWorkout.demoSample
    static let sampleShoe = RunningShoe(
        id: UUID(uuidString: "8D5E6A25-8898-4C27-A393-F5D63AA1E564") ?? UUID(),
        nickname: "트레이너 01",
        brand: "브랜드 A",
        model: "데일리",
        startMileageKilometers: 42,
        retirementKilometers: 600,
        createdAt: referenceDate.addingTimeInterval(-86400 * 45)
    )

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
