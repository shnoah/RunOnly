import SwiftUI

enum AppStoreScreenshotMode: String, CaseIterable {
    case onboarding
    case home
    case records
    case recordsEmpty = "records-empty"
    case calendar
    case personalRecords = "personal-records"
    case personalRecordRun = "personal-record-run"
    case recentRuns = "recent-runs"
    case charts
    case routeSplits = "route-splits"
    case routeSplitsTable = "route-splits-table"
    case runDetail = "run-detail"
    case runDetailPaused = "run-detail-paused"
    case runDetailMissingRoute = "run-detail-missing-route"
    case runDetailMissingHeartRate = "run-detail-missing-heart-rate"
    case runNoteEditor = "run-note-editor"
    case runDetailShare = "run-detail-share"
    case heartZones = "heart-zones"
    case shoes
    case shoesEmpty = "shoes-empty"
    case shoeDetail = "shoe-detail"
    case shoeDetailEmpty = "shoe-detail-empty"
    case shoeAdd = "shoe-add"
    case shoeEdit = "shoe-edit"
    case shoeOrder = "shoe-order"
    case settings
    case settingsLanguage = "settings-language"
    case settingsDistanceUnit = "settings-distance-unit"
    case settingsHeartZones = "settings-heart-zones"
    case settingsHeartZonesManual = "settings-heart-zones-manual"
    case settingsShoeData = "settings-shoe-data"
    case settingsDataManagement = "settings-data-management"
    case settingsSupport = "settings-support"
    case privacy
    case dataPermissions = "data-permissions"
    case share
    case shareTemplatePicker = "share-template-picker"
    case shareComposerSticker = "share-composer-sticker"
    case shareComposerStyle1 = "share-composer-style1"
    case shareComposerMicro = "share-composer-micro"
    case shareComposerStack = "share-composer-stack"
    case shareComposerGlass = "share-composer-glass"
    case shareComposerCaption = "share-composer-caption"
    case shareComposerRace = "share-composer-race"
    case mileageGoal = "mileage-goal"
    case mileageBreakdown = "mileage-breakdown"
    case mileageBreakdownAll = "mileage-breakdown-all"
    case predictionTrend = "prediction-trend"
    case predictionTrend5K = "prediction-trend-5k"
    case predictionTrendHalf = "prediction-trend-half"
    case predictionMethod = "prediction-method"
    case vo2Trend = "vo2-trend"
    case vo2TrendAll = "vo2-trend-all"
    case readiness = "readiness"
    case readinessEvidence = "readiness-evidence"
    case homeEmpty = "home-empty"
    case sampleRunEntry = "sample-run-entry"
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

    var usesSampleShoes: Bool {
        switch self {
        case .shoesEmpty, .shoeDetailEmpty, .shoeAdd:
            return false
        default:
            return true
        }
    }
}

struct AppStoreScreenshotDemoRootView: View {
    let mode: AppStoreScreenshotMode
    @StateObject private var viewModel = RunningWorkoutsViewModel()
    @StateObject private var shoeStore = ShoeStore(loadFromDisk: false, persistsChanges: false)
    @StateObject private var appSettings = AppSettingsStore()
    @StateObject private var mileageGoalStore = MileageGoalStore()
    @StateObject private var runNoteStore = RunNoteStore(loadFromDisk: false, persistsChanges: false)

    var body: some View {
        Group {
            switch mode {
            case .onboarding:
                NavigationStack {
                    HealthKitOnboardingView(showsDismissButton: false) {}
                }
            case .home:
                HomeTabView(viewModel: viewModel)
            case .homeEmpty:
                NavigationStack {
                    HomeEmptyStateView {}
                }
            case .records:
                RecordTabView(viewModel: viewModel)
            case .recordsEmpty:
                NavigationStack {
                    RunReviewFallbackView(
                        title: "러닝 기록이 없습니다",
                        message: "Apple 건강 권한을 확인하거나 샘플 러닝으로 먼저 둘러볼 수 있습니다.",
                        buttonTitle: "새로고침"
                    ) {}
                }
            case .sampleRunEntry:
                NavigationStack {
                    RunReviewFallbackView(
                        title: "샘플 러닝으로 둘러보기",
                        message: "HealthKit 데이터가 없어도 핵심 상세 화면을 확인할 수 있습니다.",
                        buttonTitle: "샘플 러닝 열기"
                    ) {}
                }
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
            case .personalRecordRun:
                AppStoreRunDetailDemoView(
                    scenario: .completeMetrics,
                    achievements: [.kilometer1, .kilometers5]
                )
            case .recentRuns:
                NavigationStack {
                    RecentRunsListView(runs: viewModel.allRuns, shoeStore: shoeStore)
                }
            case .charts:
                AppStoreDetailChartsDemoView()
            case .routeSplits:
                AppStoreRouteSplitsDemoView()
            case .routeSplitsTable:
                AppStoreRouteSplitsTableDemoView()
            case .runDetail:
                AppStoreRunDetailDemoView(scenario: .completeMetrics)
            case .runDetailPaused:
                AppStoreRunDetailDemoView(scenario: .pausedWorkout)
            case .runDetailMissingRoute:
                AppStoreRunDetailDemoView(scenario: .missingRoute)
            case .runDetailMissingHeartRate:
                AppStoreRunDetailDemoView(scenario: .missingHeartRate)
            case .runNoteEditor:
                RunNoteEditorView(run: AppStoreScreenshotFixtures.heroRun)
            case .runDetailShare:
                AppStoreShareComposerDemoView(template: .sticker)
            case .heartZones:
                AppStoreHeartZonesDemoView()
            case .shoes:
                ShoesTabView(runs: viewModel.allRuns)
            case .shoesEmpty:
                ShoesTabView(runs: [])
            case .shoeDetail:
                NavigationStack {
                    ShoeDetailView(
                        shoe: AppStoreScreenshotFixtures.sampleShoe,
                        runs: AppStoreScreenshotFixtures.runs
                    )
                }
            case .shoeDetailEmpty:
                NavigationStack {
                    ShoeDetailView(
                        shoe: AppStoreScreenshotFixtures.sampleShoe,
                        runs: []
                    )
                }
            case .shoeAdd:
                AddShoeView()
            case .shoeEdit:
                AddShoeView(existingShoe: AppStoreScreenshotFixtures.sampleShoe)
            case .shoeOrder:
                ShoeOrderEditView()
            case .settings:
                SettingsTabView()
            case .settingsLanguage:
                NavigationStack {
                    AppLanguageSettingsView()
                }
            case .settingsDistanceUnit:
                NavigationStack {
                    DistanceUnitSettingsView()
                }
            case .settingsHeartZones:
                NavigationStack {
                    HeartRateZoneSettingsView()
                }
            case .settingsHeartZonesManual:
                NavigationStack {
                    HeartRateZoneSettingsView(initialSettings: AppStoreScreenshotFixtures.manualHeartRateZoneSettings)
                }
            case .settingsShoeData:
                NavigationStack {
                    ShoeDataSettingsView()
                }
            case .settingsDataManagement:
                NavigationStack {
                    DataManagementView()
                }
            case .settingsSupport:
                NavigationStack {
                    SupportCenterView()
                }
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
            case .shareTemplatePicker:
                AppStoreShareTemplatePickerDemoView()
            case .shareComposerSticker:
                AppStoreShareComposerDemoView(template: .sticker)
            case .shareComposerStyle1:
                AppStoreShareComposerDemoView(template: .style1)
            case .shareComposerMicro:
                AppStoreShareComposerDemoView(template: .microInline)
            case .shareComposerStack:
                AppStoreShareComposerDemoView(template: .minimalStack)
            case .shareComposerGlass:
                AppStoreShareComposerDemoView(template: .glassPills)
            case .shareComposerCaption:
                AppStoreShareComposerDemoView(template: .serifCaption)
            case .shareComposerRace:
                AppStoreShareComposerDemoView(template: .raceLabel)
            case .mileageGoal:
                MileageGoalEditorView(currentDistanceKilometers: viewModel.summary.monthDistanceKilometers)
            case .mileageBreakdown:
                NavigationStack {
                    MileageBreakdownView(viewModel: viewModel)
                }
            case .mileageBreakdownAll:
                NavigationStack {
                    MileageBreakdownView(viewModel: viewModel, initialRange: .all)
                }
            case .predictionTrend:
                NavigationStack {
                    PredictionTrendView(runs: viewModel.allRuns, initialDistance: .tenK)
                }
            case .predictionTrend5K:
                NavigationStack {
                    PredictionTrendView(runs: viewModel.allRuns, initialDistance: .fiveK)
                }
            case .predictionTrendHalf:
                NavigationStack {
                    PredictionTrendView(runs: viewModel.allRuns, initialDistance: .half)
                }
            case .predictionMethod:
                PredictionMethodView()
            case .vo2Trend:
                NavigationStack {
                    VO2MaxTrendView(samples: viewModel.vo2MaxSamples)
                }
            case .vo2TrendAll:
                NavigationStack {
                    VO2MaxTrendView(samples: viewModel.vo2MaxSamples, initialRange: .all)
                }
            case .readiness:
                NavigationStack {
                    RecoveryReadinessView(readiness: viewModel.summary.recoveryReadiness)
                }
            case .readinessEvidence:
                ReadinessEvidenceView()
            case .readinessTest:
                ReadinessFormulaTestDemoView()
            }
        }
        .environmentObject(viewModel)
        .environmentObject(shoeStore)
        .environmentObject(appSettings)
        .environmentObject(mileageGoalStore)
        .environmentObject(runNoteStore)
        .environment(\.locale, appSettings.appLocale)
        .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
        .onAppear {
            appSettings.completeHealthKitIntro()
            viewModel.loadAppStoreScreenshotData()
            if mode.usesSampleShoes {
                loadSampleShoesIfNeeded()
            }
        }
    }

    private func loadSampleShoesIfNeeded() {
        guard shoeStore.shoes.isEmpty else { return }
        AppStoreScreenshotFixtures.sampleShoes.forEach { shoeStore.addShoe($0) }
        let runs = AppStoreScreenshotFixtures.runs
        for (index, run) in runs.enumerated() {
            let shoe = AppStoreScreenshotFixtures.sampleShoes[index % AppStoreScreenshotFixtures.sampleShoes.count]
            shoeStore.assign(shoe.id, to: run.id)
        }
    }
}

private struct AppStoreDetailChartsDemoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    PNRPageHeader(
                        eyebrow: "DETAIL",
                        title: "상세 차트",
                        subtitle: "페이스, 심박, 케이던스 흐름을 한 화면에서 확인합니다."
                    )
                    RunOverviewMetricsSection(
                        run: AppStoreScreenshotFixtures.heroRun,
                        summary: RunDetail.mockCompleteMetrics.summaryMetrics,
                        activeDuration: RunDetail.mockCompleteMetrics.activeDuration,
                        baselinePaceSecondsPerKilometer: TrainingLoadCalculator.baselinePaceSecondsPerKilometer(from: AppStoreScreenshotFixtures.runs)
                    )
                    PerformanceChartSection(
                        run: AppStoreScreenshotFixtures.heroRun,
                        detail: .mockCompleteMetrics
                    )
                    HeartRateZoneSection(detail: .mockCompleteMetrics, loadState: .loaded, initialSelectedZoneIndex: 2)
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AppStoreRouteSplitsDemoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    PNRPageHeader(
                        eyebrow: "ROUTE",
                        title: "경로와 스플릿",
                        subtitle: "지도와 구간 기록을 같은 흐름으로 확인합니다."
                    )
                    RunOverviewMetricsSection(
                        run: AppStoreScreenshotFixtures.heroRun,
                        summary: RunDetail.mockCompleteMetrics.summaryMetrics,
                        activeDuration: RunDetail.mockCompleteMetrics.activeDuration,
                        baselinePaceSecondsPerKilometer: TrainingLoadCalculator.baselinePaceSecondsPerKilometer(from: AppStoreScreenshotFixtures.runs)
                    )
                    RunRouteSection(detail: .mockCompleteMetrics, loadState: .loaded)
                    RunSplitSection(detail: .mockCompleteMetrics)
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AppStoreRouteSplitsTableDemoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    PNRPageHeader(
                        eyebrow: "SPLITS",
                        title: "구간",
                        subtitle: "거리, 페이스, 심박, 케이던스를 같은 축으로 확인합니다."
                    )
                    RunSplitSection(detail: .mockCompleteMetrics)
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AppStoreRunDetailDemoView: View {
    let scenario: RunDetailViewModel.DebugScenario
    let achievements: [PersonalRecordDistance]

    init(
        scenario: RunDetailViewModel.DebugScenario,
        achievements: [PersonalRecordDistance] = []
    ) {
        self.scenario = scenario
        self.achievements = achievements
    }

    var body: some View {
        NavigationStack {
            RunDetailView(
                run: AppStoreScreenshotFixtures.heroRun,
                personalRecordAchievements: achievements,
                initialDebugScenario: scenario
            )
        }
    }
}

private struct AppStoreHeartZonesDemoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    PNRPageHeader(
                        eyebrow: "EFFORT",
                        title: "심박 존",
                        subtitle: "러닝 강도를 존별 시간과 bpm 범위로 확인합니다."
                    )

                    RunOverviewMetricsSection(
                        run: AppStoreScreenshotFixtures.heroRun,
                        summary: RunDetail.mockCompleteMetrics.summaryMetrics,
                        activeDuration: RunDetail.mockCompleteMetrics.activeDuration,
                        baselinePaceSecondsPerKilometer: TrainingLoadCalculator.baselinePaceSecondsPerKilometer(from: AppStoreScreenshotFixtures.runs)
                    )

                    HeartRateZoneSection(detail: .mockCompleteMetrics, loadState: .loaded, initialSelectedZoneIndex: 2)

                    DetailSection(title: "수동 설정 예시", systemImage: "slider.horizontal.3", tint: PNR2026.track) {
                        VStack(alignment: .leading, spacing: 12) {
                            HeartRateZonePreviewRows(
                                ranges: AppStoreScreenshotFixtures.manualHeartRateZoneSettings.previewRanges
                            )
                            Text("수동 범위는 저장 전에도 바로 미리보기로 확인할 수 있습니다.")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PNR2026.muted)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AppStoreShareComposerDemoView: View {
    let template: RunShareTemplate

    var body: some View {
        RunShareComposerView(
            run: AppStoreScreenshotFixtures.heroRun,
            detail: .mockCompleteMetrics,
            summary: RunDetail.mockCompleteMetrics.summaryMetrics,
            initialTemplate: template,
            showsTemplateSelector: true
        )
    }
}

private struct AppStoreShareTemplatePickerDemoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PNRPageHeader(
                        eyebrow: "TEMPLATE",
                        title: "공유 템플릿",
                        subtitle: "\(AppStoreScreenshotFixtures.heroRun.distanceText) 러닝을 여러 스타일로 저장합니다."
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 164), spacing: 12)], spacing: 12) {
                        ForEach(RunShareTemplate.allCases) { template in
                            AppStoreShareTemplatePreviewCard(template: template)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AppStoreShareTemplatePreviewCard: View {
    let template: RunShareTemplate

    private let previewLimit = CGSize(width: 154, height: 146)

    private var previewSize: CGSize {
        let scale = min(
            previewLimit.width / max(template.canvasSize.width, 1),
            previewLimit.height / max(template.canvasSize.height, 1)
        )
        return CGSize(
            width: template.canvasSize.width * scale,
            height: template.canvasSize.height * scale
        )
    }

    private var style: RunShareArtworkStyle {
        RunShareAdvancedStyle.defaultStyle(for: template).artworkStyle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                TransparentPreviewBackground()
                    .clipShape(RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous))

                RunShareArtworkView(
                    run: AppStoreScreenshotFixtures.heroRun,
                    detail: .mockCompleteMetrics,
                    template: template,
                    enabledFields: template.defaultEnabledFields,
                    summary: RunDetail.mockCompleteMetrics.summaryMetrics,
                    style: style
                )
                .frame(width: template.canvasSize.width, height: template.canvasSize.height)
                .scaleEffect(previewSize.width / template.canvasSize.width, anchor: .topLeading)
                .frame(width: previewSize.width, height: previewSize.height, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 148)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.quickStartTitle)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(PNR2026.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(template.descriptionText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PNR2026.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 4)

                Text(template.useCaseLabel)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PNR2026.track)
                    )
            }
        }
        .padding(12)
        .frame(minHeight: 218, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                .fill(PNR2026.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .stroke(PNR2026.line, lineWidth: 1)
                )
        )
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
            .navigationTitle("")
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

    static var sampleShoes: [RunningShoe] {
        [
            sampleShoe,
            RunningShoe(
                id: UUID(uuidString: "54EA82D7-5038-462E-8A70-3C128DB04205") ?? UUID(),
                nickname: "스피드 02",
                brand: "브랜드 B",
                model: "레이서",
                startMileageKilometers: 118,
                retirementKilometers: 450,
                createdAt: referenceDate.addingTimeInterval(-86400 * 28)
            ),
            RunningShoe(
                id: UUID(uuidString: "E43C1A63-7851-44D4-98C9-63F37852721B") ?? UUID(),
                nickname: "롱런 03",
                brand: "브랜드 C",
                model: "쿠션",
                startMileageKilometers: 284,
                retirementKilometers: 700,
                createdAt: referenceDate.addingTimeInterval(-86400 * 92)
            )
        ]
    }

    static var manualHeartRateZoneSettings: HeartRateZoneSettings {
        HeartRateZoneSettings(
            kind: .manual,
            maximumHeartRateBPM: 190,
            lactateThresholdBPM: 170,
            manualRanges: [
                HeartRateZoneBPMRange(zoneIndex: 0, lowerBPM: 98, upperBPM: 129),
                HeartRateZoneBPMRange(zoneIndex: 1, lowerBPM: 130, upperBPM: 149),
                HeartRateZoneBPMRange(zoneIndex: 2, lowerBPM: 150, upperBPM: 164),
                HeartRateZoneBPMRange(zoneIndex: 3, lowerBPM: 165, upperBPM: 178),
                HeartRateZoneBPMRange(zoneIndex: 4, lowerBPM: 179, upperBPM: 196)
            ]
        )
    }

    static var runs: [RunningWorkout] {
        [
            heroRun,
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01001",
                dayOffset: -2,
                hour: 6,
                minute: 58,
                duration: 2_665,
                distance: 8_120,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01002",
                dayOffset: -5,
                hour: 19,
                minute: 12,
                duration: 1_935,
                distance: 6_240,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01003",
                dayOffset: -7,
                hour: 7,
                minute: 4,
                duration: 3_220,
                distance: 10_030,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01004",
                dayOffset: -10,
                hour: 20,
                minute: 16,
                duration: 1_812,
                distance: 5_050,
                indoor: true
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01005",
                dayOffset: -13,
                hour: 7,
                minute: 32,
                duration: 4_560,
                distance: 14_180,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01006",
                dayOffset: -17,
                hour: 6,
                minute: 42,
                duration: 2_420,
                distance: 7_450,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01007",
                dayOffset: -22,
                hour: 7,
                minute: 8,
                duration: 3_620,
                distance: 11_200,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01008",
                dayOffset: -29,
                hour: 19,
                minute: 20,
                duration: 1_770,
                distance: 5_400,
                indoor: true
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01009",
                dayOffset: -37,
                hour: 6,
                minute: 55,
                duration: 3_125,
                distance: 9_800,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D0100A",
                dayOffset: -44,
                hour: 8,
                minute: 4,
                duration: 5_480,
                distance: 16_100,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D0100B",
                dayOffset: -51,
                hour: 19,
                minute: 36,
                duration: 1_950,
                distance: 6_050,
                indoor: true
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D0100C",
                dayOffset: -66,
                hour: 7,
                minute: 18,
                duration: 3_950,
                distance: 12_000,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D0100D",
                dayOffset: -80,
                hour: 6,
                minute: 48,
                duration: 1_690,
                distance: 5_150,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D0100E",
                dayOffset: -94,
                hour: 18,
                minute: 58,
                duration: 2_860,
                distance: 8_700,
                indoor: true
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D0100F",
                dayOffset: -110,
                hour: 7,
                minute: 2,
                duration: 6_600,
                distance: 18_400,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01010",
                dayOffset: -126,
                hour: 7,
                minute: 24,
                duration: 2_195,
                distance: 6_800,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01011",
                dayOffset: -145,
                hour: 18,
                minute: 40,
                duration: 3_400,
                distance: 10_500,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01012",
                dayOffset: -166,
                hour: 6,
                minute: 50,
                duration: 2_310,
                distance: 7_100,
                indoor: true
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01013",
                dayOffset: -188,
                hour: 7,
                minute: 12,
                duration: 4_380,
                distance: 13_300,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01014",
                dayOffset: -211,
                hour: 19,
                minute: 8,
                duration: 1_625,
                distance: 5_000,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01015",
                dayOffset: -236,
                hour: 6,
                minute: 46,
                duration: 3_030,
                distance: 9_250,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01016",
                dayOffset: -263,
                hour: 7,
                minute: 20,
                duration: 5_400,
                distance: 15_600,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01017",
                dayOffset: -291,
                hour: 18,
                minute: 52,
                duration: 2_100,
                distance: 6_400,
                indoor: true
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01018",
                dayOffset: -322,
                hour: 7,
                minute: 6,
                duration: 3_860,
                distance: 11_800,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D01019",
                dayOffset: -351,
                hour: 6,
                minute: 44,
                duration: 1_850,
                distance: 5_600,
                indoor: false
            ),
            run(
                id: "4EAD28B5-9F1C-4E33-9A1B-AC9176D0101A",
                dayOffset: -379,
                hour: 19,
                minute: 16,
                duration: 2_980,
                distance: 8_900,
                indoor: false
            )
        ]
        .sorted { $0.startDate > $1.startDate }
    }

    static var vo2MaxSamples: [VO2MaxSample] {
        [
            VO2MaxSample(value: 46.8, date: date(dayOffset: -360, hour: 7, minute: 10)),
            VO2MaxSample(value: 47.1, date: date(dayOffset: -318, hour: 7, minute: 18)),
            VO2MaxSample(value: 47.4, date: date(dayOffset: -276, hour: 7, minute: 24)),
            VO2MaxSample(value: 47.9, date: date(dayOffset: -232, hour: 7, minute: 12)),
            VO2MaxSample(value: 48.2, date: date(dayOffset: -188, hour: 7, minute: 30)),
            VO2MaxSample(value: 48.0, date: date(dayOffset: -145, hour: 7, minute: 6)),
            VO2MaxSample(value: 48.7, date: date(dayOffset: -110, hour: 7, minute: 20)),
            VO2MaxSample(value: 49.0, date: date(dayOffset: -80, hour: 7, minute: 14)),
            VO2MaxSample(value: 49.2, date: date(dayOffset: -51, hour: 7, minute: 26)),
            VO2MaxSample(value: 49.6, date: date(dayOffset: -29, hour: 7, minute: 34)),
            VO2MaxSample(value: 48.8, date: date(dayOffset: -12, hour: 7, minute: 10)),
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
