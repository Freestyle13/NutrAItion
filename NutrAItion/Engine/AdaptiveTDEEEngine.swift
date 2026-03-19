//
//  AdaptiveTDEEEngine.swift
//  NutrAItion
//

import Foundation
import SwiftData

// MARK: - Output types

enum EngineConfidence: String, CaseIterable, Codable {
    case insufficient
    case low
    case medium
    case high
}

struct TDEEAdjustment: Equatable {
    var recommendedTDEE: Double
    var previousTDEE: Double
    var delta: Double
    var confidence: EngineConfidence
    var reasoning: String
    var dataPointsUsed: Int
    var weeksCovered: Int
}

// MARK: - Engine

/// Pure analysis: pass `DayLog` + entries in; no I/O.
struct AdaptiveTDEEEngine {
    private let calendar: Calendar
    private let effortCalculator: EffortScoreCalculator

    init(
        calendar: Calendar = {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "UTC")!
            return c
        }(),
        effortCalculator: EffortScoreCalculator = EffortScoreCalculator()
    ) {
        self.calendar = calendar
        self.effortCalculator = effortCalculator
    }

    func analyze(
        dayLogs: [DayLog],
        currentTDEE: Double,
        effortMultipliers: [String: Double] = [:]
    ) -> TDEEAdjustment {
        let valid = dayLogs.filter { log in
            log.smoothedWeight != nil && !log.entries.isEmpty
        }
        .sorted { calendar.startOfDay(for: $0.date) < calendar.startOfDay(for: $1.date) }

        let weeksCovered = max(1, valid.count / 7)

        if valid.count < 28 {
            return TDEEAdjustment(
                recommendedTDEE: currentTDEE,
                previousTDEE: currentTDEE,
                delta: 0,
                confidence: .insufficient,
                reasoning: "Need at least 28 days with smoothed weight and at least one food entry per day. You have \(valid.count) qualifying days.",
                dataPointsUsed: valid.count,
                weeksCovered: weeksCovered
            )
        }

        let firstDate = calendar.startOfDay(for: valid.first!.date)
        let lastDate = calendar.startOfDay(for: valid.last!.date)
        let spanDays = max(1, calendar.dateComponents([.day], from: firstDate, to: lastDate).day! + 1)
        let coverageRatio = Double(valid.count) / Double(spanDays)

        let window = Array(valid.suffix(14))
        let windowDays = window.count
        guard windowDays >= 1 else {
            return insufficient(currentTDEE: currentTDEE, validCount: valid.count, weeks: weeksCovered, reason: "No analysis window.")
        }

        let weightStart = window.first!.smoothedWeight!
        let weightEnd = window.last!.smoothedWeight!
        let actualDeltaKg = weightEnd - weightStart

        if abs(actualDeltaKg) > 3.0 {
            return TDEEAdjustment(
                recommendedTDEE: currentTDEE,
                previousTDEE: currentTDEE,
                delta: 0,
                confidence: .low,
                reasoning: "Weight changed by \(String(format: "%.1f", abs(actualDeltaKg))) kg in the last 14 logged days — likely a data anomaly. No TDEE change applied.",
                dataPointsUsed: windowDays,
                weeksCovered: 2
            )
        }

        var weightedCaloriesTotal = 0.0
        for log in window {
            for entry in log.entries {
                weightedCaloriesTotal += entry.calories * Self.intakeConfidenceWeight(entry.confidence)
            }
        }
        let weightedAverageIntake = weightedCaloriesTotal / Double(windowDays)

        let mults: [String: Double]? = effortMultipliers.isEmpty ? nil : effortMultipliers
        var effortAdjSum = 0.0
        for log in window {
            effortAdjSum += effortCalculator.calorieAdjustment(for: log.effortLevel, multipliers: mults)
        }
        let avgEffortAdj = effortAdjSum / Double(windowDays)

        let expectedDailyBalance = weightedAverageIntake - (currentTDEE + avgEffortAdj)
        let expectedTotalWeightChangeKg = (expectedDailyBalance * Double(windowDays)) / 7700.0

        let errorKg = actualDeltaKg - expectedTotalWeightChangeKg
        let errorCal = errorKg * 7700.0 / Double(windowDays)
        var rawAdjustment = errorCal * 0.15
        var clampedAdjustment = max(-100, min(100, rawAdjustment))

        var confidence: EngineConfidence
        if coverageRatio < 0.70 {
            confidence = .low
            clampedAdjustment *= 0.5
        } else if valid.count >= 28, coverageRatio > 0.85, abs(actualDeltaKg) < 1.5 {
            confidence = .high
        } else {
            confidence = .medium
        }

        let newTDEE = currentTDEE + clampedAdjustment
        let reasoning = makeReasoning(
            actualDeltaKg: actualDeltaKg,
            expectedDeltaKg: expectedTotalWeightChangeKg,
            clampedAdjustment: clampedAdjustment,
            weightedAverageIntake: weightedAverageIntake,
            currentTDEE: currentTDEE,
            avgEffortAdj: avgEffortAdj
        )

        return TDEEAdjustment(
            recommendedTDEE: newTDEE,
            previousTDEE: currentTDEE,
            delta: clampedAdjustment,
            confidence: confidence,
            reasoning: reasoning,
            dataPointsUsed: windowDays,
            weeksCovered: 2
        )
    }

    private func insufficient(
        currentTDEE: Double,
        validCount: Int,
        weeks: Int,
        reason: String
    ) -> TDEEAdjustment {
        TDEEAdjustment(
            recommendedTDEE: currentTDEE,
            previousTDEE: currentTDEE,
            delta: 0,
            confidence: .insufficient,
            reasoning: reason,
            dataPointsUsed: validCount,
            weeksCovered: weeks
        )
    }

    private static func intakeConfidenceWeight(_ c: Confidence) -> Double {
        switch c {
        case .precise: return 1.0
        case .manual: return 1.0
        case .estimated: return 0.7
        }
    }

    private func makeReasoning(
        actualDeltaKg: Double,
        expectedDeltaKg: Double,
        clampedAdjustment: Double,
        weightedAverageIntake: Double,
        currentTDEE: Double,
        avgEffortAdj: Double
    ) -> String {
        let actualDesc = actualDeltaKg >= 0
            ? "gained \(String(format: "%.2f", actualDeltaKg)) kg"
            : "lost \(String(format: "%.2f", abs(actualDeltaKg))) kg"
        let expectedDesc = expectedDeltaKg >= 0
            ? "predicted gain \(String(format: "%.2f", expectedDeltaKg)) kg"
            : "predicted loss \(String(format: "%.2f", abs(expectedDeltaKg))) kg"
        let adj = Int(clampedAdjustment.rounded())
        return
            "Over the last 14 logged days you \(actualDesc); we \(expectedDesc) from intake (~\(Int(weightedAverageIntake)) cal/day) vs TDEE+effort (~\(Int(currentTDEE + avgEffortAdj)) cal/day). Adjusting TDEE by \(adj >= 0 ? "+" : "")\(adj) cal/day (capped at ±100)."
    }
}
