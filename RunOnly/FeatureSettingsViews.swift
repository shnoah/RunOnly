import Charts
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 홈 탭은 요약 카드와 최근 상태를 빠르게 보는 대시보드 역할을 맡는다.
struct SettingsTabView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsOverviewHeaderCard()

                    DetailSection(title: "표시", systemImage: "paintbrush.pointed.fill", tint: Color(red: 0.42, green: 0.76, blue: 1.0)) {
                        VStack(spacing: 10) {
                            NavigationLink {
                                AppLanguageSettingsView()
                            } label: {
                                SettingSelectionRow(
                                    title: "앱 언어",
                                    value: appSettings.appLanguagePreference.label,
                                    detail: "문구와 날짜"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                DistanceUnitSettingsView()
                            } label: {
                                SettingSelectionRow(
                                    title: "거리 단위",
                                    value: appSettings.distanceUnitPreference.label,
                                    detail: "거리와 페이스"
                                )
                            }
                            .buttonStyle(.plain)

                            Toggle(isOn: $appSettings.defaultAppleOnlyFilter) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Apple 운동 앱 기록 기본 표시")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("홈/기록 기본 필터")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.58))
                                }
                            }
                            .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
                        }
                    }

                    DetailSection(title: "데이터", systemImage: "externaldrive.fill", tint: Color(red: 0.29, green: 0.88, blue: 0.63)) {
                        VStack(spacing: 10) {
                            NavigationLink {
                                DataPermissionsView()
                            } label: {
                                SettingLinkRow(
                                    systemImage: "heart.text.square",
                                    title: "데이터 및 권한",
                                    detail: "건강 권한"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                ShoeDataSettingsView()
                            } label: {
                                SettingLinkRow(
                                    systemImage: "shoeprints.fill",
                                    title: "신발 데이터",
                                    detail: "백업/가져오기"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                DataManagementView()
                            } label: {
                                SettingLinkRow(
                                    systemImage: "externaldrive.fill.badge.xmark",
                                    title: "데이터 관리",
                                    detail: "삭제/초기화"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    DetailSection(title: "지원", systemImage: "lifepreserver.fill", tint: Color(red: 0.95, green: 0.59, blue: 0.32)) {
                        VStack(spacing: 10) {
                            NavigationLink {
                                PrivacyPolicyView()
                            } label: {
                                SettingLinkRow(
                                    systemImage: "lock.doc.fill",
                                    title: "개인정보처리방침",
                                    detail: "읽는 데이터"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                SupportCenterView()
                            } label: {
                                SettingLinkRow(
                                    systemImage: "envelope.fill",
                                    title: "지원 및 문의",
                                    detail: "메일/링크"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(AppMetadata.versionText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.42))
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
                .padding(.bottom, 104)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingsOverviewHeaderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FeatureToneBadge(
                text: "설정",
                tint: Color(red: 0.42, green: 0.76, blue: 1.0),
                foreground: Color(red: 0.82, green: 0.94, blue: 1.0)
            )

            Text("설정")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            Text("표시, 데이터, 지원")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.74))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color(red: 0.26, green: 0.48, blue: 0.84).opacity(0.18)
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

struct SettingsOverviewPill: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.52))
            Text(LocalizedStringKey(detail))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
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

// 개인정보처리방침은 앱 안에서도 바로 읽을 수 있게 별도 화면으로 제공한다.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "개요", systemImage: "doc.text.fill", tint: Color(red: 0.42, green: 0.76, blue: 1.0)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.format("%@은 Apple 건강의 러닝 데이터를 iPhone에서 보기 쉽게 정리하는 앱입니다.", AppMetadata.displayName))
                        Text(AppMetadata.healthUsageSummary)
                        Text("계정 생성, 광고 추적, 외부 분석 SDK 없이 동작하며, 현재는 서버로 데이터를 업로드하지 않습니다.")
                        Text(L10n.format("Apple 건강 권한은 언제든 %@에서 다시 변경할 수 있습니다.", AppMetadata.healthPermissionSettingsPath))
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "읽는 건강 데이터", systemImage: "heart.text.square.fill", tint: Color(red: 0.29, green: 0.88, blue: 0.63)) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(AppMetadata.healthDataSummaryItems, id: \.self) { item in
                            Text("• \(item)")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "저장 및 보호", systemImage: "lock.shield.fill", tint: Color(red: 0.42, green: 0.76, blue: 1.0)) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AppMetadata.privacyStorageHighlights, id: \.self) { item in
                            Text(item)
                        }
                        Text("신발 데이터, 설정값, PR 계산 결과와 평균 심박/평균 케이던스/상승 고도 같은 보조 분석 데이터는 기기 내부 저장소에만 저장됩니다.")
                        Text("신발 백업 파일은 사용자가 직접 공유 버튼을 눌렀을 때만 외부 앱으로 전달됩니다.")
                        Text("앱을 삭제하면 앱 내부에 저장한 보조 데이터와 설정도 함께 제거됩니다.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "고지", systemImage: "exclamationmark.bubble.fill", tint: Color(red: 0.94, green: 0.41, blue: 0.45)) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AppMetadata.nonMedicalNoticeLines, id: \.self) { item in
                            Text(item)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }

                DetailSection(title: "문의", systemImage: "envelope.fill", tint: Color(red: 0.95, green: 0.59, blue: 0.32)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Link("지원 메일 보내기", destination: AppMetadata.supportMailURL)
                            .font(.subheadline.weight(.semibold))
                        Link("웹 개인정보처리방침 열기", destination: AppMetadata.privacyPolicyURL)
                            .font(.subheadline.weight(.semibold))
                        Link("프로젝트 저장소 열기", destination: AppMetadata.repositoryURL)
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("개인정보처리방침")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 지원 화면은 문의 방법과 전달하면 좋은 정보를 함께 안내한다.
struct SupportCenterView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "문의 방법", systemImage: "envelope.fill", tint: Color(red: 0.95, green: 0.59, blue: 0.32)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Link("메일로 문의하기", destination: AppMetadata.supportMailURL)
                            .font(.subheadline.weight(.semibold))
                        Link("웹 개인정보처리방침 열기", destination: AppMetadata.privacyPolicyURL)
                            .font(.subheadline.weight(.semibold))
                        Link("프로젝트 저장소 열기", destination: AppMetadata.repositoryURL)
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
                }

                DetailSection(title: "함께 보내주면 좋은 정보", systemImage: "checklist", tint: Color(red: 0.42, green: 0.76, blue: 1.0)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("• 사용 중인 iPhone 모델과 iOS 버전")
                        Text("• 문제가 발생한 러닝 날짜와 화면")
                        Text("• 재현 순서와 스크린샷")
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("지원 및 문의")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataPermissionsView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "데이터 및 권한", systemImage: "heart.text.square.fill", tint: Color(red: 0.29, green: 0.88, blue: 0.63)) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppMetadata.healthUsageSummary)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.78))

                        SettingInfoRow(title: L10n.tr("권한"), value: L10n.tr("Apple 건강 읽기"))
                        SettingInfoRow(title: "네트워크 업로드", value: "없음")
                        SettingInfoRow(title: "파생 분석 캐시", value: "기기 내부 전용 저장소")
                        SettingInfoRow(title: "권한 변경", value: AppMetadata.healthPermissionSettingsPath)
                        SettingInfoRow(title: "앱 삭제 시", value: "로컬 보조 데이터 함께 제거")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("읽는 데이터")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                            ForEach(AppMetadata.healthDataSummaryItems, id: \.self) { item in
                                Text("• \(item)")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        }

                        Text(L10n.tr("이 앱은 Apple 건강 데이터 중 러닝과 관련된 항목만 읽습니다. 평균 심박, 평균 케이던스, 상승 고도 같은 요약값은 상세 화면을 더 빠르게 보여주기 위해 기기 내부에만 저장하며 서버로 업로드하지 않습니다."))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.62))

                        Button {
                            appSettings.presentHealthKitIntro()
                        } label: {
                            HStack {
                                Image(systemName: "heart.text.square")
                                Text(L10n.tr("Apple 건강 안내 다시 보기"))
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                DetailSection(title: "고지", systemImage: "exclamationmark.bubble.fill", tint: Color(red: 0.94, green: 0.41, blue: 0.45)) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(AppMetadata.nonMedicalNoticeLines, id: \.self) { item in
                            Text(item)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.66))
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("데이터 및 권한")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShoeDataSettingsView: View {
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var backupURL: URL?
    @State private var backupErrorMessage: String?
    @State private var backupStatusMessage: String?
    @State private var showingImportOptions = false
    @State private var showingBackupImporter = false
    @State private var selectedImportStrategy: ShoeImportStrategy = .merge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "신발 백업 및 복원", systemImage: "shippingbox.fill", tint: Color(red: 0.91, green: 0.69, blue: 0.38)) {
                    VStack(spacing: 14) {
                        SettingInfoRow(title: "저장 위치", value: "iPhone 내부 전용 저장소")
                        SettingInfoRow(title: "자동 백업", value: "자동 iCloud/Finder 백업 제외")
                        SettingInfoRow(title: "기기 간 자동 동기화", value: "현재 지원 안 함")
                        SettingInfoRow(title: "백업 포함 범위", value: "신발 정보 + 러닝 UUID 연결")

                        Text(L10n.tr("백업 파일에는 신발 이름, 브랜드/모델, 시작 거리, 목표 수명, 생성일과 러닝 UUID 연결만 들어갑니다. 심박, 경로, 페이스 같은 Apple 건강 원본 데이터는 포함되지 않습니다. 러닝 연결은 같은 workout UUID가 있는 기기에서 가장 잘 복원됩니다."))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.62))

                        Button {
                            do {
                                backupURL = try shoeStore.exportBackupFile()
                                backupErrorMessage = nil
                                backupStatusMessage = L10n.tr("백업 파일을 준비했습니다.")
                            } catch {
                                backupErrorMessage = error.localizedDescription
                            }
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("신발 데이터 백업 파일 준비")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingImportOptions = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("신발 데이터 가져오기")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)

                        if let backupURL {
                            ShareLink(item: backupURL) {
                                HStack {
                                    Image(systemName: "paperplane")
                                    Text("백업 파일 공유")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        }

                        if let backupStatusMessage {
                            Text(backupStatusMessage)
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                        }

                        if let backupErrorMessage {
                            Text(backupErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("신발 데이터")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("가져오기 방식", isPresented: $showingImportOptions, titleVisibility: .visible) {
            Button("병합 가져오기") {
                selectedImportStrategy = .merge
                showingBackupImporter = true
            }
            Button("기존 데이터로 교체", role: .destructive) {
                selectedImportStrategy = .replace
                showingBackupImporter = true
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("병합은 같은 ID만 갱신하고 나머지는 유지합니다. 교체는 현재 신발 데이터와 연결 정보를 백업 파일 내용으로 바꿉니다.")
        }
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let summary = try shoeStore.importBackupFile(from: url, strategy: selectedImportStrategy)
                backupErrorMessage = nil
                backupStatusMessage = summary.message
                backupURL = nil
            } catch {
                backupErrorMessage = error.localizedDescription
            }
        }
    }
}

struct DataManagementView: View {
    @EnvironmentObject private var shoeStore: ShoeStore
    @State private var showingDeleteShoeDataConfirmation = false
    @State private var showingDeleteAnalysisCacheConfirmation = false
    @State private var analysisCacheStatusMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "데이터 관리", systemImage: "externaldrive.fill.badge.xmark", tint: Color(red: 0.94, green: 0.41, blue: 0.45)) {
                    VStack(spacing: 14) {
                        Button(role: .destructive) {
                            showingDeleteShoeDataConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("기존 신발데이터 삭제")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.red.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            showingDeleteAnalysisCacheConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("분석 캐시 초기화")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.red.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)

                        if let statusMessage {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
                        }

                        if let analysisCacheStatusMessage {
                            Text(analysisCacheStatusMessage)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("데이터 관리")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("기존 신발데이터 삭제", isPresented: $showingDeleteShoeDataConfirmation, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                shoeStore.clearAllData()
                statusMessage = L10n.tr("기존 신발데이터를 삭제했습니다.")
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text(L10n.tr("등록한 신발 정보와 러닝 연결 정보가 모두 삭제됩니다. Apple 건강 원본 러닝 데이터는 삭제되지 않습니다."))
        }
        .confirmationDialog("분석 캐시 초기화", isPresented: $showingDeleteAnalysisCacheConfirmation, titleVisibility: .visible) {
            Button("초기화", role: .destructive) {
                RunSummaryCacheStore.shared.clearAllData()
                RunDetailCacheStore.shared.clearAllData()
                HeartRateZoneProfileCacheStore.shared.clearAllData()
                analysisCacheStatusMessage = L10n.tr("평균 심박, 케이던스, 상승 고도, 상세 차트, 심박존 기준 캐시를 삭제했습니다.")
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text(L10n.tr("상세 화면을 빠르게 보여주기 위해 기기에 저장한 파생 요약값, 차트 데이터, 심박존 기준 캐시만 삭제합니다. Apple 건강 원본 러닝 데이터, 경로 좌표, 신발 데이터는 그대로 유지됩니다."))
        }
    }
}

// 설정 화면의 링크 행은 텍스트와 방향 표시를 함께 그린다.
struct SettingLinkRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.29, green: 0.88, blue: 0.63).opacity(0.16))
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.29, green: 0.88, blue: 0.63))
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(LocalizedStringKey(detail))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.38))
        }
        .accessibilityElement(children: .combine)
    }
}

struct SettingSelectionRow: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 12)

                Text(LocalizedStringKey(value))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.38))
            }

            Text(LocalizedStringKey(detail))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// 설정 정보의 제목/값 행은 긴 값도 줄바꿈해서 표시할 수 있게 만든다.
struct SettingInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(LocalizedStringKey(value))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text(LocalizedStringKey(value))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SettingOptionRow: View {
    let title: String
    let detail: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(LocalizedStringKey(detail))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.headline)
                .foregroundStyle(isSelected ? Color(red: 0.29, green: 0.88, blue: 0.63) : .white.opacity(0.22))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct AppLanguageSettingsView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore

    private func detail(for option: AppLanguagePreference) -> String {
        switch option {
        case .korean:
            return "앱 화면 문구와 날짜를 한국어 기준으로 표시합니다."
        case .english:
            return "앱 화면 문구와 날짜를 영어 기준으로 표시합니다."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "앱 언어") {
                    VStack(spacing: 12) {
                        ForEach(AppLanguagePreference.allCases) { option in
                            Button {
                                appSettings.appLanguagePreference = option
                            } label: {
                                SettingOptionRow(
                                    title: option.label,
                                    detail: detail(for: option),
                                    isSelected: appSettings.appLanguagePreference == option
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("앱 언어")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DistanceUnitSettingsView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore

    private func detail(for option: DistanceUnitPreference) -> String {
        switch option {
        case .system:
            return "기기 설정에 맞춰 km 또는 mi를 자동으로 사용합니다."
        case .kilometers:
            return "거리와 페이스를 km 기준으로 고정합니다."
        case .miles:
            return "거리와 페이스를 mi 기준으로 고정합니다."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: "거리 단위") {
                    VStack(spacing: 12) {
                        ForEach(DistanceUnitPreference.allCases) { option in
                            Button {
                                appSettings.distanceUnitPreference = option
                            } label: {
                                SettingOptionRow(
                                    title: option.label,
                                    detail: detail(for: option),
                                    isSelected: appSettings.distanceUnitPreference == option
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle("거리 단위")
        .navigationBarTitleDisplayMode(.inline)
    }
}
