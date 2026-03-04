//
//  UserProfile.swift
//  NutrAItion
//

import Foundation
import SwiftData

/// Wraps [String: Double] for SwiftData persistence (SwiftData doesn't persist raw Dictionary).
struct EffortMultipliersStorage: Codable {
    var values: [String: Double]
    init(_ values: [String: Double] = [:]) { self.values = values }
}

@Model
final class UserProfile {
    var id: UUID
    var age: Int
    var sex: BiologicalSex
    var heightCm: Double
    var currentWeightKg: Double
    var goalType: GoalType
    var tdeeEstimate: Double
    var effortMultipliersData: EffortMultipliersStorage
    var weeklyAdjustmentCount: Int
    var leanMassKg: Double?
    var createdAt: Date

    /// Per-bucket effort adjustments (e.g. "low" -> 1.0). Stored via EffortMultipliersStorage for SwiftData.
    var effortMultipliers: [String: Double] {
        get { effortMultipliersData.values }
        set { effortMultipliersData = EffortMultipliersStorage(newValue) }
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
        self.effortMultipliersData = EffortMultipliersStorage(effortMultipliers)
        self.weeklyAdjustmentCount = weeklyAdjustmentCount
        self.leanMassKg = leanMassKg
        self.createdAt = createdAt
    }
}
