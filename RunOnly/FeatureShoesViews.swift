import Charts
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 홈 탭은 요약 카드와 최근 상태를 빠르게 보는 대시보드 역할을 맡는다.
struct ShoesTabView: View {
    let runs: [RunningWorkout]
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingAddShoe = false

    private var samplePreviewItems: [SampleShoePreview] {
        SampleShoePreview.items
    }

    private var totalTrackedDistance: Double {
        shoeStore.shoes.reduce(0) { partial, shoe in
            partial + shoeStore.distance(for: shoe.id, runs: runs)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ShoesOverviewHeaderCard(
                        shoeCount: shoeStore.shoes.count,
                        totalTrackedDistance: totalTrackedDistance
                    ) {
                        showingAddShoe = true
                    }

                    if shoeStore.shoes.isEmpty {
                        DetailSection(title: "러닝화 추가하기", systemImage: "shoeprints.fill", tint: Color(red: 0.91, green: 0.69, blue: 0.38)) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("러닝화를 등록하면 신발별 누적 거리와 남은 수명을 볼 수 있습니다.")
                                    .foregroundStyle(.white.opacity(0.72))
                                Text("아래 샘플 카드에서 어떤 식으로 관리되는지 먼저 볼 수 있습니다.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                        }

                        DetailSection(title: "샘플 미리보기", systemImage: "sparkles", tint: Color(red: 0.95, green: 0.59, blue: 0.32)) {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(samplePreviewItems) { item in
                                    ShoeSummaryCard(
                                        shoe: item.shoe,
                                        distanceKilometers: item.distanceKilometers
                                    )
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 14) {
                            ForEach(shoeStore.shoes) { shoe in
                                NavigationLink {
                                    ShoeDetailView(shoe: shoe, runs: runs)
                                } label: {
                                    ShoeSummaryCard(
                                        shoe: shoe,
                                        distanceKilometers: shoeStore.distance(for: shoe.id, runs: runs)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 104)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddShoe) {
                AddShoeView()
                    .environmentObject(shoeStore)
            }
        }
    }
}

// 설정 탭은 실제 설정과 안내성 화면 진입점을 분리해 보여준다.
struct SampleShoePreview: Identifiable {
    let id = UUID()
    let shoe: RunningShoe
    let distanceKilometers: Double

    static let items: [SampleShoePreview] = [
        SampleShoePreview(
            shoe: RunningShoe(
                nickname: "데일리 러너",
                brand: "브랜드 A",
                model: "트레이너 01",
                startMileageKilometers: 552.0,
                retirementKilometers: 600
            ),
            distanceKilometers: 7.6
        ),
        SampleShoePreview(
            shoe: RunningShoe(
                nickname: "스피드 페어",
                brand: "브랜드 B",
                model: "레이서 02",
                startMileageKilometers: 220.0,
                retirementKilometers: 600
            ),
            distanceKilometers: 35.8
        )
    ]
}

struct ShoesOverviewHeaderCard: View {
    let shoeCount: Int
    let totalTrackedDistance: Double
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    FeatureToneBadge(
                        text: "러닝화",
                        tint: Color(red: 0.91, green: 0.69, blue: 0.38),
                        foreground: Color(red: 1.0, green: 0.9, blue: 0.76)
                    )

                    Text(titleText)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.74))
                }

                Spacer(minLength: 12)

                Button("추가", action: onAdd)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.18))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .buttonStyle(.plain)
            }

            if shoeCount > 0 {
                HStack(spacing: 10) {
                    ShoesOverviewMetric(title: "보유", value: L10n.format("%d켤레", shoeCount))
                    ShoesOverviewMetric(title: "추적 거리", value: formatKilometers(totalTrackedDistance))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color(red: 0.84, green: 0.63, blue: 0.3).opacity(0.2)
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

    private var titleText: String {
        if shoeCount == 0 {
            return L10n.tr("러닝화를 등록해보세요")
        }

        return L10n.format("%d켤레를 관리하고 있어요", shoeCount)
    }

    private var subtitleText: String {
        if shoeCount == 0 {
            return L10n.tr("누적 거리와 교체 시점을 더 쉽게 볼 수 있어요")
        }

        return L10n.format("현재 추적 거리 %@", formatKilometers(totalTrackedDistance))
    }
}

struct ShoesOverviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// 신발 목록 카드 하나는 누적 거리와 교체까지 남은 거리를 요약한다.
struct ShoeSummaryCard: View {
    let shoe: RunningShoe
    let distanceKilometers: Double

    private var totalKilometers: Double {
        shoe.startMileageKilometers + distanceKilometers
    }

    private var usageRatio: Double {
        min(totalKilometers / max(shoe.retirementKilometers, 1), 1)
    }

    private var usagePercentText: String {
        "\(Int((usageRatio * 100).rounded()))%"
    }

    private var usageColor: Color {
        usageRatio >= 0.85 ? .orange : Color(red: 0.29, green: 0.88, blue: 0.63)
    }

    private var distanceSummaryText: String {
        L10n.format(
            "누적 %@ / 총 %@",
            formatKilometers(totalKilometers),
            formatKilometers(shoe.retirementKilometers)
        )
    }

    private var compactMetricsText: String {
        L10n.format(
            "누적 %@ · 총 %@ · 사용률 %@",
            formatKilometers(totalKilometers),
            formatKilometers(shoe.retirementKilometers),
            usagePercentText
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    usageColor.opacity(0.28),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "shoeprints.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(shoe.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(distanceSummaryText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(usagePercentText)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(usageColor)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.38))
            }

            ProgressView(value: usageRatio)
                .tint(usageColor)
        }
        .frame(minHeight: 88)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            usageColor.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 12, y: 6)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(shoe.displayName))
        .accessibilityValue(Text(compactMetricsText))
        .accessibilityHint(Text("탭하면 신발 상세 정보를 볼 수 있습니다."))
    }
}

// 신발 상세 화면은 연결된 러닝 목록과 현재 사용량을 보여준다.
struct ShoeDetailView: View {
    let shoe: RunningShoe
    let runs: [RunningWorkout]
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingEditSheet = false

    private var currentShoe: RunningShoe {
        shoeStore.shoes.first(where: { $0.id == shoe.id }) ?? shoe
    }

    private var assignedRuns: [RunningWorkout] {
        shoeStore.runs(for: currentShoe.id, in: runs)
    }

    private var totalKilometers: Double {
        currentShoe.startMileageKilometers + assignedRuns.reduce(0) { $0 + $1.distanceInKilometers }
    }

    private var remainingKilometers: Double {
        max(currentShoe.retirementKilometers - totalKilometers, 0)
    }

    private var usageRatio: Double {
        min(totalKilometers / max(currentShoe.retirementKilometers, 1), 1)
    }

    private var usagePercentText: String {
        "\(Int((usageRatio * 100).rounded()))%"
    }

    private var usageColor: Color {
        usageRatio >= 0.85 ? Color(red: 0.95, green: 0.59, blue: 0.32) : Color(red: 0.29, green: 0.88, blue: 0.63)
    }

    private var usageStateText: String {
        if usageRatio >= 1 {
            return "교체 시점을 넘겼어요"
        }
        if usageRatio >= 0.85 {
            return "교체를 슬슬 생각해볼 시점이에요"
        }
        return "아직 여유 있게 쓰고 있어요"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ShoeDetailHeroCard(
                    shoeName: currentShoe.displayName,
                    brandModelText: currentShoe.brandModelText,
                    usageStateText: usageStateText,
                    usagePercentText: usagePercentText,
                    progress: usageRatio,
                    tint: usageColor,
                    totalDistanceText: formatKilometers(totalKilometers),
                    remainingDistanceText: formatKilometers(remainingKilometers),
                    runsText: L10n.format("%d회", assignedRuns.count)
                )

                DetailSection(
                    title: "최근 착용 러닝",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    tint: usageColor
                ) {
                    if assignedRuns.isEmpty {
                        Text("이 신발에 연결된 러닝이 없습니다.")
                            .foregroundStyle(.white.opacity(0.72))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(assignedRuns.prefix(10)) { run in
                                ShoeDetailRunRow(run: run)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle(currentShoe.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("수정") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddShoeView(existingShoe: currentShoe)
                .environmentObject(shoeStore)
        }
    }
}

struct ShoeDetailHeroCard: View {
    let shoeName: String
    let brandModelText: String
    let usageStateText: String
    let usagePercentText: String
    let progress: Double
    let tint: Color
    let totalDistanceText: String
    let remainingDistanceText: String
    let runsText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FeatureToneBadge(
                    text: "러닝화",
                    tint: Color(red: 0.91, green: 0.69, blue: 0.38),
                    foreground: Color(red: 1.0, green: 0.9, blue: 0.72)
                )

                Spacer()

                FeatureToneBadge(
                    text: usagePercentText,
                    tint: tint,
                    foreground: .white
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(shoeName)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(brandModelText.isEmpty ? "러닝 흐름과 사용량을 한눈에 볼 수 있어요." : brandModelText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))

                Text(usageStateText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.58))
            }

            ProgressView(value: progress)
                .tint(tint)

            ViewThatFits(in: .vertical) {
                HStack(spacing: 10) {
                    FeatureMiniStatCard(title: "누적 거리", value: totalDistanceText, tint: Color(red: 0.42, green: 0.76, blue: 1.0))
                    FeatureMiniStatCard(title: "남은 거리", value: remainingDistanceText, tint: tint)
                    FeatureMiniStatCard(title: "착용 러닝", value: runsText, tint: Color(red: 0.91, green: 0.69, blue: 0.38))
                }

                VStack(spacing: 10) {
                    FeatureMiniStatCard(title: "누적 거리", value: totalDistanceText, tint: Color(red: 0.42, green: 0.76, blue: 1.0))
                    FeatureMiniStatCard(title: "남은 거리", value: remainingDistanceText, tint: tint)
                    FeatureMiniStatCard(title: "착용 러닝", value: runsText, tint: Color(red: 0.91, green: 0.69, blue: 0.38))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.16, blue: 0.22),
                            tint.opacity(0.18),
                            Color(red: 0.91, green: 0.69, blue: 0.38).opacity(0.16)
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

struct ShoeDetailRunRow: View {
    let run: RunningWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(run.recordCompactDateText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.52))
                }

                Spacer()

                Text(run.paceText)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                ShoeDetailMetaPill(text: run.distanceText)
                ShoeDetailMetaPill(text: run.durationText)

                if !run.environmentShortText.isEmpty {
                    ShoeDetailMetaPill(text: run.environmentShortText)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct ShoeDetailMetaPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.76))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
    }
}

// 신발 추가/수정 폼은 최소 정보만 받아 빠르게 관리할 수 있게 한다.
struct AddShoeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var shoeStore: ShoeStore
    @EnvironmentObject private var appSettings: AppSettingsStore

    let existingShoe: RunningShoe?

    @State private var nickname: String
    @State private var brand: String
    @State private var model: String
    @State private var startMileage: Double
    @State private var retirementMileage: Double

    init(existingShoe: RunningShoe? = nil) {
        self.existingShoe = existingShoe
        _nickname = State(initialValue: existingShoe?.nickname ?? "")
        _brand = State(initialValue: existingShoe?.brand ?? "")
        _model = State(initialValue: existingShoe?.model ?? "")
        _startMileage = State(initialValue: existingShoe?.startMileageKilometers ?? 0)
        _retirementMileage = State(initialValue: existingShoe?.retirementKilometers ?? 600)
    }

    private var displayUnit: DisplayDistanceUnit {
        RunDisplayFormatter.resolvedDistanceUnit(for: appSettings.distanceUnitPreference)
    }

    private var startMileageBinding: Binding<Double> {
        Binding(
            get: {
                RunDisplayFormatter.displayedDistanceValue(
                    kilometers: startMileage,
                    preference: appSettings.distanceUnitPreference
                )
            },
            set: { newValue in
                startMileage = max(
                    RunDisplayFormatter.kilometers(
                        fromDisplayedDistance: newValue,
                        preference: appSettings.distanceUnitPreference
                    ),
                    0
                )
            }
        )
    }

    private var retirementMileageBinding: Binding<Double> {
        Binding(
            get: {
                RunDisplayFormatter.displayedDistanceValue(
                    kilometers: retirementMileage,
                    preference: appSettings.distanceUnitPreference
                )
            },
            set: { newValue in
                retirementMileage = max(
                    RunDisplayFormatter.kilometers(
                        fromDisplayedDistance: newValue,
                        preference: appSettings.distanceUnitPreference
                    ),
                    1
                )
            }
        )
    }

    private var recommendedRetirementRangeText: String {
        let lower = RunDisplayFormatter.distance(
            kilometers: 500,
            preference: appSettings.distanceUnitPreference,
            fractionLength: 0
        )
        let upper = RunDisplayFormatter.distance(
            kilometers: 800,
            preference: appSettings.distanceUnitPreference,
            fractionLength: 0
        )
        return "\(lower) - \(upper)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AddShoeHeroCard(
                        isEditing: existingShoe != nil,
                        recommendedRetirementRangeText: recommendedRetirementRangeText
                    )

                    DetailSection(
                        title: "기본 정보",
                        systemImage: "shoeprints.fill",
                        tint: Color(red: 0.91, green: 0.69, blue: 0.38)
                    ) {
                        VStack(spacing: 12) {
                            FeatureFormFieldCard(
                                title: "별칭",
                                caption: "기록 목록에서 가장 먼저 보여줄 이름이에요.",
                                tint: Color(red: 0.91, green: 0.69, blue: 0.38)
                            ) {
                                TextField("예: 롱런용", text: $nickname)
                                    .textFieldStyle(.plain)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(.white)
                            }

                            FeatureFormFieldCard(
                                title: "브랜드",
                                caption: "선택 사항이지만 나중에 신발을 구분하기 쉬워져요.",
                                tint: Color(red: 0.42, green: 0.76, blue: 1.0)
                            ) {
                                TextField("예: Nike", text: $brand)
                                    .textFieldStyle(.plain)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                            }

                            FeatureFormFieldCard(
                                title: "모델",
                                caption: "브랜드와 함께 적어두면 컬렉션처럼 보기 좋아요.",
                                tint: Color(red: 0.29, green: 0.88, blue: 0.63)
                            ) {
                                TextField("예: Zoom Fly 6", text: $model)
                                    .textFieldStyle(.plain)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    DetailSection(
                        title: "마일리지",
                        systemImage: "gauge.with.dots.needle.bottom.50percent",
                        tint: Color(red: 0.42, green: 0.76, blue: 1.0)
                    ) {
                        VStack(spacing: 12) {
                            FeatureFormFieldCard(
                                title: "시작 거리",
                                caption: L10n.format(
                                    "단위는 %@입니다. 새 신발이면 0으로 두고, 이미 사용 중이면 누적 거리를 이어서 적어주세요.",
                                    displayUnit.distanceInputSuffix
                                ),
                                tint: Color(red: 0.42, green: 0.76, blue: 1.0)
                            ) {
                                HStack(spacing: 10) {
                                    TextField(
                                        L10n.format("시작 거리 (%@)", displayUnit.distanceInputSuffix),
                                        value: startMileageBinding,
                                        format: .number.precision(.fractionLength(0...1))
                                    )
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(.white)

                                    Text(displayUnit.distanceInputSuffix)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }

                            FeatureFormFieldCard(
                                title: "교체 기준 거리",
                                caption: L10n.format(
                                    "보통 %@ 범위에서 잡습니다. 달리는 감각에 맞게 조금 넉넉하게 잡아도 괜찮아요.",
                                    recommendedRetirementRangeText
                                ),
                                tint: Color(red: 0.95, green: 0.59, blue: 0.32)
                            ) {
                                HStack(spacing: 10) {
                                    TextField(
                                        L10n.format("목표 수명 거리 (%@)", displayUnit.distanceInputSuffix),
                                        value: retirementMileageBinding,
                                        format: .number.precision(.fractionLength(0...1))
                                    )
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(.white)

                                    Text(displayUnit.distanceInputSuffix)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle(existingShoe == nil ? L10n.tr("신발 추가") : L10n.tr("신발 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(existingShoe == nil ? L10n.tr("저장") : L10n.tr("완료")) {
                        let updatedShoe = RunningShoe(
                            id: existingShoe?.id ?? UUID(),
                            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                            startMileageKilometers: max(startMileage, 0),
                            retirementKilometers: max(retirementMileage, 1),
                            createdAt: existingShoe?.createdAt ?? .now
                        )

                        if existingShoe == nil {
                            shoeStore.addShoe(updatedShoe)
                        } else {
                            shoeStore.updateShoe(updatedShoe)
                        }
                        dismiss()
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct AddShoeHeroCard: View {
    let isEditing: Bool
    let recommendedRetirementRangeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FeatureToneBadge(
                    text: isEditing ? "수정" : "새 러닝화",
                    tint: Color(red: 0.91, green: 0.69, blue: 0.38),
                    foreground: Color(red: 1.0, green: 0.9, blue: 0.72)
                )

                Spacer()

                FeatureToneBadge(
                    text: "권장 수명",
                    tint: Color(red: 0.42, green: 0.76, blue: 1.0),
                    foreground: Color(red: 0.74, green: 0.9, blue: 1.0)
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(isEditing ? "러닝화를 더 알아보기 쉽게 다듬어요" : "새 러닝화를 가볍게 등록해둘까요")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("교체 기준은 보통 \(recommendedRetirementRangeText) 안에서 잡으면 무난해요.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.17, blue: 0.23),
                            Color(red: 0.91, green: 0.69, blue: 0.38).opacity(0.18),
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

// 마일리지 화면은 월별/연별 누적 거리를 한곳에 모아 보여준다.
