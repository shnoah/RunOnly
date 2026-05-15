# App Store Screenshot Capture Flow

App Store 제출용 스크린샷을 빠르게 찍을 때 쓰는 고정 데모 흐름입니다. launch argument 또는 environment variable로 켜며, 모든 화면은 같은 로컬 샘플 러닝 데이터를 사용합니다.

## Launch Arguments

`RunOnly` scheme의 launch arguments에 아래 중 하나를 넣습니다.

- `--pnr-screenshot home`
- `--pnr-screenshot records`
- `--pnr-screenshot charts`
- `--pnr-screenshot route-splits`
- `--pnr-screenshot share`
- `--pnr-screenshot readiness-test`

환경 변수로 켤 때는 `PNR_SCREENSHOT_MODE`를 아래 값 중 하나로 설정합니다.

- `home`
- `records`
- `charts`
- `route-splits`
- `share`
- `readiness-test`

## Capture Order

1. `home` - 월간 거리, 준비도, VO2 Max, 예상 기록, 최근 러닝이 채워진 홈 요약.
2. `records` - 샘플 러닝 진입 카드와 March 2026 러닝 목록이 보이는 기록 화면.
3. `charts` - 고정 샘플 러닝의 상세 요약, 흐름 차트, 심박 존.
4. `route-splits` - 같은 샘플 러닝의 경로 지도와 구간 스플릿.
5. `share` - 샘플 러닝과 경로 메트릭으로 바로 열린 공유 이미지 편집 화면.
6. `readiness-test` - Apple 노력 점수 기반 준비도 비교 테스트 화면.

## Notes

- 데모 모드는 HealthKit 안내를 우회하고 Apple 건강 권한을 요청하지 않습니다.
- 샘플 데이터는 로컬 고정 데이터이며 HealthKit workout을 쓰지 않습니다.
- 일반 앱 흐름으로 돌아가려면 screenshot argument 또는 environment variable을 제거합니다.
