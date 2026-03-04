//
//  MacroTargetCalculator.swift
//  NutrAItion
//

import Foundation

/// Pure calculator: same inputs → same outputs. No HealthKit, SwiftData, or network.
/// Phase 2 will expand with full protein/fat/carb rules; this stub satisfies AppState for Phase 1.
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
        let proteinKg = leanMassKg ?? bodyWeightKg
        let proteinG = proteinKg * 2.2 * 0.85 // 0.85g per lb bodyweight
        let fatCal = calories * 0.25
        let fatG = fatCal / 9
        let proteinCal = proteinG * 4
        let carbCal = max(0, calories - proteinCal - fatCal)
        let carbG = carbCal / 4
        return MacroTargets(
            calories: calories,
            protein: proteinG,
            carbs: carbG,
            fat: fatG,
            goalType: goalType,
            generatedAt: Date()
        )
    }
}
