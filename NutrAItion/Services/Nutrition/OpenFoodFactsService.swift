import Foundation

enum OpenFoodFactsError: Error {
    case invalidURL
    case invalidResponse
    case decodingFailed
    case missingProduct
}

final class OpenFoodFactsService {
    private let baseURL = "https://world.openfoodfacts.org/api/v2/product"
    private let session = URLSession.shared

    func lookupBarcode(_ upc: String) async throws -> FoodResult? {
        guard let encoded = upc.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw OpenFoodFactsError.invalidURL
        }
        guard let url = URL(string: "\(baseURL)/\(encoded).json") else {
            throw OpenFoodFactsError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw OpenFoodFactsError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw OpenFoodFactsError.invalidResponse
        }

        return try Self.parseBarcodeResponse(from: data)
    }

    /// Pure parse — safe for unit tests (no network, no Observation).
    static func parseBarcodeResponse(from data: Data) throws -> FoodResult? {
        let decoder = JSONDecoder()
        let wrapper: OFFProductResponse
        do {
            wrapper = try decoder.decode(OFFProductResponse.self, from: data)
        } catch {
            throw OpenFoodFactsError.decodingFailed
        }

        guard wrapper.status == 1 else {
            return nil
        }
        guard let product = wrapper.product else {
            throw OpenFoodFactsError.missingProduct
        }

        let servingGrams = parseServingGrams(from: product.servingSize) ?? 100.0
        let servingLabel = product.servingSize ?? "\(Int(servingGrams)) g"

        let nutriments = product.nutriments
        func per100g(_ field: FlexibleDouble?) -> Double? {
            field?.value
        }
        let caloriesPer100g = nutriments.flatMap { per100g($0.energyKcal100g) }
        let proteinPer100g = nutriments.flatMap { per100g($0.proteins100g) }
        let carbsPer100g = nutriments.flatMap { per100g($0.carbohydrates100g) }
        let fatPer100g = nutriments.flatMap { per100g($0.fat100g) }

        let hasMissingMacros = [
            caloriesPer100g,
            proteinPer100g,
            carbsPer100g,
            fatPer100g,
        ].contains(nil)

        let calories = (caloriesPer100g ?? 0) / 100.0 * servingGrams
        let protein = (proteinPer100g ?? 0) / 100.0 * servingGrams
        let carbs = (carbsPer100g ?? 0) / 100.0 * servingGrams
        let fat = (fatPer100g ?? 0) / 100.0 * servingGrams

        let imageURL = product.imageURL.flatMap { URL(string: $0) }

        return FoodResult(
            nixItemId: nil,
            foodName: product.productName ?? "Unknown food",
            brandName: product.brands,
            servingQty: 1.0,
            servingUnit: "g",
            servingWeightGrams: servingGrams,
            servingOptions: [FoodResult.ServingOption(label: servingLabel, grams: servingGrams)],
            calories: calories,
            protein: protein,
            totalCarbohydrate: carbs,
            totalFat: fat,
            thumbnail: imageURL,
            hasMissingMacros: hasMissingMacros,
            source: .openFoodFacts
        )
    }

    private static func parseServingGrams(from servingSize: String?) -> Double? {
        guard let servingSize else { return nil }

        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*g\b"#
        guard let match = servingSize.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let captured = servingSize[match].replacingOccurrences(of: "g", with: "", options: .caseInsensitive)
        let numeric = captured.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(numeric)
    }
}

// MARK: - Open Food Facts DTOs

private struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let productName: String?
    let brands: String?
    let imageURL: String?
    let servingSize: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case imageURL = "image_url"
        case servingSize = "serving_size"
        case nutriments
    }
}

private struct OFFNutriments: Decodable {
    let energyKcal100g: FlexibleDouble?
    let proteins100g: FlexibleDouble?
    let carbohydrates100g: FlexibleDouble?
    let fat100g: FlexibleDouble?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
}

private struct FlexibleDouble: Decodable {
    let value: Double?

    init(value: Double?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()

        if let d = try? c.decode(Double.self) {
            value = d
            return
        }

        if let s = try? c.decode(String.self) {
            let normalized = s.replacingOccurrences(of: ",", with: "")
            value = Double(normalized)
            return
        }

        value = nil
    }
}
