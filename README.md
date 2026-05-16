# PNR Run

## 한국어

`PNR Run`은 Apple 건강에 저장된 Apple Watch 러닝 기록을 iPhone에서 더 깔끔하고 러너 중심으로 살펴보는 SwiftUI 앱입니다. 홈 화면 표시 이름은 `PNR`이며, 외부 설명은 `Pace Notes & Records`를 사용합니다.

앱은 러닝 기록을 기기 안에서 읽고, 월간 목표와 누적 거리, 러닝 준비도, VO2 Max, 예상 완주 기록, 최고 기록, 신발 사용량, 공유용 러닝 이미지까지 한 흐름으로 정리합니다. 클라우드나 별도 서버 없이 로컬 우선으로 동작합니다.

### 주요 기능

- Apple 건강의 러닝 워크아웃 불러오기
- Apple 기기에서 기록된 운동만 보는 선택 필터
- 올해 누적 거리, 월간 목표, 러닝 준비도, VO2 Max, 예상 완주 기록 요약
- 오래된 러닝 기록을 월 단위로 추가 로드
- `400m`, `800m`, `1K`, `5K`, `10K`, `Half`, `Marathon` 최고 기록 계산
- 자동 교체하기 애매한 최고 기록 후보를 검토 대상으로 분리
- 최근 러닝, 최근 착용 신발, 월간 로그를 간결한 카드/리스트 UI로 표시

### 러닝 상세

- 러닝 경로 지도
- 거리 기반 상호작용이 가능한 페이스, 심박, 케이던스, 고도 차트
- 거리, 페이스, 심박, 케이던스를 포함한 구간 기록
- 일시정지와 자동 일시정지를 고려한 계산
- Apple 건강 샘플 기반 거리 타임라인
- 경로, 심박, 케이던스, 고도 데이터가 부족한 기록에 대한 fallback 처리
- 상세 차트 캐시와 보강 로딩으로 재진입 시 더 빠른 표시

### 러닝 준비도와 건강 지표

PNR Run은 가능한 경우 아래 Apple 건강 지표를 읽어 러닝 기록과 준비도 계산에 사용합니다.

- 심박수
- 안정시 심박수
- 걷기/달리기 거리
- 걸음 수
- VO2 Max
- 지원되는 iOS/watchOS에서 제공되는 workout effort 또는 estimated workout effort

러닝 준비도는 최근 러닝 부하, 평소 기준선, 마지막 러닝 이후 시간, 안정시 심박 변화, Apple effort 값을 함께 고려합니다. Apple effort가 없으면 앱 내부 추정값으로 대체합니다. 이 점수는 훈련 참고용이며 의료 목적 지표가 아닙니다.

### 신발 관리

- 러닝별 신발 지정
- 신발별 누적 거리와 러닝 횟수 추적
- 최근 착용 신발 요약
- 신발 데이터 JSON 백업 내보내기
- 설정에서 로컬 캐시와 신발 데이터 관리

### 공유 기능

- `공유` 탭에서 최근 러닝 선택
- 러닝 스티커와 미니 타이포 템플릿 생성
- 스티커/스타일 템플릿의 표시 데이터, 폰트, 색상 조정
- 새 미니 템플릿의 미리보기, 저장, 복사, 공유
- 상세 화면과 공유 탭이 같은 이미지 export 흐름 재사용

### 데모와 App Store 준비 도구

- HealthKit 권한 없이 주요 화면을 확인하는 샘플 러닝/스크린샷 모드
- 홈, 기록, 상세 차트, 경로/구간, 공유, 신발, 설정, 권한 화면 캡처 경로
- App Store 제출용 개인정보, 리뷰 노트, 메타데이터 초안은 `APP_STORE/`에 정리

### 개인정보와 저장 방식

- 러닝 기록은 Apple 건강에서 기기 안으로만 읽습니다.
- 신발과 가벼운 앱 데이터는 로컬 저장소에 보관합니다.
- 앱 내부 JSON 저장에는 iOS 파일 보호를 적용합니다.
- 현재 자동 클라우드 동기화, 백엔드, 외부 서버 연동은 없습니다.
- 개인정보/심사/지원 문구를 바꾸는 작업은 `APP_STORE/` 문서도 함께 확인해야 합니다.

### 프로젝트 구조

- `RunOnly/`: 앱 소스 코드
- `RunOnlyTests/`: 계산 로직 중심 유닛 테스트
- `RunOnly.xcodeproj/`: Xcode 프로젝트
- `tools/`: 앱 아이콘 생성 등 보조 스크립트와 자산
- `APP_STORE/`: App Store 메타데이터, 개인정보 처리방침, 리뷰 노트, 스크린샷 캡처 안내
- `WORKLOG.md`: 작업 기록
- `TEAM_NOTES.md`: 협업 방식과 UI 원칙

### 요구 사항

- Xcode 15 이상
- iOS 17.0 이상
- 실제 Apple 건강 러닝 데이터를 확인하려면 Apple Watch 기록이 있는 실제 iPhone 권장

### 실행 방법

1. Xcode에서 `RunOnly.xcodeproj`를 엽니다.
2. iPhone 시뮬레이터 또는 실제 iPhone 대상을 선택합니다.
3. 앱을 빌드하고 실행합니다.
4. 실제 데이터를 확인하려면 Apple 건강 읽기 권한을 허용합니다.

### 검증

기본 빌드 확인:

```sh
xcodebuild -project RunOnly.xcodeproj -scheme RunOnly -destination 'generic/platform=iOS Simulator' build
```

계산 테스트 확인:

```sh
xcodebuild test -project RunOnly.xcodeproj -scheme RunOnly -destination 'platform=iOS Simulator,name=iPhone 17'
```

HealthKit 상세 데이터와 실제 러닝 흐름은 시뮬레이터보다 Apple 건강 데이터가 있는 실제 iPhone에서 검증하는 것이 좋습니다.

### 현재 상태

현재 앱은 Apple 건강/Apple Watch 러닝 데이터를 iPhone에서 보기 쉽게 정리하고, 기록 분석, 준비도 참고, 신발 관리, 공유 이미지 제작을 제공하는 로컬 우선 러닝 로그 앱입니다. 훈련 동기화 플랫폼, 소셜 앱, 클라우드 서비스가 아닙니다.

## English

`PNR Run` is a SwiftUI iPhone app for reviewing Apple Watch running workouts from Apple Health in a cleaner, more runner-focused way. The Home Screen display name is `PNR`, and the public expansion is `Pace Notes & Records`.

The app reads running data on device and organizes monthly goals, cumulative distance, running readiness, VO2 Max, predicted race times, personal records, shoe mileage, and shareable run images in one lightweight flow. It is local-first and does not depend on a cloud service or backend.

### Core features

- Load running workouts from Apple Health
- Optionally filter to workouts recorded by Apple devices
- Summarize yearly distance, monthly goals, running readiness, VO2 Max, and predicted race times
- Load older workout history month by month
- Calculate personal records for `400m`, `800m`, `1K`, `5K`, `10K`, `Half`, and `Marathon`
- Put ambiguous PR replacement candidates into a manual review queue
- Show recent runs, recently used shoes, and monthly logs with concise card/list UI

### Run detail

- Run route map
- Distance-interactive pace, heart rate, cadence, and elevation charts
- Split table with distance, pace, heart rate, and cadence
- Pause and auto-pause aware calculations
- Distance timeline based on Apple Health samples
- Fallback handling when route, heart rate, cadence, or elevation data is missing
- Detail chart caching and progressive enrichment for faster revisits

### Readiness and health metrics

PNR Run reads these Apple Health metrics when available:

- Heart rate
- Resting heart rate
- Distance walking/running
- Step count
- VO2 Max
- Workout effort or estimated workout effort on supported iOS/watchOS versions

Running readiness considers recent training load, baseline history, time since the last run, resting heart rate changes, and Apple effort values. If Apple effort is unavailable, the app falls back to an internal estimate. The score is for training reference only and is not a medical metric.

### Shoe management

- Assign a shoe to each run
- Track shoe mileage and run count
- Show recently used shoes
- Export shoe data backup as JSON
- Manage local cache and shoe data from Settings

### Sharing

- Pick recent runs from the `Share` tab
- Generate run stickers and compact typography templates
- Adjust included data, fonts, and colors for sticker/style templates
- Preview, save, copy, and share the newer mini templates
- Reuse the same image export path from both run detail and the Share tab

### Demo and App Store tools

- Sample run and screenshot modes for checking key screens without HealthKit permission
- Capture paths for Home, Records, detail charts, route/splits, sharing, shoes, settings, and permission screens
- App Store privacy, review note, and metadata drafts live in `APP_STORE/`

### Privacy and storage

- Workout data is read from Apple Health on device.
- Shoe and lightweight app data are stored locally.
- Internal JSON files use iOS file protection.
- There is currently no automatic cloud sync, backend, or external server integration.
- Changes to privacy, review, support, or App Store wording should also update the relevant files in `APP_STORE/`.

### Project structure

- `RunOnly/`: app source code
- `RunOnlyTests/`: unit tests for calculation-heavy logic
- `RunOnly.xcodeproj/`: Xcode project
- `tools/`: helper scripts and assets, including app icon generation
- `APP_STORE/`: App Store metadata, privacy policy, review notes, and screenshot capture guide
- `WORKLOG.md`: development log
- `TEAM_NOTES.md`: collaboration notes and UI principles

### Requirements

- Xcode 15 or newer
- iOS 17.0+
- A physical iPhone with Apple Watch running data is recommended for real HealthKit testing

### Running the project

1. Open `RunOnly.xcodeproj` in Xcode.
2. Select an iPhone simulator or physical iPhone target.
3. Build and run the app.
4. Grant Apple Health read permission when testing real data.

### Validation

Preferred build check:

```sh
xcodebuild -project RunOnly.xcodeproj -scheme RunOnly -destination 'generic/platform=iOS Simulator' build
```

Calculation test check:

```sh
xcodebuild test -project RunOnly.xcodeproj -scheme RunOnly -destination 'platform=iOS Simulator,name=iPhone 17'
```

HealthKit-heavy detail flows are best verified on a real iPhone with Apple Health data rather than only in the simulator.

### Current status

The project is currently a local-first running log app for reviewing Apple Health / Apple Watch running data on iPhone, with record analysis, readiness reference, shoe tracking, and share image creation. It is not a training sync platform, social app, or cloud service.
