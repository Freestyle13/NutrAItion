//
//  EffortScoreCalculatorTests.swift
//  NutrAItionTests
//

import XCTest
import HealthKit
@testable import NutrAItion

final class EffortScoreCalculatorTests: XCTestCase {
    private let calculator = EffortScoreCalculator()

    // MARK: - Helper

    private func makeMockHRSample(bpm: Double, date: Date, durationMinutes: Double = 1.0) -> HKQuantitySample {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let quantity = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: bpm)
        let end = date.addingTimeInterval(durationMinutes * 60)
        return HKQuantitySample(type: type, quantity: quantity, start: date, end: end)
    }

    // MARK: - calculate (no HR, calories fallback)

    func test_calculate_noHRSamples_lowCalories_returnsRest() {
        let result = calculator.calculate(heartRateSamples: [], activeCalories: 30, age: 30)
        XCTAssertEqual(result, .rest)
    }

    func test_calculate_noHRSamples_highCalories_returnsVeryHigh() {
        let result = calculator.calculate(heartRateSamples: [], activeCalories: 700, age: 30)
        XCTAssertEqual(result, .veryHigh)
    }

    // MARK: - calculate (HR zones)

    func test_calculate_allZone4HR_returnsHigh() {
        // Age 30 → maxHR 190. Zone 4 = 80–90% → 152–171 bpm. Use 85% = 161.5 bpm.
        let base = Calendar.current.startOfDay(for: Date())
        let samples = (0..<30).map { i in
            makeMockHRSample(bpm: 161.5, date: base.addingTimeInterval(TimeInterval(i * 60)))
        }
        let result = calculator.calculate(heartRateSamples: samples, activeCalories: 0, age: 30)
        XCTAssertEqual(result, .high)
    }

    func test_calculate_mixedZones_returnsModerate() {
        // Age 30, maxHR 190. Zone 1 < 114 bpm, zone 3 = 133–152 bpm.
        // 10 min zone 1 (e.g. 95 bpm) + 40 min zone 3 (e.g. 142 bpm) → normalized ~46 → .moderate
        let base = Calendar.current.startOfDay(for: Date())
        var samples: [HKQuantitySample] = []
        for i in 0..<10 {
            samples.append(makeMockHRSample(bpm: 95, date: base.addingTimeInterval(TimeInterval(i * 60))))
        }
        for i in 0..<40 {
            samples.append(makeMockHRSample(bpm: 142, date: base.addingTimeInterval(TimeInterval((10 + i) * 60))))
        }
        let result = calculator.calculate(heartRateSamples: samples, activeCalories: 0, age: 30)
        XCTAssertEqual(result, .moderate)
    }

    // MARK: - calorieAdjustment

    func test_calorieAdjustment_rest_returnsNegative200() {
        let result = calculator.calorieAdjustment(for: .rest, multipliers: nil)
        XCTAssertEqual(result, -200.0)
    }

    func test_calorieAdjustment_customMultipliers_usesCustomValues() {
        let custom: [String: Double] = [
            EffortLevel.rest.rawValue: -300,
            EffortLevel.high.rawValue: 200,
        ]
        XCTAssertEqual(calculator.calorieAdjustment(for: .rest, multipliers: custom), -300)
        XCTAssertEqual(calculator.calorieAdjustment(for: .high, multipliers: custom), 200)
        // Unspecified level uses default
        XCTAssertEqual(calculator.calorieAdjustment(for: .moderate, multipliers: custom), 0)
    }
}
