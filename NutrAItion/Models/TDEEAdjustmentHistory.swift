//
//  TDEEAdjustmentHistory.swift
//  NutrAItion
//

import Foundation
import SwiftData

/// History entries for what the adaptive TDEE engine decided over time.
/// This powers the later "trust" UI in the Trends view.
@Model
final class TDEEAdjustmentHistory {
    var id: UUID
    var date: Date
    var previousTDEE: Double
    var newTDEE: Double
    var delta: Double
    /// Stored as a string for Codable compatibility and easy debugging.
    var confidence: String
    var reasoning: String

    init(
        id: UUID = UUID(),
        date: Date,
        previousTDEE: Double,
        newTDEE: Double,
        delta: Double,
        confidence: String,
        reasoning: String
    ) {
        self.id = id
        self.date = date
        self.previousTDEE = previousTDEE
        self.newTDEE = newTDEE
        self.delta = delta
        self.confidence = confidence
        self.reasoning = reasoning
    }
}

