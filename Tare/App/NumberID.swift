import Foundation
import TareEngine

/// Every tappable number in the app. The number-detail sheet renders one of these.
enum NumberID: Hashable, Identifiable {
    case target, remaining, protein, carbs, fat, water
    case weight, trendWeight, steps, maintenance, actualRate, goalRate
    case observedTDEE, formulaTDEE, trust, bmr, bodyFat, leanMass
    case sets(Muscle)
    case e1rm(String)
    case sensitivity(DialKey)

    var id: String {
        switch self {
        case .sets(let m): return "sets:\(m.rawValue)"
        case .e1rm(let e): return "e1rm:\(e)"
        case .sensitivity(let k): return "sensitivity:\(k.rawValue)"
        default: return "\(self)"
        }
    }

    var title: String {
        switch self {
        case .target: return "Today's target"
        case .remaining: return "Remaining today"
        case .protein: return "Protein"
        case .carbs: return "Carbs"
        case .fat: return "Fat"
        case .water: return "Water"
        case .weight: return "Weight"
        case .trendWeight: return "Trend weight"
        case .steps: return "Steps"
        case .maintenance: return "Maintenance"
        case .actualRate: return "Actual rate"
        case .goalRate: return "Goal rate"
        case .observedTDEE: return "Observed TDEE"
        case .formulaTDEE: return "Formula TDEE"
        case .trust: return "Trust in your data"
        case .bmr: return "BMR"
        case .bodyFat: return "Body fat"
        case .leanMass: return "Lean mass"
        case .sets(let m): return "\(m.title) hard sets"
        case .e1rm(let e): return "\(e) 1RM"
        case .sensitivity: return "Sensitivity"
        }
    }

    /// The dial group "Tune these dials" jumps to.
    var dialGroup: DialGroup {
        switch self {
        case .target, .remaining, .goalRate: return .goal
        case .protein, .carbs, .fat: return .macros
        case .water: return .display
        case .weight, .trendWeight, .bodyFat, .leanMass: return .body
        case .steps, .formulaTDEE: return .activity
        case .maintenance, .observedTDEE, .actualRate, .trust: return .adaptive
        case .bmr: return .bmr
        case .sets, .e1rm: return .progress
        case .sensitivity(let key): return DialCatalog.spec(for: key, in: Dials())?.group ?? .body
        }
    }

    /// Parses the IDs the coach puts in its math rows.
    static func parse(_ s: String) -> NumberID? {
        if s.hasPrefix("sets:"), let m = Muscle(rawValue: String(s.dropFirst(5))) { return .sets(m) }
        if s.hasPrefix("e1rm:") { return .e1rm(String(s.dropFirst(5))) }
        switch s {
        case "target": return .target
        case "protein": return .protein
        case "steps": return .steps
        case "maintenance": return .maintenance
        case "actualRate": return .actualRate
        case "goalRate": return .goalRate
        case "trust": return .trust
        case "bodyFat": return .bodyFat
        case "weight": return .weight
        default: return nil
        }
    }
}
