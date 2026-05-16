import Charts
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 홈 탭은 요약 카드와 최근 상태를 빠르게 보는 대시보드 역할을 맡는다.
struct DashboardHeader: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    let summary: RunningSummary
    let runs: [RunningWorkout]
    let vo2MaxSamples: [VO2MaxSample]
    @EnvironmentObject private var mileageGoalStore: MileageGoalStore
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingGoalEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardBrandHeader()

            Button {
                showingGoalEditor = true
            } label: {
                GoalMileageCard(
                    currentDistanceKilometers: summary.monthDistanceKilometers,
                    goalKilometers: mileageGoalStore.monthlyGoalKilometers
                )
            }
            .buttonStyle(.plain)

            DashboardQuickOverviewPanel(
                viewModel: viewModel,
                summary: summary,
                runs: runs,
                vo2MaxSamples: vo2MaxSamples
            )

            RecentRunsPreviewSection(
                previewRuns: Array(runs.prefix(3)),
                allRuns: runs,
                shoeStore: shoeStore
            )

            if let shoeUsage = latestShoeUsage {
                NavigationLink {
                    ShoeDetailView(shoe: shoeUsage.shoe, runs: runs)
                } label: {
                    RecentShoeUsageCard(usage: shoeUsage)
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                PredictionTrendView(runs: runs)
            } label: {
                PredictionSummaryCard(
                    predicted5KText: summary.predicted5KText,
                    predicted10KText: summary.predicted10KText,
                    predictedHalfText: summary.predictedHalfText,
                    predictedMarathonText: summary.predictedMarathonText
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingGoalEditor) {
            MileageGoalEditorView(currentDistanceKilometers: summary.monthDistanceKilometers)
                .environmentObject(mileageGoalStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color(red: 0.23, green: 0.55, blue: 0.84).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    private var latestShoeUsage: RecentShoeUsage? {
        for run in runs {
            guard let shoe = shoeStore.shoe(for: run.id) else { continue }
            let trackedDistance = shoeStore.distance(for: shoe.id, runs: runs)
            return RecentShoeUsage(shoe: shoe, trackedDistanceKilometers: trackedDistance)
        }

        return nil
    }
}

struct DashboardBrandHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("PNR")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(.white)

            Text("Pace Notes & Records")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct DashboardSectionHeader: View {
    let title: String

    var body: some View {
        Text(LocalizedStringKey(title))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.62))
            .accessibilityAddTraits(.isHeader)
    }
}

struct DashboardQuickOverviewPanel: View {
    @ObservedObject var viewModel: RunningWorkoutsViewModel
    let summary: RunningSummary
    let runs: [RunningWorkout]
    let vo2MaxSamples: [VO2MaxSample]

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink {
                MileageBreakdownView(viewModel: viewModel)
            } label: {
                DashboardCompactSummaryLink(
                    systemImage: "figure.run",
                    title: "올해",
                    value: summary.yearDistanceText,
                    detail: nil,
                    tint: Color(red: 0.42, green: 0.76, blue: 1.0)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                RecoveryReadinessView(readiness: summary.recoveryReadiness)
            } label: {
                DashboardCompactSummaryLink(
                    systemImage: "figure.run.circle.fill",
                    title: "준비도",
                    value: summary.recoveryReadiness.status,
                    detail: nil,
                    tint: Color(red: 0.45, green: 0.95, blue: 0.76),
                    monospacedValue: false
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                VO2MaxTrendView(samples: vo2MaxSamples)
            } label: {
                DashboardCompactSummaryLink(
                    systemImage: "heart.circle.fill",
                    title: "VO2 Max",
                    value: summary.vo2MaxText,
                    detail: nil,
                    tint: Color(red: 0.94, green: 0.41, blue: 0.45)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

struct DashboardCompactSummaryLink: View {
    let systemImage: String
    let title: String
    let value: String
    let detail: String?
    let tint: Color
    var monospacedValue = true

    var body: some View {
        VStack(alignment: .center, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(tint.opacity(0.16))
                    )
                Text(LocalizedStringKey(title))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            valueText
                .frame(height: 31, alignment: .center)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tint.opacity(0.13))
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.13),
                            Color.white.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(title)))
        .accessibilityValue(Text(value))
        .accessibilityHint(Text(detail ?? ""))
    }

    @ViewBuilder
    private var valueText: some View {
        let text = Text(value)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .fixedSize(horizontal: false, vertical: true)

        if monospacedValue {
            text.monospacedDigit()
        } else {
            text
        }
    }
}

struct RecentRunsPreviewSection: View {
    let previewRuns: [RunningWorkout]
    let allRuns: [RunningWorkout]
    let shoeStore: ShoeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DashboardSectionHeader(title: "최근 러닝")
                Spacer()
                NavigationLink {
                    RecentRunsListView(
                        runs: allRuns,
                        shoeStore: shoeStore
                    )
                } label: {
                    Text("전체 보기")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                }
                .buttonStyle(.plain)
            }

            if previewRuns.isEmpty {
                Text("최근 러닝이 쌓이면 여기에 표시됩니다.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.64))
                    .padding(.vertical, 4)
            } else {
                ForEach(previewRuns) { run in
                    NavigationLink {
                        RunDetailView(run: run)
                    } label: {
                        RecentRunCompactRow(run: run)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 2)
    }
}

struct RecentRunsListView: View {
    let runs: [RunningWorkout]
    let shoeStore: ShoeStore

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(runs) { run in
                        NavigationLink {
                            RunDetailView(run: run)
                        } label: {
                            RunRowCard(
                                run: run,
                                shoeDisplay: shoeStore.shoeAssignmentDisplay(for: run.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("최근 러닝")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RecentRunCompactRow: View {
    let run: RunningWorkout

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(compactDateText)
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundStyle(.white.opacity(0.92))
                .monospacedDigit()
                .frame(width: 44, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )

            Text(run.distanceText)
                .font(.system(.headline, design: .rounded).weight(.black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 8)

            Text(run.paceText)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.74))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.36))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(compactDateText))
        .accessibilityValue(Text("\(L10n.tr("거리")) \(run.distanceText), \(L10n.tr("페이스")) \(run.paceText)"))
    }

    private var compactDateText: String {
        let formatter = DateFormatter()
        formatter.locale = RunDisplayFormatter.currentAppLocale
        formatter.timeZone = .current
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: run.startDate)
    }
}

struct RecentShoeUsage: Identifiable {
    let shoe: RunningShoe
    let trackedDistanceKilometers: Double

    var id: UUID { shoe.id }

    var totalKilometers: Double {
        shoe.startMileageKilometers + trackedDistanceKilometers
    }

    var progress: Double {
        min(totalKilometers / max(shoe.retirementKilometers, 1), 1)
    }

    var usagePercentText: String {
        "\(Int((progress * 100).rounded()))%"
    }

    var usageColor: Color {
        progress >= 0.85 ? Color(red: 0.95, green: 0.59, blue: 0.32) : Color(red: 0.29, green: 0.88, blue: 0.63)
    }

    var distanceText: String {
        L10n.format(
            "누적 %@ / 총 %@",
            formatKilometers(totalKilometers),
            formatKilometers(shoe.retirementKilometers)
        )
    }
}

struct RecentShoeUsageCard: View {
    let usage: RecentShoeUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(usage.usageColor.opacity(0.16))
                    Image(systemName: "shoeprints.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(usage.usageColor)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("최근 착용 신발")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                    Text(usage.shoe.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 8)

                Text(usage.usagePercentText)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(usage.usageColor)
                    .monospacedDigit()
            }

            Text(usage.distanceText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            ProgressView(value: usage.progress)
                .tint(usage.usageColor)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.045),
                            usage.usageColor.opacity(0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("최근 착용 신발"))
        .accessibilityValue(Text("\(usage.shoe.displayName), \(usage.distanceText), \(usage.usagePercentText)"))
    }
}

// 공통 요약 카드는 대시보드 전반에서 같은 시각 규칙을 유지한다.
struct GoalMileageCard: View {
    let currentDistanceKilometers: Double
    let goalKilometers: Double
    @EnvironmentObject private var appSettings: AppSettingsStore

    private var progress: Double {
        guard goalKilometers > 0 else { return 0 }
        return min(currentDistanceKilometers / goalKilometers, 1)
    }

    private var headlineText: String {
        let currentText = RunDisplayFormatter.distance(
            kilometers: currentDistanceKilometers,
            preference: appSettings.distanceUnitPreference,
            fractionLength: 1
        )
        let goalText = RunDisplayFormatter.distance(
            kilometers: goalKilometers,
            preference: appSettings.distanceUnitPreference,
            fractionLength: 0
        )
        return "\(currentText) / \(goalText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("목표 마일리지", systemImage: "target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.78, green: 1.0, blue: 0.9))
                Spacer()
                Text("탭해서 수정")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
            }

            Text(headlineText)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: progress)
                .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct MileageGoalEditorView: View {
    let currentDistanceKilometers: Double
    @EnvironmentObject private var mileageGoalStore: MileageGoalStore
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var draftGoalKilometers: Double = 60
    @State private var didLoadInitialValue = false

    private let presetGoals: [Double] = [40, 60, 80, 100, 150]

    private var displayUnit: DisplayDistanceUnit {
        RunDisplayFormatter.resolvedDistanceUnit(for: appSettings.distanceUnitPreference)
    }

    private var displayedGoalBinding: Binding<Double> {
        Binding(
            get: {
                RunDisplayFormatter.displayedDistanceValue(
                    kilometers: draftGoalKilometers,
                    preference: appSettings.distanceUnitPreference
                )
            },
            set: { newValue in
                draftGoalKilometers = max(
                    RunDisplayFormatter.kilometers(
                        fromDisplayedDistance: newValue,
                        preference: appSettings.distanceUnitPreference
                    ),
                    1
                )
            }
        )
    }

    private var minimumGoalValue: Double {
        RunDisplayFormatter.displayedDistanceValue(
            kilometers: 10,
            preference: appSettings.distanceUnitPreference
        )
    }

    private var maximumGoalValue: Double {
        RunDisplayFormatter.displayedDistanceValue(
            kilometers: 500,
            preference: appSettings.distanceUnitPreference
        )
    }

    private var goalProgress: Double {
        min(currentDistanceKilometers / max(draftGoalKilometers, 1), 1)
    }

    private var remainingGoalKilometers: Double {
        max(draftGoalKilometers - currentDistanceKilometers, 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MileageGoalHeroCard(
                        monthText: RunDisplayFormatter.monthOnly(Date()),
                        progress: goalProgress,
                        statusText: goalStatusText,
                        currentDistanceText: displayDistanceText(currentDistanceKilometers),
                        goalDistanceText: displayDistanceText(draftGoalKilometers),
                        remainingDistanceText: displayDistanceText(remainingGoalKilometers)
                    )

                    DetailSection(
                        title: "월간 목표 설정",
                        systemImage: "target",
                        tint: Color(red: 0.29, green: 0.88, blue: 0.63)
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            FeatureFormFieldCard(
                                title: "목표 거리",
                                caption: L10n.format(
                                    "단위는 %@입니다. 원하는 한 달 누적 거리를 바로 조정할 수 있어요.",
                                    displayUnit.distanceInputSuffix
                                ),
                                tint: Color(red: 0.29, green: 0.88, blue: 0.63)
                            ) {
                                HStack(spacing: 10) {
                                    TextField(
                                        L10n.format("월간 목표 거리 (%@)", displayUnit.distanceInputSuffix),
                                        value: displayedGoalBinding,
                                        format: .number.precision(.fractionLength(0...1))
                                    )
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                    Text(displayUnit.distanceInputSuffix)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }

                            FeatureFormFieldCard(
                                title: "미세 조정",
                                caption: L10n.format("%d %@ 단위로 가볍게 올리거나 내릴 수 있어요.", 5, displayUnit.distanceInputSuffix),
                                tint: Color(red: 0.42, green: 0.76, blue: 1.0)
                            ) {
                                Stepper(
                                    value: displayedGoalBinding,
                                    in: minimumGoalValue...maximumGoalValue,
                                    step: 5
                                ) {
                                    HStack {
                                        Text("현재 설정")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.74))
                                        Spacer()
                                        Text(displayDistanceText(draftGoalKilometers))
                                            .font(.system(.headline, design: .rounded).weight(.bold))
                                            .foregroundStyle(.white)
                                            .monospacedDigit()
                                    }
                                }
                                .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
                            }

                            Text("빠른 선택")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 10) {
                                ForEach(presetGoals, id: \.self) { goal in
                                    Button {
                                        draftGoalKilometers = goal
                                    } label: {
                                        Text(
                                            RunDisplayFormatter.distance(
                                                kilometers: goal,
                                                preference: appSettings.distanceUnitPreference,
                                                fractionLength: 0
                                            )
                                        )
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(
                                                        goal == roundedGoal
                                                            ? Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.22)
                                                            : Color.black.opacity(0.18)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                            .stroke(Color.white.opacity(goal == roundedGoal ? 0.1 : 0.06), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(Color(red: 0.42, green: 0.76, blue: 1.0))
                                Text("목표는 이번 달 전체에 공통으로 적용됩니다. 지금은 빠르게 한 달 흐름만 관리하는 방식으로 두었어요.")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.58))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("목표 마일리지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        mileageGoalStore.monthlyGoalKilometers = max(draftGoalKilometers, 1)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            guard !didLoadInitialValue else { return }
            draftGoalKilometers = mileageGoalStore.monthlyGoalKilometers
            didLoadInitialValue = true
        }
    }

    private var roundedGoal: Double {
        draftGoalKilometers.rounded()
    }

    private var goalStatusText: String {
        let remaining = draftGoalKilometers - currentDistanceKilometers
        if remaining > 0 {
            let remainingText = displayDistanceText(remaining)
            return L10n.format("%@ 남음", remainingText)
        }
        return L10n.tr("이미 달성")
    }

    private func displayDistanceText(_ kilometers: Double) -> String {
        RunDisplayFormatter.distance(
            kilometers: kilometers,
            preference: appSettings.distanceUnitPreference,
            fractionLength: 1
        )
    }
}

struct MileageGoalHeroCard: View {
    let monthText: String
    let progress: Double
    let statusText: String
    let currentDistanceText: String
    let goalDistanceText: String
    let remainingDistanceText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FeatureToneBadge(
                    text: "목표",
                    tint: Color(red: 0.29, green: 0.88, blue: 0.63),
                    foreground: Color(red: 0.76, green: 1.0, blue: 0.88)
                )

                Spacer()

                Text(monthText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.54))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("이번 달 페이스를 정리해볼까요")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            ProgressView(value: progress)
                .tint(Color(red: 0.29, green: 0.88, blue: 0.63))

            ViewThatFits(in: .vertical) {
                HStack(spacing: 10) {
                    FeatureMiniStatCard(title: "진행", value: currentDistanceText, tint: Color(red: 0.42, green: 0.76, blue: 1.0))
                    FeatureMiniStatCard(title: "목표", value: goalDistanceText, tint: Color(red: 0.29, green: 0.88, blue: 0.63))
                    FeatureMiniStatCard(title: "남은 거리", value: remainingDistanceText, tint: Color(red: 0.95, green: 0.59, blue: 0.32))
                }

                VStack(spacing: 10) {
                    FeatureMiniStatCard(title: "진행", value: currentDistanceText, tint: Color(red: 0.42, green: 0.76, blue: 1.0))
                    FeatureMiniStatCard(title: "목표", value: goalDistanceText, tint: Color(red: 0.29, green: 0.88, blue: 0.63))
                    FeatureMiniStatCard(title: "남은 거리", value: remainingDistanceText, tint: Color(red: 0.95, green: 0.59, blue: 0.32))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.18, blue: 0.16),
                            Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.18),
                            Color(red: 0.42, green: 0.76, blue: 1.0).opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
        )
    }
}

// 레이스 거리별 예측 기록을 한 카드 안에 묶는다.
struct PredictionSummaryCard: View {
    let predicted5KText: String
    let predicted10KText: String
    let predictedHalfText: String
    let predictedMarathonText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("예상 완주 기록", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.76))
                Spacer()
            }

            HStack(spacing: 6) {
                PredictionCell(title: "5K", value: predicted5KText)
                PredictionCell(title: "10K", value: predicted10KText)
                PredictionCell(title: PredictionDistance.half.label, value: predictedHalfText)
                PredictionCell(title: PredictionDistance.marathon.label, value: predictedMarathonText)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.045),
                            Color(red: 0.95, green: 0.59, blue: 0.32).opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// 예측 기록 카드의 개별 셀이다.
struct PredictionCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}
