import XCTest
@testable import NutrAItion

final class OpenFoodFactsServiceTests: XCTestCase {
    func test_parseBarcodeResponse_serving30g_convertsPer100gToPerServingMacros() throws {
        let json = """
        {
          "status": 1,
          "product": {
            "product_name": "Test Bar",
            "brands": "Test Brand",
            "image_url": "https://example.com/test.jpg",
            "serving_size": "30 g",
            "nutriments": {
              "energy-kcal_100g": 200,
              "proteins_100g": 10,
              "carbohydrates_100g": 30,
              "fat_100g": 5
            }
          }
        }
        """

        let data = Data(json.utf8)
        let service = OpenFoodFactsService()

        let result = try service.parseBarcodeResponse(from: data)
        XCTAssertNotNil(result)

        guard let food = result else { return }
        XCTAssertEqual(food.calories, 60.0, accuracy: 0.0001)
        XCTAssertEqual(food.protein, 3.0, accuracy: 0.0001)
        XCTAssertEqual(food.totalCarbohydrate, 9.0, accuracy: 0.0001)
        XCTAssertEqual(food.totalFat, 1.5, accuracy: 0.0001)

        XCTAssertEqual(food.servingWeightGrams, 30.0, accuracy: 0.0001)
        XCTAssertEqual(food.hasMissingMacros, false)
        XCTAssertEqual(food.source, .openFoodFacts)
    }
}

