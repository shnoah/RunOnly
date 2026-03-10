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
