//
//  FoodEntry.swift
//  NutrAItion
//

import Foundation
import SwiftData

@Model
final class FoodEntry {
    var id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var confidence: Confidence
    var mealType: MealType
    var timestamp: Date
    var notes: String?

    var dayLog: DayLog?

    init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        confidence: Confidence,
        mealType: MealType,
        timestamp: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.confidence = confidence
        self.mealType = mealType
        self.timestamp = timestamp
        self.notes = notes
    }
}
