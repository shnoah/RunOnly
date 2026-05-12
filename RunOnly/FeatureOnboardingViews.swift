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
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppMetadata.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .tracking(0.2)

                    Text(L10n.tr("러닝 기록을 한눈에"))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text(L10n.tr("Apple 건강의 러닝, 경로, 심박을 한곳에."))
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                VStack(spacing: 12) {
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
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.29, green: 0.88, blue: 0.63))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequestingPermission)

                    Text("서버 업로드 없음 · 참고용 지표")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)

                    if let permissionErrorMessage {
                        Text(permissionErrorMessage)
                            .font(.caption)
                            .foregroundStyle(Color(red: 1.0, green: 0.73, blue: 0.73))
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
                RunDetailView(
                    run: .demoSample,
                    initialDebugScenario: .completeMetrics
                )
                .environmentObject(workoutsViewModel)
                .environmentObject(shoeStore)
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
                            RunDetailView(
                                run: .demoSample,
                                initialDebugScenario: .completeMetrics
                            )
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
                Text(AppMetadata.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .tracking(0.2)
                    .padding(.horizontal, 4)

                RunReviewStatusCard(
                    title: "러닝 기록이 없습니다",
                    buttonTitle: "새로고침",
                    action: action
                )

                NavigationLink {
                    RunDetailView(
                        run: .demoSample,
                        initialDebugScenario: .completeMetrics
                    )
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
                .foregroundStyle(.white)

            if let message {
                Text(LocalizedStringKey(message))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button(LocalizedStringKey(buttonTitle), action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
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
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(L10n.format("기본 샘플 %@ · %@", sampleDistanceText, RunningWorkout.demoSample.durationText))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text("차트, 지도, 공유 이미지 미리보기")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// 월 이동과 날짜 필터 진입 버튼을 담는 상단 헤더다.
