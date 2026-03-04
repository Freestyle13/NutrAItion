//
//  MacroTargetCalculator.swift
//  NutrAItion
//

import Foundation

/// Pure calculator: same inputs → same outputs. No HealthKit, SwiftData, or network.
/// Protein is always the floor; fat = 25% of calories; carbs = remainder.
struct MacroTargetCalculator {
    static func calculate(
        tdee: Double,
        goalType: GoalType,
        bodyWeightKg: Double,
        leanMassKg: Double?
    ) -> MacroTargets {
        let calories: Double
        switch goalType {
        case .cut: calories = tdee - 400
        case .bulk: calories = tdee + 300
        case .maintain: calories = tdee
        }

        let proteinG: Double
        if let lean = leanMassKg {
            proteinG = lean * 2.2 * 1.0  // 1.0g per lb lean mass (DEXA)
        } else {
            proteinG = bodyWeightKg * 2.2 * 0.85  // 0.85g per lb bodyweight
        }

        let fatG = (calories * 0.25) / 9
        let proteinCal = proteinG * 4
        let fatCal = fatG * 9
        let carbCal = calories - proteinCal - fatCal
        let carbG = max(0, carbCal) / 4
        let lowCarbWarning = carbG < 50

        return MacroTargets(
            calories: calories,
            protein: proteinG,
            carbs: carbG,
            fat: fatG,
            goalType: goalType,
            generatedAt: Date(),
            lowCarbWarning: lowCarbWarning
        )
    }
}
