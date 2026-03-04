//
//  UserProfile.swift
//  NutrAItion
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var age: Int
    var sex: BiologicalSex
    var heightCm: Double
    var currentWeightKg: Double
    var goalType: GoalType
    var tdeeEstimate: Double
    /// JSON-encoded [String: Double]. Persisting as Data avoids Swift 6 main-actor isolation on custom Codable.
    var effortMultipliersData: Data
    var weeklyAdjustmentCount: Int
    var leanMassKg: Double?
    var createdAt: Date

    /// Per-bucket effort adjustments (e.g. "low" -> 1.0). Backed by effortMultipliersData (JSON).
    var effortMultipliers: [String: Double] {
        get {
            (try? JSONDecoder().decode([String: Double].self, from: effortMultipliersData)) ?? [:]
        }
        set {
            effortMultipliersData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(
        id: UUID = UUID(),
        age: Int,
        sex: BiologicalSex,
        heightCm: Double,
        currentWeightKg: Double,
        goalType: GoalType,
        tdeeEstimate: Double,
        effortMultipliers: [String: Double] = [:],
        weeklyAdjustmentCount: Int = 0,
        leanMassKg: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.age = age
        self.sex = sex
        self.heightCm = heightCm
        self.currentWeightKg = currentWeightKg
        self.goalType = goalType
        self.tdeeEstimate = tdeeEstimate
        self.effortMultipliersData = (try? JSONEncoder().encode(effortMultipliers)) ?? Data()
        self.weeklyAdjustmentCount = weeklyAdjustmentCount
        self.leanMassKg = leanMassKg
        self.createdAt = createdAt
    }
}
