import SwiftUI
import SwiftData
import LocalAuthentication
import TareEngine

enum ProgressSection: Hashable, CaseIterable {
    case lifts, photos, body
    var title: String {
        switch self {
        case .lifts: return "Lifts"
        case .photos: return "Photos"
        case .body: return "Body"
        }
    }
}

struct ProgressTabView: View {
    @Environment(AppModel.self) private var model
    @State private var section: ProgressSection = .lifts
    @State private var weeks = 8
    @State private var unlocking = false

    var body: some View {
        NavigationStack {
            if AppState.progressLockEnabled && !model.progressUnlocked {
                lockScreen
            } else {
                Screen {
                    ScreenHeader(kicker: kicker, title: "Progress") {
                        SegmentedPills(options: ProgressSection.allCases.map { ($0, $0.title) }, selection: $section)
                    }
                    .padding(.bottom, 24)

                    switch section {
                    case .lifts: LiftsView(weeks: $weeks)
                    case .photos: PhotosView()
                    case .body: BodyView()
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    private var kicker: String {
        switch section {
        case .lifts:
            let sources = Set(model.liftSets.map(\.source)).filter { !$0.isEmpty }.sorted()
            return "Last \(weeks) weeks" + (sources.isEmpty ? "" : " · \(sources.joined(separator: ", "))")
        case .photos:
            let count = (try? model.context.fetchCount(FetchDescriptor<ProgressPhoto>())) ?? 0
            return count == 0 ? "No photos yet" : "\(count) photo\(count == 1 ? "" : "s")"
        case .body:
            return "Trend weight, lean mass, body fat"
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "faceid").font(.system(size: 44)).foregroundStyle(Theme.ink)
            Text("Progress is locked").font(Theme.section()).foregroundStyle(Theme.ink)
            PillButton(title: "Unlock") { unlock() }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .onAppear { unlock() }
    }

    private func unlock() {
        guard !unlocking else { return }
        unlocking = true
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            model.progressUnlocked = true
            unlocking = false
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your progress photos and lifts") { ok, _ in
            Task { @MainActor in
                model.progressUnlocked = ok
                unlocking = false
            }
        }
    }
}

// MARK: - Lifts

struct LiftsView: View {
    @Environment(AppModel.self) private var model
    @Binding var weeks: Int

    private var d: Dials { model.dials }

    private var weekly: [WeekSets] {
        LiftAnalytics.weeklyHardSets(sets: model.liftSets, map: model.muscleMap, weeks: weeks, today: Date())
    }
    private var average: [Muscle: Double] { LiftAnalytics.averageWeeklySets(weekly) }
    private var unlocked: Set<Muscle> { LiftAnalytics.unlockedMuscles(sets: model.liftSets, map: model.muscleMap, dials: d, today: Date()) }
    private var strengthChange: [Muscle: Double] {
        LiftAnalytics.strengthChangeByMuscle(strength: strength, map: model.muscleMap, weeks: weeks, today: Date())
    }
    private var strength: [ExerciseStrength] {
        LiftAnalytics.unlockedExercises(LiftAnalytics.strength(sets: model.liftSets), dials: d)
    }
    private var since: Date { Calendar.current.date(byAdding: .day, value: -weeks * 7, to: Date()) ?? Date() }

    var body: some View {
        if model.liftSets.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("No set-level data yet").font(Theme.section()).foregroundStyle(Theme.ink)
                Text("Apple Health carries workout duration but not sets and reps. Connect the Hevy API or import a Hevy or Strong CSV in Data sources, and this view fills in: hard sets per muscle each week, estimated 1RMs, and a body map.")
                    .font(Theme.body()).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
                NavigationLink { DataSourcesView() } label: {
                    Text("Open Data sources").font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
                }
            }
        } else {
            let muscles = Muscle.allCases.filter { unlocked.contains($0) }
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Hard sets per week")
                Spacer()
                Menu {
                    ForEach([4, 8, 12], id: \.self) { w in Button("\(w) weeks") { weeks = w } }
                } label: {
                    Text("target \(d.hardSetsTargetPerWeek) · \(weeks)-wk strength").font(Theme.body()).foregroundStyle(Theme.tertiary)
                }
            }
            .padding(.bottom, 14)

            if muscles.isEmpty {
                EmptyHint(text: "Muscles appear after \(d.muscleUnlockWeeks) weeks of sessions that train them.")
            }

            ForEach(muscles, id: \.self) { m in
                let avg = average[m] ?? 0
                let under = avg < Double(d.hardSetsTargetPerWeek)
                HStack(spacing: 14) {
                    Text(m.title).font(.system(size: 18, weight: .semibold)).foregroundStyle(under ? Theme.behind : Theme.ink)
                        .frame(width: 110, alignment: .leading)
                    BarView(fraction: avg / Double(d.hardSetsTargetPerWeek * 2), height: 8, color: under ? Theme.behindBar : Theme.accent)
                    DottedNumber(text: Fmt.dec(avg, 0), number: .sets(m), font: .system(size: 18, weight: .semibold), color: under ? Theme.behind : Theme.ink)
                        .frame(width: 34, alignment: .trailing)
                    Text(strengthChange[m].map { Fmt.signed($0, 0, suffix: "%") } ?? "—")
                        .font(.system(size: 18, weight: .semibold)).monospacedDigit()
                        .foregroundStyle((strengthChange[m] ?? 0) > 0 ? Theme.good : Theme.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
                .padding(.vertical, 10)
            }

            let underNames = muscles.filter { (average[$0] ?? 0) < Double(d.hardSetsTargetPerWeek) }.map { $0.title.lowercased() }
            if !underNames.isEmpty {
                Text("\(Format.list(underNames).capitalizingFirst) \(underNames.count == 1 ? "is" : "are") under \(d.hardSetsTargetPerWeek) sets. The coach will suggest where to add them.")
                    .font(Theme.body()).foregroundStyle(Theme.tertiary).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }

            if !model.untaggedExercises.isEmpty {
                NavigationLink { TagExercisesView() } label: {
                    Text("\(model.untaggedExercises.count) exercise\(model.untaggedExercises.count == 1 ? "" : "s") need a muscle tag →")
                        .font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
                }
                .padding(.top, 10)
            }

            strengthAndMore
        }
    }

    @ViewBuilder
    private var strengthAndMore: some View {
        Group {
            Hairline().padding(.vertical, 22)

            Eyebrow("Estimated 1RM").padding(.bottom, 10)
            if strength.isEmpty {
                EmptyHint(text: "An exercise's 1RM trend appears after \(d.exerciseUnlockSessions) sessions.")
            }
            ForEach(strength.prefix(8)) { ex in
                let sessions = ex.sessions.filter { $0.date >= since }
                let change = ex.change(since: since)
                HStack(spacing: 14) {
                    Text(ex.exercise).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer()
                    SparklineView(values: sessions.map(\.e1RM)).frame(width: 70, height: 28)
                    DottedNumber(text: ex.latest.map(Fmt.int) ?? "—", number: .e1rm(ex.exercise), font: .system(size: 18, weight: .bold))
                        .frame(width: 56, alignment: .trailing)
                    Text(change.map { Fmt.signed($0, 0) } ?? "—")
                        .font(.system(size: 17, weight: .semibold)).monospacedDigit()
                        .foregroundStyle((change ?? 0) > 0 ? Theme.good : Theme.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
                .padding(.vertical, 12)
            }

            Hairline().padding(.vertical, 22)

            BodyMapView(weeks: weeks, change: strengthChange, unlocked: unlocked)

            Hairline().padding(.vertical, 22)

            PhotoCompareStrip()
        }
    }
}

extension String {
    var capitalizingFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// Front and back silhouettes with muscles shaded by strength change. Tap a muscle for its chart.
struct BodyMapView: View {
    @Environment(AppModel.self) private var model
    let weeks: Int
    let change: [Muscle: Double]
    let unlocked: Set<Muscle>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("Body map")
                Spacer()
                Text("\(weeks)-week change").font(Theme.body()).foregroundStyle(Theme.tertiary)
            }
            HStack(spacing: 24) {
                figure(front: true)
                figure(front: false)
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 12) {
                legend(Theme.good, "up")
                legend(Theme.behindBar, "down")
                legend(Theme.track, "flat or no data")
            }
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text).font(Theme.captionSmall()).foregroundStyle(Theme.secondary)
        }
    }

    private func color(for m: Muscle) -> Color {
        guard unlocked.contains(m), let c = change[m] else { return Theme.track }
        if c > 1 { return Theme.good.opacity(min(1, 0.35 + c / 15)) }
        if c < -1 { return Theme.behindBar.opacity(min(1, 0.35 + abs(c) / 15)) }
        return Theme.pill
    }

    /// A schematic figure: regions are rounded rectangles placed on a 120×260 canvas.
    private func figure(front: Bool) -> some View {
        let regions: [(Muscle, CGRect)] = front
            ? [(.shoulders, CGRect(x: 14, y: 48, width: 92, height: 18)),
               (.chest, CGRect(x: 32, y: 66, width: 56, height: 30)),
               (.biceps, CGRect(x: 10, y: 70, width: 18, height: 40)),
               (.forearms, CGRect(x: 6, y: 114, width: 18, height: 40)),
               (.abs, CGRect(x: 40, y: 100, width: 40, height: 46)),
               (.quads, CGRect(x: 30, y: 152, width: 60, height: 60)),
               (.calves, CGRect(x: 34, y: 216, width: 52, height: 36))]
            : [(.shoulders, CGRect(x: 14, y: 48, width: 92, height: 18)),
               (.back, CGRect(x: 32, y: 66, width: 56, height: 70)),
               (.triceps, CGRect(x: 10, y: 70, width: 18, height: 40)),
               (.glutes, CGRect(x: 32, y: 138, width: 56, height: 26)),
               (.hamstrings, CGRect(x: 30, y: 166, width: 60, height: 48)),
               (.calves, CGRect(x: 34, y: 216, width: 52, height: 36))]
        return VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                // Outline
                Circle().fill(Theme.track).frame(width: 30, height: 30).offset(x: 45, y: 10)
                RoundedRectangle(cornerRadius: 14).fill(Theme.track).frame(width: 64, height: 100).offset(x: 28, y: 48)
                ForEach(regions, id: \.0) { m, rect in
                    Button { model.showDetail(.sets(m)) } label: {
                        RoundedRectangle(cornerRadius: 6).fill(color(for: m))
                            .frame(width: rect.width, height: rect.height)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .offset(x: rect.minX, y: rect.minY)
                    if front && (m == .biceps || m == .forearms) {
                        RoundedRectangle(cornerRadius: 6).fill(color(for: m))
                            .frame(width: rect.width, height: rect.height)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 1.5))
                            .offset(x: 120 - rect.maxX, y: rect.minY)
                    }
                    if !front && m == .triceps {
                        RoundedRectangle(cornerRadius: 6).fill(color(for: m))
                            .frame(width: rect.width, height: rect.height)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 1.5))
                            .offset(x: 120 - rect.maxX, y: rect.minY)
                    }
                }
            }
            .frame(width: 120, height: 260)
            Text(front ? "Front" : "Back").font(Theme.captionSmall()).foregroundStyle(Theme.secondary)
        }
    }
}

/// Lets the user place exercises the built-in map doesn't know.
struct TagExercisesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Screen {
            ScreenHeader(kicker: "Tag once, used forever", title: "Muscle tags").padding(.bottom, 20)
            ForEach(model.untaggedExercises, id: \.self) { ex in
                HStack {
                    Text(ex).font(Theme.body(.semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Menu {
                        ForEach(Muscle.allCases, id: \.self) { m in
                            Button(m.title) { model.tagExercise(ex, as: ExerciseMuscles(primary: m)) }
                        }
                    } label: {
                        Text("Primary muscle").font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
                    }
                }
                .padding(.vertical, 12)
                Hairline()
            }
            if model.untaggedExercises.isEmpty {
                EmptyHint(text: "Every exercise is mapped.")
            }
        }
    }
}

// MARK: - Photos

struct PhotosView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    @State private var pose: PhotoPose? = nil
    @State private var selected: [UUID] = []
    @State private var showCamera = false
    @State private var showImport = false
    @State private var compare = false
    @State private var lock = AppState.progressLockEnabled

    private var filtered: [ProgressPhoto] { photos.filter { pose == nil || $0.pose == pose } }

    var body: some View {
        HStack(spacing: 10) {
            PillButton(title: "Take photo", tint: .white, background: Theme.ink) { showCamera = true }
            PillButton(title: "Import") { showImport = true }
            Spacer()
            Menu {
                Toggle("Face ID lock", isOn: $lock)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.pill))
            }
        }
        .padding(.bottom, 16)
        .onChange(of: lock) { _, new in AppState.progressLockEnabled = new }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PillChip(title: "All", active: pose == nil) { pose = nil }
                ForEach(PhotoPose.allCases) { p in
                    PillChip(title: p.title, active: pose == p) { pose = p }
                }
            }
        }
        .padding(.bottom, 16)

        if filtered.isEmpty {
            EmptyHint(text: "Take a front, side and back photo. Each one is tied to that day's trend weight, body fat and phase, and the camera overlays your last shot so the framing matches.")
        } else {
            Text(selected.isEmpty ? "Tap two photos to compare." : (selected.count == 1 ? "Tap one more." : "Comparing two photos."))
                .font(Theme.caption()).foregroundStyle(Theme.tertiary).padding(.bottom, 10)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(filtered) { photo in
                    PhotoThumb(photo: photo, selected: selected.contains(photo.id))
                        .onTapGesture { toggle(photo) }
                        .contextMenu {
                            Button("Delete", role: .destructive) { model.context.delete(photo) }
                        }
                }
            }
            if selected.count == 2 {
                InkButton(title: "Compare") { compare = true }.padding(.top, 16)
            }
        }
        Color.clear.frame(height: 0)
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView(defaultPose: pose ?? .front)
            }
            .sheet(isPresented: $showImport) {
                PhotoImportSheet()
            }
            .sheet(isPresented: $compare) {
                if selected.count == 2, let a = photos.first(where: { $0.id == selected[0] }), let b = photos.first(where: { $0.id == selected[1] }) {
                    PhotoCompareView(a: a.date < b.date ? a : b, b: a.date < b.date ? b : a)
                }
            }
    }

    private func toggle(_ photo: ProgressPhoto) {
        if let i = selected.firstIndex(of: photo.id) {
            selected.remove(at: i)
        } else {
            if selected.count == 2 { selected.removeFirst() }
            selected.append(photo.id)
        }
    }
}

struct PhotoThumb: View {
    let photo: ProgressPhoto
    var selected = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = UIImage(data: photo.thumbnailData ?? photo.imageData) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Theme.pill
            }
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 1) {
                Text(Fmt.shortDate(photo.date)).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Text(photo.poseTitle + (photo.trendWeightLb.map { " · \(Fmt.lb($0))" } ?? "")).font(.system(size: 10)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(8)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? Theme.accent : .clear, lineWidth: 3))
    }
}

/// Oldest and newest photo of the same pose, as a teaser on the Lifts view.
struct PhotoCompareStrip: View {
    @Query(sort: \ProgressPhoto.date) private var photos: [ProgressPhoto]
    @State private var compare = false

    private var pair: (ProgressPhoto, ProgressPhoto)? {
        for pose in PhotoPose.allCases {
            let same = photos.filter { $0.pose == pose }
            if let first = same.first, let last = same.last, first.id != last.id { return (first, last) }
        }
        return nil
    }

    var body: some View {
        if let (a, b) = pair {
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    PhotoThumb(photo: a).frame(width: 72)
                    PhotoThumb(photo: b).frame(width: 72)
                }
                VStack(alignment: .leading, spacing: 6) {
                    let weeks = max(1, Calendar.current.days(from: a.date, to: b.date) / 7)
                    Text("\(a.poseTitle) pose · \(weeks) week\(weeks == 1 ? "" : "s") apart").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                    if let wa = a.trendWeightLb, let wb = b.trendWeightLb {
                        Text("\(Fmt.lb(wa)) → \(Fmt.lb(wb)) lb trend").font(Theme.body()).foregroundStyle(Theme.secondary)
                    }
                    Button("Compare photos →") { compare = true }.font(Theme.body(.semibold)).foregroundStyle(Theme.accent)
                }
            }
            .sheet(isPresented: $compare) { PhotoCompareView(a: a, b: b) }
        } else {
            EmptyView()
        }
    }
}

/// Side by side, or a swipe slider between two dates.
struct PhotoCompareView: View {
    @Environment(\.dismiss) private var dismiss
    let a: ProgressPhoto
    let b: ProgressPhoto
    @State private var mode = 0
    @State private var split: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                SegmentedPills(options: [(0, "Side by side"), (1, "Slider")], selection: $mode)
                Spacer()
                PillButton(title: "Done") { dismiss() }
            }
            .padding(.horizontal, Theme.sideMargin)
            .padding(.top, 20)

            GeometryReader { geo in
                if mode == 0 {
                    HStack(spacing: 8) {
                        labeled(a, width: (geo.size.width - 8) / 2)
                        labeled(b, width: (geo.size.width - 8) / 2)
                    }
                } else {
                    ZStack(alignment: .leading) {
                        image(b).frame(width: geo.size.width, height: geo.size.height)
                        image(a).frame(width: geo.size.width, height: geo.size.height)
                            .mask(alignment: .leading) { Rectangle().frame(width: geo.size.width * split) }
                        Rectangle().fill(.white).frame(width: 2).offset(x: geo.size.width * split - 1)
                        Circle().fill(.white).frame(width: 28, height: 28).shadow(radius: 3)
                            .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink))
                            .offset(x: geo.size.width * split - 14)
                            .gesture(DragGesture().onChanged { g in split = max(0.02, min(0.98, g.location.x / geo.size.width)) })
                        VStack {
                            HStack {
                                caption(a).padding(8)
                                Spacer()
                                caption(b).padding(8)
                            }
                            Spacer()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, Theme.sideMargin)
            .padding(.bottom, 20)
        }
        .background(Theme.surface)
    }

    private func image(_ p: ProgressPhoto) -> some View {
        Group {
            if let img = UIImage(data: p.imageData) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Theme.pill
            }
        }
        .clipped()
    }

    private func labeled(_ p: ProgressPhoto, width: CGFloat) -> some View {
        VStack(spacing: 6) {
            image(p).frame(width: width).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            caption(p)
        }
    }

    private func caption(_ p: ProgressPhoto) -> some View {
        VStack(spacing: 1) {
            Text(Fmt.mediumDate(p.date)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
            Text([p.trendWeightLb.map { "\(Fmt.lb($0)) lb" }, p.bodyFatPercent.map { "\(Fmt.dec($0, 1))%" }, p.phase?.title].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 11)).foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(0.9)))
    }
}

// MARK: - Body

struct BodyView: View {
    @Environment(AppModel.self) private var model
    @State private var range: ChartRange = .threeMonths

    private var s: EngineSnapshot { model.snapshot }

    var body: some View {
        HStack {
            Spacer()
            SegmentedPills(options: ChartRange.allCases.map { ($0, $0.title) }, selection: $range)
        }
        .padding(.bottom, 16)

        section("Trend weight", value: s.body.trendWeightLb.map(Fmt.lb) ?? "—", unit: "lb", number: .trendWeight) {
            WeightChart(points: s.trend.filter { $0.date >= range.start() }, showDots: false, height: 150)
        }
        Hairline().padding(.vertical, 18)
        section("Lean mass", value: s.body.leanMassLb.map(Fmt.lb) ?? "—", unit: "lb", number: .leanMass) {
            let series = model.log.filter { $0.date >= range.start() }.compactMap { day in day.leanMassLb.map { DatedValue(date: day.date, value: $0) } }
            if series.count >= 2 { LineSeriesChart(series: series, height: 150, yDigits: 1) } else { EmptyHint(text: "Needs lean mass from a Health-connected scale, or body fat in Dials.") }
        }
        Hairline().padding(.vertical, 18)
        section("Body fat", value: s.body.bodyFatPercent.map { Fmt.dec($0, 1) } ?? "—", unit: "%", number: .bodyFat) {
            let series = model.log.filter { $0.date >= range.start() }.compactMap { day in day.bodyFatPercent.map { DatedValue(date: day.date, value: $0) } }
            if series.count >= 2 { LineSeriesChart(series: series, height: 150, yDigits: 1) } else { EmptyHint(text: "Needs body fat from a Health-connected scale, or a manual value in Dials.") }
        }
    }

    private func section<Content: View>(_ title: String, value: String, unit: String, number: NumberID, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(title)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                DottedNumber(text: value, number: number, font: Theme.large(36), tracking: -1.4)
                Text(unit).font(Theme.body()).foregroundStyle(Theme.secondary)
            }
            content()
        }
    }
}
