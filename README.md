# Tare

A native iPhone app for lifters who want control over every number behind their calorie target. The spec is in `SPEC.md`, the screens in `SCREENS.md`. This repo holds the full build: a tested math engine, a tested file layer, the SwiftUI app and a widget.

## What's here

| Folder | What it is | Verified? |
| --- | --- | --- |
| `TareEngine/` | Pure Swift package. `Dials` (every constant, versioned), BMR formulas, formula and observed TDEE, trend weight, the blend, rate modes, cycling, macros, sensitivity, all eight coach rules, lift analytics. | 83 unit tests pass (`swift test`), including a 28-day synthetic log with a known observed TDEE. |
| `TareFiles/` | Pure Swift package. `.xlsx` read and write, CSV, column-mapping guesses for Hevy, Strong, MacroFactor, Cronometer and MyFitnessPal exports, the Hevy API client. Depends on ZIPFoundation. | 36 unit tests pass. |
| `Tare/` | The iOS app: SwiftData models, HealthKit sync with background delivery, the five tabs, Coach screen, number-detail sheet, Dials with presets and change log, progress photos with camera overlay, Excel import/export, onboarding. | Parsed only. Needs Xcode to compile and a phone to run. |
| `TareWidget/` | WidgetKit extension: home-screen and lock-screen calories remaining. | Parsed only. |
| `Shared/` | The App Group snapshot the app writes and the widget reads. | Parsed only. |
| `project.yml` | XcodeGen definition for the app and widget targets, entitlements and Info.plist keys. | |

Everything runs on the phone. There is no server and no account.

## Building on your Mac

You need Xcode 16 or newer and an Apple Developer account (a free Apple ID works for 7-day installs).

### Option A: XcodeGen (recommended)

```bash
brew install xcodegen
cd TDEE_App
xcodegen generate
open Tare.xcodeproj
```

Then in Xcode:

1. Select the `Tare` target → Signing & Capabilities → pick your Team. Do the same for `TareWidget`.
2. If you change the bundle ID from `com.holdencole.tare`, also change the App Group in `project.yml` (`group.com.holdencole.tare`) and in `Shared/WidgetSnapshot.swift`, then re-run `xcodegen generate`.
3. Pick your iPhone as the run destination and press Run. HealthKit does not work in the simulator, so test on the phone.

### Option B: make the project by hand

1. File → New → Project → iOS App. Name `Tare`, SwiftUI, SwiftData storage. Uncheck "Include Tests" if you like.
2. Delete the generated `ContentView.swift` and `TareApp.swift`, then drag the `Tare/` and `Shared/` folders into the project (copy items, create groups).
3. File → Add Package Dependencies → Add Local → pick `TareEngine`, then again for `TareFiles`. Add both libraries to the `Tare` target.
4. Signing & Capabilities → `+ Capability` → HealthKit (tick Background Delivery), and App Groups (add `group.com.holdencole.tare`).
5. Info → add the usage strings from `project.yml` (`NSHealthShareUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSFaceIDUsageDescription`).
6. File → New → Target → Widget Extension, name `TareWidget`, untick "Include Configuration App Intent". Replace its generated Swift file with `TareWidget/TareWidget.swift`, add `Shared/WidgetSnapshot.swift` to the widget target too, and give the widget the same App Group.

### First compile

The app code was written without an Apple toolchain, so expect a handful of compile errors on the first build: a wrong argument label, a modifier that moved. Paste the exact Xcode error into Claude Code rather than describing it. The engine and file layer are tested and should not need changes.

## Running the package tests anywhere

```bash
cd TareEngine && swift test
cd ../TareFiles && swift test
```

They run on macOS and Linux.

## Before you rely on the numbers

- Weigh in the same way every morning and save it to Health.
- Check that your food app writes Dietary Energy to Health (Health → Browse → Nutrition → Dietary Energy → Data Sources & Access). If it doesn't, use "Log today" on the Today tab or a spreadsheet import.
- Turn on Apple Health in Hevy so workouts land with start and end times. For sets and reps, paste a Hevy API key (needs Hevy Pro) in Dials → Data sources, or import a Hevy or Strong CSV.

## How the engine treats time

- The observed TDEE uses the N days ending **yesterday** for calories (today's food is still being logged) and the N days ending **today** for weigh-ins, so this morning's weight counts.
- "Trust" is `min(1, days with calories ÷ N) × max trust`. Maintenance is `trust × observed + (1 − trust) × formula`.
- Calorie cycling keeps the weekly total: the gap between training and rest days is `(training-day TDEE − rest-day TDEE) × shift`, spread by your lift days per week.
- The `+38 kcal` badge on a dial is today's target now versus with that dial at its default.

## Layout of the app code

```
Tare/
  TareApp.swift            entry, scene phase → Health sync and coach check-in
  App/AppModel.swift       the one observable store: records → engine → screens
  App/AppState.swift       dials and flags in the App Group's UserDefaults
  App/NumberID.swift       every tappable number
  Models/Models.swift      SwiftData models from SPEC.md section 10
  Services/HealthSync.swift, HevyConnector.swift, ExportService.swift, Keychain.swift
  Design/Theme.swift, Components.swift, ChartStyle.swift
  Screens/Today, Trend, Progress, Plan, Dials, Coach, Detail, Onboarding, Data
```
