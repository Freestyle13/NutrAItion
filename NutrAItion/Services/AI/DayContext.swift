//
//  DayContext.swift
//  NutrAItion
//

import Foundation

/// Snapshot of the user’s day for Claude system prompts (food extraction + coach chat).
struct DayContext: Equatable, Sendable {
    var calorieTarget: Double
    var remainingCalories: Double
    var proteinTarget: Double
    var proteinLogged: Double
    var goalType: GoalType
    var effortLevel: EffortLevel?

    var effortDescription: String {
        effortLevel?.displayName ?? "Not available"
    }
}
