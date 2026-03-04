//
//  MacroTargetCalculatorTests.swift
//  NutrAItionTests
//

import XCTest
@testable import NutrAItion

final class MacroTargetCalculatorTests: XCTestCase {

    func test_calculate_cut_reducesCaloriesBy400() {
        let result = MacroTargetCalculator.calculate(tdee: 2500, goalType: .cut, bodyWeightKg: 80, leanMassKg: nil)
        XCTAssertEqual(result.calories, 2100)
        XCTAssertEqual(result.goalType, .cut)
    }

    func test_calculate_bulk_increasesCaloriesBy300() {
        let result = MacroTargetCalculator.calculate(tdee: 2500, goalType: .bulk, bodyWeightKg: 80, leanMassKg: nil)
        XCTAssertEqual(result.calories, 2800)
        XCTAssertEqual(result.goalType, .bulk)
    }

    func test_calculate_withDEXA_usesLeanMassForProtein() {
        let withDEXA = MacroTargetCalculator.calculate(tdee: 2000, goalType: .maintain, bodyWeightKg: 80, leanMassKg: 60)
        let withoutDEXA = MacroTargetCalculator.calculate(tdee: 2000, goalType: .maintain, bodyWeightKg: 80, leanMassKg: nil)
        let proteinWithDEXA = withDEXA.protein   // 60 * 2.2 * 1.0 = 132
        let proteinWithoutDEXA = withoutDEXA.protein // 80 * 2.2 * 0.85 = 149.6
        XCTAssertEqual(proteinWithDEXA, 132, accuracy: 0.01)
        XCTAssertEqual(proteinWithoutDEXA, 149.6, accuracy: 0.01)
        XCTAssertLessThan(proteinWithDEXA, proteinWithoutDEXA)
    }

    func test_calculate_proteinNeverReducedBelowFloor() {
        let result = MacroTargetCalculator.calculate(tdee: 1500, goalType: .cut, bodyWeightKg: 80, leanMassKg: nil)
        let proteinFloor = 80 * 2.2 * 0.85
        XCTAssertEqual(result.protein, proteinFloor, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(result.protein, proteinFloor)
    }

    func test_calculate_macrosSumToTotalCalories() {
        let result = MacroTargetCalculator.calculate(tdee: 2200, goalType: .maintain, bodyWeightKg: 70, leanMassKg: nil)
        let computedCal = result.protein * 4 + result.carbs * 4 + result.fat * 9
        XCTAssertEqual(computedCal, result.calories, accuracy: 0.5)
    }
}
