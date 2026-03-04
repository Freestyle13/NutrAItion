//
//  MacroTargets.swift
//  NutrAItion
//

import Foundation

/// Computed on the fly from UserProfile + engine; not persisted.
struct MacroTargets {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var goalType: GoalType
    var generatedAt: Date
    /// True when carb target is very low (<50g); caller may show a warning.
    var lowCarbWarning: Bool = false

    var summary: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let calStr = formatter.string(from: NSNumber(value: Int(calories.rounded()))) ?? "\(Int(calories.rounded()))"
        let p = Int(protein.rounded())
        let c = Int(carbs.rounded())
        let f = Int(fat.rounded())
        return "\(calStr) cal · \(p)g protein · \(c)g carbs · \(f)g fat"
    }
}
