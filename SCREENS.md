# Tare — Screens

Version 1.0 · October 13, 2026 · companion to `SPEC.md`

Seven screens: five tabs plus two that open from anywhere. The mockups below are 390 × 844 (iPhone 15/16 size) with sample data. Rebuild them in SwiftUI; don't copy pixel values from the PNGs, use the tokens in section 1.

| Screen | Opens from | File |
| --- | --- | --- |
| Today | Tab 1, app launch | `screens/today.png` |
| Coach | Tap the coach card on Today | `screens/coach.png` |
| Number detail | Tap any dotted number anywhere | `screens/detail.png` |
| Trend | Tab 2 | `screens/trend.png` |
| Progress | Tab 3 | `screens/progress.png` |
| Plan | Tab 4 | `screens/plan.png` |
| Dials | Tab 5 | `screens/dials.png` |

---

## 1. Design language

One continuous white surface per screen. No cards, no boxes, no borders. Sections are separated by whitespace and a 1 px hairline. The only coloured block in the whole app is the coach card.

**Type:** Geist (SwiftUI: bundle the font, or use SF Pro with the same sizes and weights; SF Pro is an acceptable substitute). Numbers use tabular figures everywhere (`.monospacedDigit()`).

| Role | Size | Weight | Tracking |
| --- | --- | --- | --- |
| Hero number | 72 | Bold | −4% |
| Large number | 44–52 | Bold | −4% |
| Screen title | 26 | Bold | −2% |
| Stat number | 22 | Bold | −2% |
| Section heading | 21 | Bold | −2% |
| Body | 14–15 | Regular / Semibold | 0 |
| Caption | 12–13 | Regular | 0 |
| Eyebrow label | 11–12 | Semibold, uppercase | +8–10% |

**Colour**

| Token | Hex | Use |
| --- | --- | --- |
| Ink | `#15181D` | Text, primary buttons, filled bars, active tab |
| Secondary | `#6B7280` | Captions, labels, inactive text |
| Tertiary | `#9AA1AB` | Hints, inactive tabs, chart axes |
| Hairline | `#ECEEF1` | Dividers, chart grid |
| Track | `#EEF0F3` | Empty part of any bar |
| Pill | `#F2F3F5` | Secondary buttons, chips, segmented control |
| Accent | `#2453CC` | Dotted underlines, chart lines, the trust bar, "+38 kcal" badges |
| Coach gradient | `#1B3FA8 → #2F63E0` at 135° | The coach card only |
| Good | `#1D7A50` | Gains, on-target |
| Behind | `#9A5A06` text / `#C27A12` bars | Behind goal, under-target muscles |

**Shape:** buttons 12–14 px radius, chips and segmented controls fully rounded, coach card 20 px, bottom sheet 28 px top corners. Sliders: 4–6 px track, 22–28 px white thumb with a soft shadow.

**Spacing:** 24 px side margins. 28 px from the top of the safe area to the header. Sections breathe 18–28 px. Rows in a list are 40–60 px tall.

**Tab bar:** five tabs, line icons, 11 px labels. Active tab is ink, inactive tabs are tertiary. White background with a soft fade above it, no top border.

---

## 2. Interaction rules

These apply on every screen.

1. **Every number is tappable.** Any value that comes from data or the engine gets a 1.5 px dotted accent underline and opens the number-detail sheet (section 5) for that value. Labels and units are not tappable. This includes targets, macros, weights, steps, TDEE figures, rates, set counts, 1RMs and the "+38 kcal" sensitivity badges on Dials.
2. **The coach comes first.** When a recommendation is open, its card is the first thing under the header on Today. When none is open, the Remaining number moves up to take its place.
3. **Accept is one tap, and reversible.** Accepting a recommendation changes the dial, logs a `DialChange`, and shows an undo toast for 10 seconds.
4. **Training vs rest day is automatic.** Today shows a "Training day" pill once a strength workout appears in Health. Tapping the pill toggles it manually for the day.
5. **Charts share one style.** Accent line 2.5 px with a soft area fill, raw data as tertiary dots, hairline horizontal grid, axis labels in tertiary 10 px, the last point ringed in white with its value labelled. Goal paths are dashed tertiary. Dial changes are a dashed vertical rule in the "behind" colour with a small label.
6. **Segmented controls** (6W / 3M / 1Y, Lifts / Photos / Body) are pill-shaped, with the active segment white on the pill-grey track.

---

## 3. Today

![Today](screens/today.png)

**Top to bottom**

1. Header: date in secondary, "Today" in title size. Right: the training-day pill (accent text on 8% accent tint).
2. **Coach card**, full width, gradient. Eyebrow "Coach · Sunday check-in" with a sparkle icon and a chevron. Headline is the recommendation in one line. One sentence of why. Accept (white) and Later (translucent white) buttons. The whole card is a link to the Coach screen; the two buttons act without leaving.
3. **Remaining today**: eyebrow, the hero number, then "of 3,420 kcal · 1,840 eaten" with the target dotted. A 6 px progress bar, ink on track.
4. Three macro columns: name, "eaten / target" dotted in secondary, a 4 px bar.
5. Hairline.
6. Three stats separated by vertical hairlines: Weight (trend under it), Steps (average under it), Maintenance (trust % under it). All three numbers dotted.
7. A tertiary hint, "Any dotted number opens its chart", shown for the first week only.

**States:** no recommendation (card hidden); no food logged yet today (hero shows the full target, progress bar empty, "0 eaten"); rest day (pill reads "Rest day" in secondary on pill-grey).

---

## 4. Coach

![Coach](screens/coach.png)

Full-screen push from the coach card. Back button returns to Today.

1. Header: back circle, eyebrow "Coach · Sunday check-in" in accent, the recommendation as the title.
2. **Weight vs goal path** chart: trend weight (accent line) against the goal path (dashed tertiary line from the phase start), the gap at the end marked with a short vertical "behind" rule and label. Three weeks by default, or the trust window.
3. Hairline.
4. **The math**, as a list of rows: goal rate, actual rate (21-day fit), gap × 3,500 ÷ 7, then the rounded and capped result in accent. The first two values are dotted and open their own charts.
5. Hairline.
6. **If you accept**: one short paragraph with the new training-day and rest-day targets, which macro absorbs the change, and that the change is logged and marked on Trend.
7. Bottom buttons, pinned: Accept +130 (ink), Edit amount (pill), Later (pill, secondary text). Edit amount opens a stepper on the same screen.

Each coach rule in `SPEC.md` section 8 uses this same layout with its own chart: strength rules show the 1RM trend, the undertrained-muscle rule shows weekly sets, the steps rule shows weekly steps.

---

## 5. Number detail (bottom sheet)

![Number detail](screens/detail.png)

A sheet over the current screen, dimmed behind. Drag down or tap outside to close. The example shows Maintenance.

1. Grab handle.
2. Header: eyebrow with the number's name, the value large, a change badge ("+90 in 6 wk" in good or behind colour), and a units line. Right: range control.
3. The chart. For Maintenance: observed TDEE as the accent line with area fill, the blended value as a faint accent line, formula TDEE as a dashed tertiary rule. Last point ringed and labelled.
4. Hairline.
5. **What feeds it**: rows of the inputs that produced the number. Inputs that are themselves dials or numbers are dotted and open their own sheet or the Dials tab.
6. Buttons: "Tune these dials" (pill) jumps to the Dials tab filtered to the relevant group; "Done" (ink) closes.

**What each number shows**

| Number | Chart | What feeds it |
| --- | --- | --- |
| Remaining / target | Daily target over time with intake bars | Maintenance, rate, cycling |
| Protein, carbs, fat | Daily grams vs target, last 2–6 weeks | Protein dial, fat dial, target |
| Weight | Same as the Trend tab chart | Weigh-ins, smoothing, outlier filter |
| Steps | Daily steps with the window average | Watch |
| Maintenance | Observed vs formula vs blended | Intake, slope, trust, formula |
| Actual rate | Weekly rate vs goal rate | Trend weight slope |
| Observed / formula TDEE | Each one over time | Their inputs |
| Trust % | Days logged per window | Logging completeness |
| Hard sets per muscle | Weekly sets, last 8–12 weeks | LiftSets and the muscle map |
| Estimated 1RM | Per-session e1RM for that exercise | Best set each session |
| Sensitivity badge ("+38 kcal") | Target as a function of that dial, with the current value marked | That dial |

---

## 6. Trend

![Trend](screens/trend.png)

1. Header: phase and week in secondary, "Trend" title. Right: 6W / 3M / 1Y segmented control.
2. **Trend weight** large, with the change since the range start in good/behind colour and the date.
3. The weight chart (section 2, rule 5). Dial changes and accepted recommendations are marked. Caption under it explains dots vs line.
4. Hairline.
5. Four stats in a 2 × 2 grid with vertical hairlines: Actual rate (with "goal +0.55 · behind" in the behind colour), Observed TDEE, Formula TDEE, Maintenance. All dotted.
6. Hairline.
7. **Trust in your data**: label, percent in accent, a 6 px accent bar, one line explaining the blend.

---

## 7. Progress

![Progress](screens/progress.png)

1. Header: data range and source in secondary, "Progress" title. Right: Lifts / Photos / Body segmented control.
2. **Lifts view** (shown): "Hard sets per week" with the target and range on the right. One row per muscle: name, an 8 px bar (accent when at or above target, behind-orange when under), set count, 8-week strength change in good/secondary. Under-target muscles have their name in the behind colour. A caption notes which muscles are under and that the coach will suggest where to add sets.
3. Hairline.
4. **Estimated 1RM**: one row per tracked exercise with a 70 px sparkline, the e1RM (dotted) and the change since the range start.
5. Hairline.
6. Photo compare strip: two thumbnails (oldest and newest in the range), pose and span, trend weights, and a "Compare photos →" link.

**Photos view:** a grid by date, filter by pose, tap two to compare (side by side or swipe slider). **Body view:** trend weight, lean mass and body fat as three small charts.

---

## 8. Plan

![Plan](screens/plan.png)

1. Header: active preset in secondary, "Plan" title. Right: "Save preset" pill.
2. Phase chips in a row: Cut, Recomp, Maintain, Lean bulk, Bulk. Active chip is ink with white text.
3. **Rate** as a large number with %, then "per week · lb/wk · kcal surplus or deficit" in secondary. Slider underneath with an accent fill. A caption with the usual rate range for the phase.
4. Hairline.
5. Setting rows, 52–56 px each, separated by hairlines: Calorie cycling (with the per-day shift and an ink toggle), Protein, Fat floor. Values on the right; tapping a row opens its dial.
6. Hairline.
7. **Daily targets** table: Training (accent row), Rest, Weekly avg. Columns kcal, P, C, F. The kcal values are dotted.

---

## 9. Dials

![Dials](screens/dials.png)

1. Header: "35 dials · 4 changed from default" in secondary, "Dials" title. Right: search button.
2. Group chips, horizontally scrolling: Body, BMR, Activity, Adaptive, Macros, Coach, and so on. Active chip is ink.
3. One dial per block, separated by hairlines:
   - **Slider dial**: name on the left, value and unit on the right. A dial that is off its default also shows a sensitivity badge ("+38 kcal", accent on 8% tint, dotted/tappable) and the slider fill turns accent instead of ink. Below: a one-line note in secondary, and a "Reset" link in accent when changed.
   - **Choice dial** (Lift duration, Activity source): a 60 px row with name and current value, chevron on the right, opens a picker.
   - **Number dial** (Post-workout burn): a row with the value on the right, tap to edit.
4. Presets and the change log live at the top of the Body group and at the end of the list respectively.

---

## 10. Widget

Not mocked up. Small widget: remaining calories large, target under it, a thin progress bar. Lock screen: remaining calories only. Both update when Health delivers new food samples.
