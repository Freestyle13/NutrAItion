//
//  FoodExtractionParserTests.swift
//  NutrAItionTests
//

import XCTest
@testable import NutrAItion

final class FoodExtractionParserTests: XCTestCase {
    func test_parse_stripsMarkdownFences_returnsItems() throws {
        let json = """
        ```json
        {"items":[{"name":"Egg","estimated_calories":70,"estimated_protein":6,"estimated_carbs":1,"estimated_fat":5,"confidence":"high","portion_description":"1 large"}]}
        ```
        """
        let items = try FoodExtractionParser().parse(jsonString: json)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Egg")
        XCTAssertEqual(items[0].estimatedCalories, 70, accuracy: 0.01)
    }

    func test_toFoodEntries_usesEstimatedConfidence() {
        let items = [
            ExtractedFoodItem(
                name: "Apple",
                estimatedCalories: 95,
                estimatedProtein: 0.5,
                estimatedCarbs: 25,
                estimatedFat: 0.3,
                confidence: "medium",
                portionDescription: "1 medium"
            ),
        ]
        let entries = FoodExtractionParser().toFoodEntries(items, mealType: .snack)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].confidence, .estimated)
        XCTAssertEqual(entries[0].mealType, .snack)
        XCTAssertTrue(entries[0].notes?.contains("1 medium") == true)
    }
}
