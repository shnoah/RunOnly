# AGENTS.md

This file is the quick-start guide for coding agents and collaborators working in this repository.

## Project Snapshot

- App name: `RunOnly`
- Platform: iPhone app built with SwiftUI
- Xcode project: `RunOnly.xcodeproj`
- Main source folder: `RunOnly/`
- Helper assets/scripts: `tools/`
- There are currently no separate test targets in this repo.

## Read First

Before starting work, check these files in this order:

1. `README.md`
2. `TEAM_NOTES.md`
3. Latest relevant section in `WORKLOG.md`

Open the `APP_STORE/` docs only when the task affects release copy, privacy wording, review notes, onboarding messaging, or support-facing text.

## Working Rules

- Follow direct user instructions first.
- Keep edits focused and avoid broad refactors unless they are necessary for the requested change.
- Respect existing uncommitted changes. Do not revert user work unless explicitly asked.
- Treat this app as local-first. Do not introduce backend or cloud assumptions unless requested.
- If you change user-facing UX, preserve the existing RunOnly tone: clean, runner-focused, lightweight.

## UI Rules

These project-wide UI rules come from `TEAM_NOTES.md` and should be treated as default guidance:

- UI should feel trendy.
- UI should stay concise.
- UI should stay intuitive.
- A first-time user should understand the screen at a glance.

When adjusting headers, cards, or high-visibility surfaces, prioritize those rules over decorative complexity.

## Documentation Rules

- Record substantial product or code changes in `WORKLOG.md` under the current date.
- Keep collaboration preferences and working style notes in `TEAM_NOTES.md`, not in `WORKLOG.md`.
- If a change affects App Store review wording, privacy descriptions, onboarding explanations, or support text, update the relevant files in `APP_STORE/` as part of the same task.

## Validation

- Preferred build check:
  `xcodebuild -project RunOnly.xcodeproj -scheme RunOnly -destination 'generic/platform=iOS Simulator' build`
- HealthKit-heavy flows are better verified on a real iPhone with Apple Health data.
- If simulator verification is incomplete, state that clearly in the handoff.

## Important Context

- The app reads Apple Health workout data on-device.
- Shoe and lightweight app data are stored locally.
- Privacy-sensitive wording matters. Be careful when editing permission prompts or health-related explanations.
