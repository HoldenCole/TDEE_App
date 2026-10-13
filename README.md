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

## No Mac? Build in the cloud

Two GitHub Actions workflows live in `.github/workflows/`. The repo is public, so GitHub's macOS runners are free.

- **Build** runs on every push: package tests, then an unsigned compile of the app. This is how compile errors get found and fixed without a Mac.
- **UI smoke** runs on every push too: it launches the app in the iPhone 16 simulator with demo data, walks every screen in light and dark mode, and publishes screenshots to the `ci-screenshots-light` and `ci-screenshots-dark` branches. Open those branches on GitHub to see the app without installing it.
- **TestFlight** runs on demand and needs the setup below. It mints a signing certificate and provisioning profiles with your App Store Connect API key, archives, uploads to TestFlight, then revokes what it created so nothing piles up in your account.

### TestFlight without a Mac: one-time setup (about 15 minutes in a browser)

1. **App Group.** [developer.apple.com/account](https://developer.apple.com/account) → Certificates, Identifiers & Profiles → Identifiers → the dropdown at the top right → App Groups → `+`. Description `Tare`, identifier `group.com.holdencole.tare`.
2. **App ID for the app.** Identifiers → `+` → App IDs → App → Description `Tare`, Bundle ID explicit `com.holdencole.tare`. Tick **HealthKit** and **App Groups**; next to App Groups press Configure and select the group from step 1. Register.
3. **App ID for the widget.** Same again with Bundle ID `com.holdencole.tare.widget`. Tick only **App Groups** and select the same group.
4. **API key.** [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Users and Access → Integrations → App Store Connect API → Team Keys → `+`. Name `Tare CI`, access **Admin**. Note the **Issuer ID** (top of the page) and the **Key ID**, and download the `.p8` file once (it can't be downloaded again).
5. **App record.** App Store Connect → Apps → `+` → New App → iOS, a name (App Store names are unique worldwide, so "Tare" alone may be taken; try "Tare Calorie Dials"), primary language, Bundle ID `com.holdencole.tare`, SKU `tare`. The name only matters for the store; TestFlight shows it too.
6. **Team ID.** developer.apple.com/account → Membership details → Team ID (10 characters).
7. **GitHub secrets.** github.com/HoldenCole/TDEE_App → Settings → Secrets and variables → Actions → New repository secret, four times:
   - `ASC_KEY_ID`: the Key ID from step 4
   - `ASC_ISSUER_ID`: the Issuer ID from step 4
   - `ASC_KEY_P8`: the whole contents of the `.p8` file, including the BEGIN and END lines
   - `APPLE_TEAM_ID`: from step 6
8. **Run it.** The TestFlight workflow is started from the Actions tab (it has to exist on the `main` branch to show up there). Each run uploads a build numbered after the run. Once App Store Connect finishes processing (a few minutes), add yourself under TestFlight → Internal Testing and install from the TestFlight app on your phone.

If you change the bundle ID, change it in `project.yml`, `fastlane/Fastfile`, `fastlane/Appfile`, `Shared/WidgetSnapshot.swift` and the App Group everywhere, then regenerate the project.

## Building on your Mac

You need Xcode 16 or newer and an Apple Developer account (a free Apple ID works for 7-day installs).

### Option A: open the committed project

`Tare.xcodeproj` is committed, generated from `project.yml` with XcodeGen. Open it directly. If you add files, either add them in Xcode or run `brew install xcodegen && xcodegen generate` to regenerate.

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
- Nothing resets when you switch phase or accept a recommendation. Every change is logged: dial changes and accepted recommendations appear as a dashed marker on the charts, and a phase switch draws a solid line with the chart shaded by phase (orange for a cut, blue for a bulk, green for maintenance or recomp). Switching phase leaves the rate alone; if the rate points the wrong way for the new phase, a toast offers the phase's usual rate.
- Health background delivery re-syncs the last three days whenever a weigh-in, meal, step sample or workout lands, including while the app is open. Coming to the foreground re-syncs Health, pulls Hevy if a key is set, and runs the coach if it is check-in day. Pull down on Today to do the same by hand.

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
