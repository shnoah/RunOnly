# RunOnly Work Log

## 2026-03-10

### 기록 범위
- 이 문서는 현재 워크스페이스에서 진행한 작업을 이어서 추적하기 위한 로그다.
- `이전 스레드` 항목은 원문 전체가 남아 있지 않아, 사용자 인수인계와 현재 코드 상태를 기준으로 복원한 요약이다.

### 이전 스레드 요약(복원)
- 초기 버전 빌드 완료.
- 2026-03-10 첫 실주행 데이터를 이용해 상세 화면 검증 시작.
- 목표:
  - 실제 러닝 기록이 Apple Fitness/Health 앱과 최대한 비슷하게 보이도록 조정.
  - 그래프와 km 스플릿의 거리 불일치 수정.
  - 빌드/에러 확인.
- 당시 확인된 현상:
  - 총 거리는 `4.02 km`인데 그래프 선택 최대값과 km 스플릿 계산이 약 `3.94 km` 수준으로 잘림.
  - 차트가 거리 버킷 기반으로 뭉개져 보임.
  - context compaction 413으로 이전 세션 종료.

### 현재 스레드 작업 내역

#### 1. 상세 거리/그래프/스플릿 불일치 수정
- 상세 카드의 총 거리와 그래프/스플릿 기준이 서로 다르던 문제 확인.
- 초기 단계에서는 `HKWorkout.totalDistance`를 기준으로 route 거리축과 split 계산을 맞추는 방향으로 조정.
- 그래프 축이 `4.0`에서 끊기지 않고 실제 최대 거리(`4.02`)까지 표기되도록 수정.
- 마지막 partial split도 표시되도록 수정.

#### 2. 그래프 해상도 조정
- 거리 버킷(대략 200m) 기반 압축을 제거.
- 샘플을 더 촘촘히 사용하도록 변경해 실주행 그래프 디테일 향상.

#### 3. Apple 공식 기록에 더 가깝게 상세 계산 구조 변경
- 목표를 `재계산 앱`이 아니라 `공식 운동 기록을 보기 좋게 표시하는 앱`으로 재정의.
- route를 지도 표시용으로 두고, 상세 계산의 기준을 다음으로 전환:
  - `HKWorkout.totalDistance`
  - `HKWorkout.duration`
  - `HKWorkout.workoutEvents`(pause/resume, motion pause/resume)
  - `HKQuantityTypeIdentifierDistanceWalkingRunning` 샘플
- `RunDetail`에 `distanceTimeline` 모델 추가.
- pace/split/선택 지점 elapsed 계산을 route 재계산 대신 공식 거리 타임라인 기준으로 변경.
- distance 샘플이 없을 때만 route 기반으로 fallback하도록 구성.

#### 4. pause 구간 반영
- active interval 개념 도입.
- pause 또는 auto-pause 구간은 active interval 밖으로 분리.
- 그래프가 pause 전후를 하나의 연속선으로 잇지 않도록 segment 기반 시리즈로 분리.
- pace smoothing도 segment 경계를 넘지 않게 수정.

#### 5. split UI 조정
- split 행 우측 하단의 중복 시간 표시 제거.
- 해당 위치에는 split 평균 심박이 나오도록 변경.
- 현재 사용자 확인 기준:
  - 그래프 pause 처리: 대체로 정상처럼 보임.
  - split 평균 심박 표기: 문제 남음, 다음 작업으로 보류.

### 이번 스레드에서 수정된 주요 파일
- `RunOnly/HealthKitService.swift`
- `RunOnly/RunningWorkout.swift`
- `RunOnly/ContentView.swift`

### 남은 이슈
- split 평균 심박 표기에 문제가 있음.
- 원인 후보:
  - split 거리 구간과 heart rate 샘플 매핑 방식 차이
  - pause 경계 전후 샘플 필터링 문제
  - 특정 러닝에서 heart rate 샘플 수 부족 또는 distance 매핑 오차

### 빌드/검증 메모
- CLI `xcodebuild`는 현재 환경에서 `CoreSimulator`/asset catalog runtime 문제로 끝까지 검증되지 않음.
- 에러 성격:
  - `No available simulator runtimes for platform iphonesimulator`
- 실제 기능 확인은 Xcode GUI/실기기에서 진행.

### 다음에 이어서 볼 작업
- split 평균 심박 표기 버그 수정.
- 필요하면 Apple Fitness와 상세 숫자 비교를 위한 검증용 디버그 출력 또는 개발자용 진단 화면 추가.

## 2026-03-12

### 상세 계산/표시 추가 수정
- split 평균 심박 계산을 거리 기준이 아닌 active elapsed 구간 기준으로 변경.
- 마지막 partial split 표기는 다시 `/km` 페이스 형식으로 원복.
- km split UI를 막대형에서 표형으로 변경.
- 이후 `시간` 열은 제거하고 `거리 / 페이스 / 심박 / 케이던스` 4열로 정리.

### 개인 최고기록(PR) 기능 추가
- 홈 화면에 `400m / 800m / 1K / 5K / 10K / 하프 / 풀` 2열 그리드 추가.
- 첫 계산 시 전체 러닝을 스캔해 내부 구간 PR까지 계산하도록 구현.
- 계산 진행률 퍼센티지 표시 추가.
- 최근 3년 이내 기록은 자동 반영, 3년보다 오래된 더 빠른 기록은 `검토 대기`로 분리.
- `검토 n건` 관리 화면에서 `유지 / 교체` 선택 가능하도록 구현.

### HealthKit 러닝 메트릭 확장
- 읽기 권한과 상세 로딩에 다음 항목 추가:
  - `stepCount`
  - `runningPower`
  - `runningSpeed`
  - `runningStrideLength`
  - `runningVerticalOscillation`
  - `runningGroundContactTime`
- `RunDetail.runningMetrics` 모델 추가.
- 케이던스는 전용 식별자가 없어 `stepCount` 샘플을 이용해 `spm`으로 계산.
- split 행에는 평균 케이던스를 표기하도록 연결.

### 디버그/목 데이터 강화
- 기존 `빈 경로 / 빈 심박 / 빈 상세` 외에 다음 시나리오 추가:
  - 정상 메트릭
  - pause 포함
  - 고급 메트릭 없음
- 상세 화면의 `테스트 데이터` 메뉴에서 바로 전환 가능하게 구성.

### 사용자 확인 상태
- PR 카드와 `검토 n건` 동작 확인.
- split 표 UI와 케이던스 표기 확인.
- HealthKit 케이던스 수집 확인.

### 검증 메모
- CLI 빌드는 Swift 단계까지 진행되지만 여전히 simulator runtime 부재로 asset catalog 단계에서 실패.
- 현재 관찰된 환경 에러:
  - `No available simulator runtimes for platform iphonesimulator`
