# App Store Screenshot Capture Flow

App Store 제출용 스크린샷과 화면 QA를 빠르게 찍을 때 쓰는 고정 데모 흐름입니다. launch argument 또는 environment variable로 켜며, 모든 화면은 2025-2026년에 걸친 같은 로컬 샘플 러닝 데이터를 사용합니다.

## Launch Arguments

`RunOnly` scheme의 launch arguments에 원하는 mode를 넣습니다.

```text
--pnr-screenshot home
```

환경 변수로 켤 때는 같은 값을 `PNR_SCREENSHOT_MODE`에 넣습니다.

```text
PNR_SCREENSHOT_MODE=home
```

## Primary Capture Set

실제 App Store 제출 후보는 아래 순서로 먼저 캡처합니다.

1. `home` - 올해/월간 거리, 준비도, VO2 Max, 예상 기록, 최근 러닝이 채워진 홈 요약.
2. `records` - 샘플 러닝 진입 카드와 March 2026 러닝 목록이 보이는 기록 화면.
3. `run-detail` - 상세 기록의 요약, 차트, 심박, 경로 진입 흐름.
4. `charts` - 고정 샘플 러닝의 상세 요약, 흐름 차트, 심박 존.
5. `route-splits` - 같은 샘플 러닝의 경로 지도와 구간 스플릿.
6. `share-composer-sticker` - 샘플 러닝으로 열린 공유 이미지 편집 화면.
7. `personal-records` - 최고 기록과 검토 대기 상태를 확인하는 기록 관리 화면.
8. `shoes` - 샘플 신발과 최신 러닝 연결이 채워진 신발 탭.
9. `settings-heart-zones` - 심박 존 설정 루트.
10. `data-permissions` - Apple 건강 데이터 읽기 범위와 로컬 저장 안내 화면.

## Full QA Mode Catalog

### Onboarding and Empty States

- `onboarding` - 첫 실행 Apple 건강 안내 화면.
- `home-empty` - 홈 빈 상태.
- `records-empty` - 기록 빈 상태.
- `sample-run-entry` - 샘플 러닝 진입 안내.

### Home Metrics

- `home` - 홈 탭 전체 요약.
- `mileage-goal` - 월간 마일리지 목표 설정.
- `mileage-breakdown` - 올해 마일리지 상세.
- `mileage-breakdown-all` - 전체 기간 마일리지 상세.
- `prediction-trend` - 예상 기록 추세 기본 10K 화면.
- `prediction-trend-5k` - 5K 예상 기록 추세.
- `prediction-trend-half` - 하프 예상 기록 추세.
- `prediction-method` - 예상 기록 계산 설명.
- `vo2-trend` - VO2 Max 1년 추세.
- `vo2-trend-all` - VO2 Max 전체 기간 추세.
- `readiness` - 러닝 준비도 카드.
- `readiness-evidence` - 준비도 근거 화면.
- `readiness-test` - Apple 노력 점수 기반 준비도 비교 테스트 화면.

### Records and Run Detail

- `records` - 기록 탭 목록.
- `recent-runs` - 최근 러닝 전체 목록.
- `calendar` - 기록 달력 화면.
- `personal-records` - 최고 기록 관리.
- `personal-record-run` - PR 배너가 있는 상세 기록.
- `run-detail` - 상세 기록 기본 시나리오.
- `run-detail-paused` - 일시정지 포함 상세 기록.
- `run-detail-missing-route` - 경로 없는 상세 기록.
- `run-detail-missing-heart-rate` - 심박 없는 상세 기록.
- `run-note-editor` - 러닝 메모 편집 화면.
- `run-detail-share` - 상세 기록에서 공유 편집으로 진입한 화면.
- `charts` - 상세 차트 섹션.
- `route-splits` - 경로와 스플릿 섹션.
- `route-splits-table` - 구간 표 정렬 QA용 스플릿 섹션.
- `heart-zones` - 상세 심박 존 섹션과 수동 범위 예시.

### Shoes

- `shoes` - 신발 탭 샘플 데이터.
- `shoes-empty` - 신발 빈 상태와 샘플 미리보기.
- `shoe-detail` - 신발 상세와 연결 러닝.
- `shoe-detail-empty` - 연결 러닝 없는 신발 상세.
- `shoe-add` - 신발 추가 화면.
- `shoe-edit` - 신발 편집 화면.
- `shoe-order` - 신발 순서 편집 화면.

### Share

- `share` - 공유 탭 루트.
- `share-template-picker` - 전체 템플릿 선택 화면.
- `share-composer-sticker` - 클립보드 스티커 편집.
- `share-composer-style1` - 상단 오버레이 편집.
- `share-composer-micro` - 마이크로 한 줄 편집.
- `share-composer-stack` - 미니 스택 편집.
- `share-composer-glass` - 글래스 pill 편집.
- `share-composer-caption` - 세리프 캡션 편집.
- `share-composer-race` - 레이스 라벨 편집.

### Settings and Policy

- `settings` - 설정 루트.
- `settings-language` - 앱 언어 설정.
- `settings-distance-unit` - 거리 단위 설정.
- `settings-heart-zones` - 심박 존 설정 자동 기준.
- `settings-heart-zones-manual` - 심박 존 설정 수동 범위 입력.
- `settings-shoe-data` - 신발 데이터 백업/복원.
- `settings-data-management` - 앱 데이터 관리.
- `settings-support` - 지원 센터.
- `privacy` - 앱 내 개인정보 처리방침.
- `data-permissions` - 데이터 권한 안내.

## Notes

- 데모 모드는 HealthKit 안내를 우회하고 Apple 건강 권한을 요청하지 않습니다.
- 샘플 데이터는 로컬 고정 데이터이며 HealthKit workout을 쓰지 않습니다.
- 일반 앱 흐름으로 돌아가려면 screenshot argument 또는 environment variable을 제거합니다.
