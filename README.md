# RunOnly

RunOnly is a SwiftUI iPhone app for reviewing Apple Watch running workouts from HealthKit in a cleaner, more runner-focused way.

It reads running workouts recorded on Apple devices, summarizes training status, shows detailed run analysis, and includes lightweight gear and PR tracking tools inside the app.

## What the app does

- Loads running workouts from HealthKit
- Optionally filters the list to Apple-recorded workouts only
- Shows summary cards for monthly distance, yearly distance, training status, VO2 Max, and predicted race times
- Supports loading older workout history month by month
- Calculates and displays personal records for `400m`, `800m`, `1K`, `5K`, `10K`, `Half`, and `Marathon`
- Separates older PR replacements into a review queue so they can be kept or replaced manually

## Run detail features

- Run route map
- Pace chart with distance-based interaction
- Heart rate chart
- Split table with distance, pace, heart rate, and cadence
- Pause / auto-pause aware calculations
- Distance timeline based on HealthKit samples when available
- Fallback detail handling when route, heart rate, or advanced metrics are missing

## Advanced metrics currently supported

RunOnly reads these HealthKit metrics when available:

- Heart rate
- Distance walking/running
- Step count
- VO2 Max
- Running power
- Running speed
- Running stride length
- Running vertical oscillation
- Running ground contact time

## Extra in-app tools

- Shoe management
- Assigning a shoe to each run
- Shoe mileage and run count tracking
- Shoe data backup export as JSON
- Debug/test scenarios for detail screens

## Privacy and storage

- Workout data is read from HealthKit on-device
- Shoe data is stored locally with `UserDefaults`
- There is currently no automatic cloud sync
- No backend or external server integration is included in this project

## Project structure

- [`RunOnly/`](RunOnly): app source code
- [`RunOnly.xcodeproj/`](RunOnly.xcodeproj): Xcode project
- [`tools/`](tools): helper scripts/assets
- [`WORKLOG.md`](WORKLOG.md): development notes

## Requirements

- Xcode 15 or newer
- iOS 17.0+
- A physical iPhone with HealthKit data is recommended for real testing

## Running the project

1. Open `RunOnly.xcodeproj` in Xcode.
2. Select an iPhone target or device.
3. Build and run the app.
4. Grant HealthKit read permission when prompted.

## Current status

This project is focused on viewing and analyzing Apple Health / Apple Watch running data on iPhone. It is not a training sync platform, social app, or cloud service.
