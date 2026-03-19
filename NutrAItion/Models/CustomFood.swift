//
//  CustomFood.swift
//  NutrAItion
//

import Foundation
import SwiftData

@Model
final class CustomFood {
    var id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    /// Display-only metadata (helps search UX later).
    var servingQty: Double
    var servingUnit: String

    var createdAt: Date
    var lastUsedAt: Date?
    var useCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        servingQty: Double = 1,
        servingUnit: String = "serving",
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        useCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingQty = servingQty
        self.servingUnit = servingUnit
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }
}

