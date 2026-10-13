# Tare — iOS App Build Spec

Version 1.0 · October 13, 2026

Tare is a native iPhone app for lifters who want control over every number behind their calorie target. Every constant in the math is a dial you can change, and the app learns your real burn from your data underneath it. It connects to the apps you already use, imports and exports Excel, tracks progress photos and strength by muscle group, and suggests adjustments you accept or decline.

The name comes from the scale: to tare is to zero it out so you read the true weight. The app does the same for your metabolism. It starts from formulas, then recalibrates to what your body actually does.

Companion file: `SCREENS.md` holds the visual design, screen anatomy and interaction rules. Read both before building UI.

---

## 1. Before you start

- [ ] **A Mac with the current Xcode** from the Mac App Store. iOS apps can only be built and signed on macOS.
- [ ] **An Apple Developer account.** A free Apple ID can install the app on your phone, but the install expires after 7 days. The paid program ($99/yr) keeps it installed and unlocks TestFlight.
- [ ] **Claude Code with Fable selected.** Run `/model` in Claude Code and pick Fable before starting.
- [ ] **Check Provision writes to Apple Health.** Open Health → Browse → Nutrition → Dietary Energy → Data Sources & Access. If Provision isn't listed, ask its developer, since it's in TestFlight. Without this, calories are the one thing you'd still type in.
- [ ] **Turn on Apple Health in Hevy** so each workout is written to Health with its start and end time.
- [ ] **Weigh in the same way every morning** and save it to Health, either from a smart scale or by hand.

---

## 2. Data sources

Apple Health is the main connection, because most nutrition, workout, wearable and scale apps can sync to it. Direct app connections and Excel files fill in what Health doesn't carry, such as individual sets and reps.

```
Apple Watch ──────┐
Scale / manual ───┤
Provision ────────┼──▶ Apple Health ──▶ ┐
Hevy (duration) ──┘                      │
                                         ├──▶ Connectors ──▶ TareEngine ──▶ Five tabs
Hevy API or CSV (sets, reps) ───────────▶┤                  (TDEE, targets,   check-in cards
Excel / CSV files ──────────────────────▶┘                   coach, dials)    home widget
```

| Data | Example apps | How Tare gets it |
| --- | --- | --- |
| Calories and macros | Provision, MyFitnessPal, Cronometer, MacroFactor, Lose It! | Apple Health; Excel or CSV as a backup |
| Workout duration | Hevy, Strong, Fitbod, Apple Workouts | Apple Health |
| Sets, reps, weight | Hevy, Strong | Hevy API (needs Pro) or each app's CSV export |
| Steps, active energy, sleep | Apple Watch, Garmin, Oura, Whoop | Apple Health |
| Weight, body fat | Withings, Renpho, any Health-connected scale | Apple Health |
| Anything else | Spreadsheets, old logs, a coach's template | Excel or CSV import with column mapping |

Check each app's Health settings to confirm what it shares; not every app writes every data type.

**Built to add more.** Each source is a `Connector`: one Swift type that fetches a date range and returns day records and lift sets. HealthKit and Hevy are the first two. Direct APIs vary; some need a paid tier or developer approval, so add them one at a time as you need them.

**HealthKit reads:** body mass, body fat %, lean body mass, height, date of birth, biological sex, step count, active energy, dietary energy, dietary protein, carbohydrates and total fat, dietary water, and workouts (strength training and cardio types with duration). The app only reads; it never writes to Health.

---

## 3. Layout

Five tabs, which fits the iPhone tab bar. Today, Trend, Progress and Plan stay clean for daily use; Dials holds every number in the engine. Day to day you see one target, and the depth is one tap away. See `SCREENS.md` for the visuals.

**1. Today** (the screen you open 95% of the time)

- **Coach card first**, when there is an open recommendation: what it recommends, one line of why, Accept and Later. Tapping the card opens the Coach screen.
- Remaining calories, large. Target switches to the training-day number automatically once a strength workout appears in Health, with a manual "Lifting today" toggle for the morning before you train.
- Progress bar of eaten vs target, plus protein, carbs and fat remaining.
- This morning's weight next to trend weight, steps so far, and maintenance.

**2. Trend**

- Weight chart: daily weigh-ins as dots, smoothed trend as a line, last 6 weeks by default. Dial changes and accepted recommendations are marked on the chart.
- Actual rate (lb/wk) vs goal rate.
- Observed TDEE vs formula TDEE, with a trust meter showing how much the app relies on your data.

**3. Progress**

- Photos: a timeline of front, side and back shots, with a side-by-side or swipe compare between any two dates.
- Lifts: hard sets per week per muscle group, and estimated 1RM per exercise. Appears once enough set-level data exists.
- Body: trend weight, lean mass and body fat over time, when you have the data.

**4. Plan**

- Phase chips (Cut, Recomp, Maintain, Lean bulk, Bulk) and a rate slider in % bodyweight per week.
- Calorie cycling on/off and how much to shift.
- Protein (g/lb) and fat floor (g/lb). Carbs fill the rest.
- A table of training-day, rest-day and weekly-average targets.

**5. Dials**

- Every value in the engine, grouped as Body, BMR, Activity, Digestion, Adaptive, Goal, Cycling, Macros, Coach and Display. The full list is in section 5.
- Each dial shows its default, a reset button, a one-line note on what it does, and the live change to today's target as you drag it ("+38 kcal").
- Presets: save the whole set under a name ("Offseason", "Prep, 12 out") and switch in one tap.
- Change log: each dial change is dated, and the Trend chart marks it so you can see what a change did.
- Body basics (sex, age, height) and data-source status also live here.

**Two screens that open from anywhere**

- **Coach** (full screen): the recommendation, a chart of your trend against the goal path, the math line by line, what changes if you accept, and Accept / Edit amount / Later.
- **Number detail** (bottom sheet): opens from any number in the app. Shows that number's chart over time, the inputs that feed it, and a link to the dials that affect it.

**Widget:** today's target and calories remaining, for the home and lock screen.

---

## 4. The engine

The engine is a pure Swift package with unit tests. Every constant below is a default stored in a `Dials` struct, never hard-coded. Units: W = weight in kg, H = height in cm, LBM = lean mass in kg, A = age.

### BMR

- Mifflin-St Jeor: `10W + 6.25H − 5A + 5` (male) or `− 161` (female)
- Katch-McArdle: `370 + 21.6 × LBM`
- Cunningham: `500 + 22 × LBM`
- Harris-Benedict (revised): men `88.4 + 13.4W + 4.8H − 5.7A`; women `447.6 + 9.2W + 3.1H − 4.3A`
- Average of whichever are available, or a weighted blend, or a measured RMR override.

### Formula TDEE

Built from parts, with adaptation `a` = 0 to 0.15:

```
Rest day     = (BMR + living + steps + cardio) × (1 − a) + TEF
Training day = Rest day + lift × (1 − a)
```

| Part | How it's calculated | Source in the app |
| --- | --- | --- |
| Daily living | BMR × 8–15% (setting) | Dials |
| Steps | steps × W × 0.0005 kcal | Health step count |
| Lifting | (MET − 1) × W × hours. MET 3.5 heavy, 5.0 hypertrophy, 6.0 supersets | Hevy workouts in Health |
| Cardio | (MET − 1) × W × hours, by workout type | Health workouts |
| Digestion (TEF) | 25% of protein kcal + 7.5% of carb kcal + 2% of fat kcal | Target macros |
| Watch alternative | Replaces steps, lifting and cardio with Apple Watch active energy × 0.85 | Health active energy |

### Observed TDEE

From the log, over the trust window of N days (default 21):

```
TDEE_observed = mean(kcal eaten) − slope_lb_per_day × 3500
```

The slope is a least-squares fit through the weigh-ins in the window. It needs at least 7 days with calories and 7 with weight. Skip days where food logging was incomplete; the app lets you mark a day that way.

### Blend and targets

```
w           = min(1, days_with_kcal / N) × max_trust
Maintenance = w × TDEE_observed + (1 − w) × TDEE_formula
Target      = Maintenance + (rate × bodyweight_lb × 3500) / 7
```

- **Trend weight** is an exponential moving average of daily weigh-ins, α = 0.1, with an outlier filter.
- **Calorie cycling:** gap between days = (training-day TDEE − rest-day TDEE) × shift %. The weekly total stays the same: rest = target − gap × lift days ÷ 7, training = rest + gap.
- **Macros:** protein = g/lb × bodyweight (or lean mass, or goal weight). Fat = g/lb × bodyweight or % of calories. Carbs = what's left ÷ 4. Warn below the carb floor.
- **TEF loop:** TEF depends on the targets, which depend on TEF. Iterate 4 times; it settles.
- **Dial sensitivity:** a function that returns how much today's target changes for a change in one dial. The Dials screen shows this live.

---

## 5. Every dial

Thirty-five core dials, each with a default that works out of the box. The Progress and Coach thresholds in sections 6–8 are dials too. This table is the contract for the Dials tab and the `Dials` struct.

| Group | Dial | Default | Range or options |
| --- | --- | --- | --- |
| Body | Weight used | Trend weight | Trend, latest weigh-in, manual |
| Body | Trend smoothing (α) | 0.10 | 0.05–0.25 |
| Body | Outlier filter | Ignore weigh-ins 3 lb off trend | 1–6 lb, or off |
| Body | Body fat source | Manual | Manual, Health, none |
| BMR | Formula | Average of available | Mifflin, Katch-McArdle, Cunningham, Harris-Benedict, weighted blend |
| BMR | Measured RMR override | Off | Any kcal value from a lab test |
| BMR | BMR adjustment | 0% | −15% to +15% |
| Activity | Source | Modeled | Modeled, Apple Watch, blend with a weight |
| Activity | Watch correction | 0.85 | 0.5–1.0 |
| Activity | Daily living | 10% of BMR | 0–25% |
| Activity | Step cost | 0.0005 kcal per step per kg | 0.0003–0.0007 |
| Activity | Lifting MET by style | 3.5 heavy, 5.0 hypertrophy, 6.0 supersets | 2.5–8.0 each, plus custom styles |
| Activity | Lift duration | From Hevy | From Hevy, fixed minutes |
| Activity | Post-workout burn | 0% of session | 0–15% |
| Activity | Cardio MET by type | Walk 5.0, bike 7.0, stairs 9.0, run 9.8, HIIT 8.0 | Editable, plus custom types |
| Digestion | TEF rates (P / C / F) | 25% / 7.5% / 2% | 0–35% each, or a flat 10% |
| Adaptive | Trust window | 21 days | 7–56 |
| Adaptive | Days before trusting data | 7 | 5–14 |
| Adaptive | Max trust | 90% | 0–100% |
| Adaptive | Energy per lb of change | 3,500 kcal | 2,000–3,500 |
| Adaptive | Incomplete food days | Exclude | Exclude, include |
| Adaptive | Metabolic adaptation | 0% | 0–15% |
| Goal | Rate mode | % bodyweight per week | %/wk, lb/wk, fixed kcal, goal weight by date |
| Goal | Rate | +0.30%/wk | −1.5 to +1.0 |
| Goal | Calorie floor and ceiling | Off | Any kcal |
| Cycling | Calorie cycling | On, 100% shift | 0–200% |
| Cycling | Training day detection | Hevy workout, else manual | Hevy, weekly schedule, manual |
| Cycling | Weekday offsets | 0 | ± kcal per weekday, e.g. a Saturday refeed |
| Macros | Protein | 1.0 g/lb bodyweight | 0.6–1.5; per bodyweight, lean mass or goal weight |
| Macros | Fat | 0.35 g/lb floor | g/lb or % of calories |
| Macros | Carb floor warning | 50 g | 0–200 g |
| Macros | Fiber | 14 g per 1,000 kcal | 0–25 |
| Macros | Day-type overrides | Off | Separate macros for training and rest days |
| Display | Rounding | Nearest 10 kcal | 1, 5, 10, 25, 50 |
| Display | Water target | 0.5 oz/lb + 12 oz per training hour | Both parts editable |

The energy-per-lb dial exists because a lean bulk adds some muscle, which stores less energy per pound than fat.

---

## 6. Progress photos

Photos live inside Tare, never in your camera roll, and each one is tied to that day's trend weight, body fat and phase.

- **Capture:** in-app camera with a faded overlay of your last photo in the same pose, so framing and distance match. Poses: front, side, back, plus custom. A 3-second timer for mirror-free shots.
- **Import:** pick older photos from your library and set their dates.
- **Compare:** side by side, a swipe slider between two dates, or a time-lapse across a phase.
- **Privacy:** optional Face ID lock on the Progress tab. Photos are left out of exports unless you choose to include them.

---

## 7. Lifting progress by muscle group

This needs set-level data (exercise, weight, reps, date), which Apple Health doesn't carry. It comes from the Hevy API or a Hevy or Strong CSV export.

- **Muscle map:** each exercise credits 1 set to its primary muscle and 0.5 to each secondary. Use the source's muscle groups when it provides them; otherwise use a built-in map of common lifts, and ask once to tag anything unknown.
- **Weekly hard sets per muscle:** working sets only, warm-ups excluded.
- **Estimated 1RM per exercise:** Epley, `weight × (1 + reps ÷ 30)`, from the best set of 10 reps or fewer each session.
- **Relative strength:** estimated 1RM ÷ trend weight, which shows whether a cut is costing strength.
- **Body map:** front and back silhouettes shaded by change over 4, 8 or 12 weeks. Tap a muscle for its chart and exercises.
- **Unlocks when there's enough data:** a muscle shows after 4 weeks of sessions that train it; an exercise's 1RM trend after 6 sessions. Both thresholds are dials.

---

## 8. Coach

Once a week (Sunday by default) the coach checks your trends against your goal and offers specific changes. It never changes a dial on its own unless you turn on auto-apply.

| Signal | Default trigger | Suggestion |
| --- | --- | --- |
| Rate off target | Actual rate misses the goal by more than 0.15%/wk at 2 check-ins in a row | Move the target by (goal − actual lb/wk) × 3,500 ÷ 7, capped at 250 kcal per change |
| Incomplete logging | Fewer than 5 days of food logged that week | Hold all calorie changes until the data is complete |
| Strength dropping on a cut | Estimated 1RM down more than 5% on 3+ main lifts over 4 weeks | Slow the deficit by 0.25%/wk, or take a 1–2 week maintenance break |
| Long cut | More than 12 weeks in a deficit | Suggest a maintenance phase |
| Undertrained muscle | Under 10 hard sets/wk for 3 weeks while bulking | Add sets, using exercises you already do |
| Protein short | Protein target hit on fewer than 5 of 7 days | Flag it, with your actual average |
| Steps drifting | Weekly steps down more than 20% from your window average | Show the calorie impact and whether the target already covers it |
| Bulk overshoot | Body fat above your ceiling (default 18%) | Suggest switching to a cut |

Every trigger and threshold above is a dial. Each suggestion shows the numbers behind it and a chart of the trend that triggered it. Accept applies the change and logs it; Edit amount lets you change the size before accepting; Later snoozes it for a week.

---

## 9. Excel import and export

Anything in Tare goes out as a spreadsheet, and any spreadsheet can come in.

- **Export:** an .xlsx workbook with sheets for Days, Lifts, Dials, Recommendations and a photo log (dates and stats, no images). CSV for any single sheet. Shared through the iOS share sheet or saved to Files.
- **Import:** .xlsx or .csv from Files. A mapping screen guesses each column (date, weight, calories, exercise, reps) and lets you fix it. Mappings are saved per source, so a Hevy, Strong or MacroFactor export only needs mapping once.
- **Template:** a blank workbook you can download, fill in by hand or from a coach, and import.
- **Libraries:** pick a maintained Swift package for reading and writing .xlsx.

---

## 10. Data model and tech stack

Everything runs on the phone. There's no server, no account and no monthly cost.

| Layer | Choice | Why |
| --- | --- | --- |
| UI | SwiftUI, iOS 18+ | Native look, least code |
| Charts | Swift Charts | Built in, handles every chart in the app |
| Storage | SwiftData (iCloud sync optional later) | Simple local database |
| Health data | HealthKit, with background delivery | Reads new weigh-ins, food and workouts as they land |
| Widget | WidgetKit | Home and lock screen target |
| Math | `TareEngine` Swift package | Pure functions, no UI, fully unit-tested |

**`Dials`** (one active set, Codable and versioned): every row of section 5, plus sex, birth date and height. New dials added later get their default, so old saves never break.

**`Preset`**: a name plus a full Dials snapshot. Export and import as JSON.

**`DialChange`**: date, dial name, old value, new value. Feeds the change markers on the Trend chart.

**`DayRecord`** (one per date): date, weight, calories, protein, carbs, fat, water, steps, active energy, lift minutes, lift style, cardio minutes, a food-log-complete flag, a manual "lifting today" override, and last-synced time.

**`LiftSet`**: date, exercise, set index, set type (warm-up, working, drop, failure), weight, reps, RPE, source.

**`ExerciseMap`**: exercise name, primary muscle, secondary muscles. Built-in entries plus your own tags.

**`ProgressPhoto`**: date, pose, image (SwiftData external storage), and the trend weight, body fat and phase on that date.

**`Recommendation`**: date, rule, the numbers behind it, suggested dial change, and status (open, accepted, dismissed).

**`ImportMapping`**: source name and column-to-field map, reused on the next import.

---

## 11. Build plan

Build in steps, each one session in Claude Code, and test on your phone after every step. Keep `SPEC.md` and `SCREENS.md` in the project folder so every prompt can point back to them.

### Phase 1 — core app

1. **Create the project yourself in Xcode.** New project → iOS App, SwiftUI, SwiftData storage, name it Tare. Under Signing & Capabilities, add HealthKit and tick Background Delivery. Then open the folder in Claude Code.
2. **Engine.** Paste the starting prompt below.
3. **Health sync.** "Add a HealthSync service that requests read access to every type in SPEC.md section 2, pulls the last 60 days into DayRecords, and uses background delivery to update when new samples arrive. Strength workouts set lift minutes; other workouts set cardio minutes."
4. **Today and Plan tabs.** "Build the Today and Plan tabs from SPEC.md section 3 and SCREENS.md, wired to TareEngine and DayRecords. Every number is tappable and opens the number-detail sheet from SCREENS.md with that number's history in Swift Charts."
5. **Trend tab and Dials.** "Build the Trend tab with Swift Charts (dots for weigh-ins, line for trend weight, markers for dial changes) and the Dials tab per SCREENS.md, including live sensitivity badges, reset, presets and the change log. Add first-launch onboarding that asks for HealthKit access and fills height, sex and age from Health."
6. **Widget.** "Add a WidgetKit extension showing today's target and calories remaining, sharing data through an App Group."

### Phase 2 — once the core works on your phone

1. **Coach.** "Implement the Coach rules from SPEC.md section 8 in TareEngine with every threshold in Dials and unit tests for each rule. Build the Today coach card and the Coach screen from SCREENS.md."
2. **Excel.** "Add Excel and CSV export and import as described in SPEC.md section 9, including the column-mapping screen and saved mappings."
3. **Lift data.** "Add a Hevy Connector using the Hevy API key from the Keychain, plus CSV import for Hevy and Strong exports, filling LiftSet. Then build the muscle map and the Lifts view in the Progress tab."
4. **Photos.** "Build progress photos per SPEC.md section 6: camera with the last-photo overlay, import, compare views and the optional Face ID lock."

### Starting prompt

```
Read SPEC.md and SCREENS.md. Create a local Swift package called TareEngine inside this project with no UI code. First define a Codable, versioned Dials struct containing every row of the "Every dial" table with its default; the engine must read every constant from Dials and hard-code none. Then implement everything in "The engine" section: all BMR formulas and the RMR override, formula TDEE by parts for rest and training days (modeled, Watch and blended activity), TEF with the 4-pass loop, trend weight with the outlier filter, observed TDEE from a least-squares slope over the trust window, the blend, every goal rate mode, calorie cycling with weekday offsets, and macros. Use pounds for inputs and outputs. Add a function that returns how much today's target changes when one dial changes. Write unit tests for each function, including a 28-day synthetic log where the right observed TDEE is known. Run the tests and fix failures before you stop. Don't build any screens yet.
```

If something breaks on device, paste the exact Xcode error into Claude Code rather than describing it.

---

## 12. Later

- Siri and Shortcuts: "What's my target today?" through App Intents.
- Apple Watch complication with calories remaining.
- Phase history, so the Trend chart shades each cut and bulk.
- Diet-break and refeed scheduling during long cuts.
- Dark mode, following the system setting.
