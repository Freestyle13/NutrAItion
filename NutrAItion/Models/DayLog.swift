//
//  DayLog.swift
//  NutrAItion
//

import Foundation
import SwiftData

@Model
final class DayLog {
    var id: UUID
    var date: Date
    var effortLevel: EffortLevel
    var rawWeight: Double?
    var smoothedWeight: Double?
    var tdeeEstimateAtDate: Double

    @Relationship(deleteRule: .cascade, inverse: \FoodEntry.dayLog) var entries: [FoodEntry] = []

    init(
        id: UUID = UUID(),
        date: Date,
        effortLevel: EffortLevel,
        rawWeight: Double? = nil,
        smoothedWeight: Double? = nil,
        tdeeEstimateAtDate: Double
    ) {
        self.id = id
        self.date = date
        self.effortLevel = effortLevel
        self.rawWeight = rawWeight
        self.smoothedWeight = smoothedWeight
        self.tdeeEstimateAtDate = tdeeEstimateAtDate
    }
}
