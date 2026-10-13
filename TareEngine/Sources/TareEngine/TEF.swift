import Foundation

/// Thermic effect of food.
public enum TEF {
    /// kcal burned digesting the given macros under the dials' TEF settings.
    public static func kcal(proteinG: Double, carbsG: Double, fatG: Double, dials: Dials) -> Double {
        let pKcal = proteinG * 4
        let cKcal = carbsG * 4
        let fKcal = fatG * 9
        switch dials.tefMode {
        case .byMacro:
            return pKcal * dials.tefProteinPercent / 100
                + cKcal * dials.tefCarbPercent / 100
                + fKcal * dials.tefFatPercent / 100
        case .flat:
            return (pKcal + cKcal + fKcal) * dials.tefFlatPercent / 100
        }
    }
}
