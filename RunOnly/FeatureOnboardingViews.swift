import Charts
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 홈 탭은 요약 카드와 최근 상태를 빠르게 보는 대시보드 역할을 맡는다.
struct HealthKitOnboardingView: View {
    let showsDismissButton: Bool
    let onContinue: () async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutsViewModel: RunningWorkoutsViewModel
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingSampleRun = false
    @State private var isRequestingPermission = false
    @State private var permissionErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("PNR")
                        .font(.system(size: 58, weight: .black, design: .rounded))
                        .foregroundStyle(PNR2026.ink)
                        .lineLimit(1)

                    Text(L10n.tr("Apple Watch 러닝을 읽기 쉬운 로그로 바꿉니다."))
                        .font(.system(size: 29, weight: .black, design: .rounded))
                        .foregroundStyle(PNR2026.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 8) {
                        OnboardingSignalRow(systemImage: "figure.run", title: "러닝 기록", detail: "거리, 시간, 페이스를 먼저 정리")
                        OnboardingSignalRow(systemImage: "heart.fill", title: "몸 상태", detail: "심박, 노력, 준비도는 참고 지표로 표시")
                        OnboardingSignalRow(systemImage: "shoeprints.fill", title: "로컬 관리", detail: "신발과 보조 데이터는 iPhone 안에 저장")
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    PNR2026.track.opacity(0.14),
                                    PNR2026.water.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                                .stroke(PNR2026.line, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 18)

                VStack(spacing: 10) {
                    Button {
                        showingSampleRun = true
                    } label: {
                        DemoRunAccessCard()
                    }
                    .buttonStyle(.plain)

                    Button {
                        guard !isRequestingPermission else { return }
                        permissionErrorMessage = nil
                        isRequestingPermission = true
                        Task { @MainActor in
                            do {
                                try await onContinue()
                                if showsDismissButton {
                                    dismiss()
                                }
                            } catch {
                                permissionErrorMessage = error.localizedDescription
                            }
                            isRequestingPermission = false
                        }
                    } label: {
                        Text(
                            isRequestingPermission
                                ? L10n.tr("권한 요청 중")
                                : L10n.tr("Apple 건강 권한 허용하고 시작")
                        )
                            .font(.headline.weight(.black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                                    .fill(PNR2026.track)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequestingPermission)

                    Text("서버 업로드 없음 · 참고용 지표")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PNR2026.muted)
                        .frame(maxWidth: .infinity)

                    if let permissionErrorMessage {
                        Text(permissionErrorMessage)
                            .font(.caption)
                            .foregroundStyle(PNR2026.rose)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(AppBackground())
        .navigationTitle(L10n.tr("Apple 건강 안내"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingSampleRun) {
            NavigationStack {
                RunDetailView(run: .demoSample)
                .environmentObject(workoutsViewModel)
                .environmentObject(shoeStore)
            }
        }
    }
}

private struct OnboardingSignalRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(PNR2026.track)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: PNR2026.radius, style: .continuous)
                        .fill(PNR2026.track.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(PNR2026.ink)
                Text(LocalizedStringKey(detail))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PNR2026.muted)
            }
        }
    }
}

struct RunReviewFallbackView: View {
    let title: String
    let message: String?
    let buttonTitle: String
    let action: () -> Void

    init(title: String, message: String? = nil, buttonTitle: String, action: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RunReviewStatusCard(
                    title: title,
                    message: message,
                    buttonTitle: buttonTitle,
                    action: action
                )

                DetailSection(title: "샘플 러닝으로 둘러보기", systemImage: "sparkles", tint: Color(red: 0.95, green: 0.59, blue: 0.32)) {
                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink {
                            RunDetailView(run: .demoSample)
                        } label: {
                            DemoRunAccessCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 104)
        }
    }
}

struct HomeEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PNRPageHeader(
                    eyebrow: "PNR",
                    title: "러닝 기록이 없습니다",
                    subtitle: "권한을 다시 확인하거나 샘플 러닝으로 화면 흐름을 먼저 볼 수 있습니다."
                )

                RunReviewStatusCard(
                    title: "러닝 기록이 없습니다",
                    buttonTitle: "새로고침",
                    action: action
                )

                NavigationLink {
                    RunDetailView(run: .demoSample)
                } label: {
                    DemoRunAccessCard()
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .padding(.bottom, 104)
        }
    }
}

struct RunReviewStatusCard: View {
    let title: String
    let message: String?
    let buttonTitle: String
    let action: () -> Void

    init(title: String, message: String? = nil, buttonTitle: String, action: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(.title3.weight(.semibold))
                .foregroundStyle(PNR2026.ink)

            if let message {
                Text(LocalizedStringKey(message))
                    .font(.body)
                    .foregroundStyle(PNR2026.muted)
                    .multilineTextAlignment(.center)
            }

            Button(LocalizedStringKey(buttonTitle), action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
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

struct DemoRunAccessCard: View {
    private var sampleDistanceText: String {
        RunDisplayFormatter.distance(
            meters: RunningWorkout.demoSample.distanceInMeters,
            fractionLength: 2
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("샘플 러닝 열기")
                        .font(.headline.weight(.black))
                        .foregroundStyle(PNR2026.ink)
                    Text(L10n.format("기본 샘플 %@ · %@", sampleDistanceText, RunningWorkout.demoSample.durationText))
                        .font(.subheadline)
                        .foregroundStyle(PNR2026.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(PNR2026.muted)
            }

            Text("차트, 지도, 공유 이미지 미리보기")
                .font(.footnote)
                .foregroundStyle(PNR2026.muted)
                .lineLimit(2)
        }
        .padding(14)
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

// 월 이동과 날짜 필터 진입 버튼을 담는 상단 헤더다.
