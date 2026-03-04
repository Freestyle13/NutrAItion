//
//  EffortScoreCalculator.swift
//  NutrAItion
//

import Foundation
import HealthKit

/// Minutes spent in each heart-rate zone (percentage of max HR).
struct ZoneDistribution {
    var zone1Minutes: Double  // <60% HRmax
    var zone2Minutes: Double  // 60–70%
    var zone3Minutes: Double  // 70–80%
    var zone4Minutes: Double  // 80–90%
    var zone5Minutes: Double  // >90%

    var totalMinutes: Double {
        zone1Minutes + zone2Minutes + zone3Minutes + zone4Minutes + zone5Minutes
    }
}

/// Pure logic: converts HR samples + active calories into a daily EffortLevel. No HealthKit queries, no SwiftData, no UI.
struct EffortScoreCalculator {
    private static let heartRateUnit = HKUnit(from: "count/min")

    /// Converts raw HR samples and active calories into a single daily effort level.
    /// Falls back to calories-only when no HR samples are provided.
    func calculate(
        heartRateSamples: [HKQuantitySample],
        activeCalories: Double,
        age: Int
    ) -> EffortLevel {
        let maxHR = Double(220 - age)
        if maxHR <= 0 { return effortFromActiveCaloriesOnly(activeCalories) }

        let distribution = zoneDistribution(samples: heartRateSamples, maxHR: maxHR)
        if distribution.totalMinutes <= 0 {
            return effortFromActiveCaloriesOnly(activeCalories)
        }

        let weightedScore = distribution.zone1Minutes * 0.3
            + distribution.zone2Minutes * 0.5
            + distribution.zone3Minutes * 0.7
            + distribution.zone4Minutes * 0.9
            + distribution.zone5Minutes * 1.0
        let normalizedScore = (weightedScore / distribution.totalMinutes - 0.3) / 0.7 * 100
        return effortFromNormalizedScore(max(0, min(100, normalizedScore)))
    }

    /// Default calorie adjustments (cal from TDEE). Use custom multipliers when provided.
    func calorieAdjustment(for level: EffortLevel, multipliers: [String: Double]?) -> Double {
        if let value = multipliers?[level.rawValue] { return value }
        switch level {
        case .rest: return -200
        case .low: return -100
        case .moderate: return 0
        case .high: return 150
        case .veryHigh: return 300
        }
    }

    /// Minutes per zone from HR samples. Zones: 1 <60%, 2 60–70%, 3 70–80%, 4 80–90%, 5 >90% of max HR.
    private func zoneDistribution(samples: [HKQuantitySample], maxHR: Double) -> ZoneDistribution {
        var z1 = 0.0, z2 = 0.0, z3 = 0.0, z4 = 0.0, z5 = 0.0
        for sample in samples {
            let hr = sample.quantity.doubleValue(for: Self.heartRateUnit)
            let durationMinutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
            if hr < 0.60 * maxHR { z1 += durationMinutes }
            else if hr < 0.70 * maxHR { z2 += durationMinutes }
            else if hr < 0.80 * maxHR { z3 += durationMinutes }
            else if hr < 0.90 * maxHR { z4 += durationMinutes }
            else { z5 += durationMinutes }
        }
        return ZoneDistribution(
            zone1Minutes: z1,
            zone2Minutes: z2,
            zone3Minutes: z3,
            zone4Minutes: z4,
            zone5Minutes: z5
        )
    }

    // MARK: - Private helpers

    private func effortFromNormalizedScore(_ score: Double) -> EffortLevel {
        switch score {
        case ..<16: return .rest
        case ..<36: return .low
        case ..<61: return .moderate
        case ..<81: return .high
        default: return .veryHigh
        }
    }

    private func effortFromActiveCaloriesOnly(_ activeCalories: Double) -> EffortLevel {
        switch activeCalories {
        case ..<51: return .rest
        case ..<201: return .low
        case ..<401: return .moderate
        case ..<601: return .high
        default: return .veryHigh
        }
    }
}
