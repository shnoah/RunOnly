# RunOnly App Review Notes

## What the App Does

RunOnly is an iPhone app for reviewing Apple Health running workouts in a cleaner, runner-focused format.

It reads running workouts recorded on Apple devices and shows:

- Monthly and yearly mileage summaries
- Detailed run charts and route view
- Heart rate and advanced running metrics
- Personal record tracking
- Shoe assignment and mileage tracking
- Share-ready run summary layouts

## Fastest Review Path

If the review device has Apple Health running data:

1. Open `RunOnly`
2. Tap `Apple 건강 권한 허용하고 시작`
3. Grant Apple Health read access
4. Open any run from `기록`
5. Check detail charts, splits, route, and share screen

If the review device does not have running data:

1. Open `RunOnly`
2. Tap `샘플 러닝 열기`, or
3. After entering the app, open the `샘플 러닝 열기` card pinned at the top of `기록`
4. In the detail screen, open `다른 샘플 보기` to inspect alternate scenarios such as paused runs, missing route, and missing heart rate

## Permissions

- Apple Health read permission is requested to read running workouts and related metrics
- Photo Library add-only permission is requested only when the user saves a generated share image to Photos

## Network / Accounts

- No account is required
- No login is required
- No backend upload flow is included in the current 1.0 build

## Notes for Review

- The app is intended for iPhone
- Demo/sample mode is included specifically so the review team can inspect the core experience even without local Apple Health workout data
