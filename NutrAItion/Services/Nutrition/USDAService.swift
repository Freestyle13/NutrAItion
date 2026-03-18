import Foundation

enum USDAServiceError: Error {
    case invalidURL
    case unauthorized
    case rateLimited
    case networkError(String)
    case decodingFailed
    case missingFoodDescription
}

@Observable
final class USDAService {
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func searchFood(_ query: String) async throws -> [FoodResult] {
        let key = KeychainManager.load(key: Keys.usdaApiKey) ?? ""
        guard !key.isEmpty else { throw USDAServiceError.unauthorized }

        var comps = URLComponents(string: "\(baseURL)/foods/search")
        guard comps != nil else { throw USDAServiceError.invalidURL }
        comps!.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "20"),
            URLQueryItem(name: "dataType", value: "Branded,Survey(FNDDS)"),
            URLQueryItem(name: "api_key", value: key),
        ]
        guard let url = comps?.url else { throw USDAServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw USDAServiceError.networkError("Invalid response")
        }
        switch http.statusCode {
        case 200...299:
            break
        case 401:
            throw USDAServiceError.unauthorized
        case 429:
            throw USDAServiceError.rateLimited
        default:
            throw USDAServiceError.networkError("HTTP \(http.statusCode)")
        }

        let wrapper: USDAFoodsSearchResponse
        do {
            wrapper = try decoder.decode(USDAFoodsSearchResponse.self, from: data)
        } catch {
            throw USDAServiceError.decodingFailed
        }

        let results: [FoodResult] = (wrapper.foods ?? []).compactMap { food in
            guard let calories = foodMacro(food.foodNutrients, nutrientId: 1008) else { return nil }
            if calories == 0 { return nil }

            let protein = foodMacro(food.foodNutrients, nutrientId: 1003) ?? 0
            let carbs = foodMacro(food.foodNutrients, nutrientId: 1005) ?? 0
            let fat = foodMacro(food.foodNutrients, nutrientId: 1004) ?? 0

            let hasMissingMacros = [
                foodMacro(food.foodNutrients, nutrientId: 1008),
                foodMacro(food.foodNutrients, nutrientId: 1003),
                foodMacro(food.foodNutrients, nutrientId: 1005),
                foodMacro(food.foodNutrients, nutrientId: 1004),
            ].contains(nil)

            let servingSize = food.servingSize ?? 100.0
            let servingUnit = food.servingSizeUnit ?? "g"
            let servingLabel = "\(servingSize, specifier: "%.0f") \(servingUnit)"

            return FoodResult(
                nixItemId: nil,
                foodName: food.description ?? "Unknown food",
                brandName: food.brandOwner,
                servingQty: 1.0,
                servingUnit: servingUnit,
                servingWeightGrams: servingSize,
                servingOptions: [FoodResult.ServingOption(label: servingLabel, grams: servingSize)],
                calories: calories,
                protein: protein,
                totalCarbohydrate: carbs,
                totalFat: fat,
                thumbnail: nil,
                hasMissingMacros: hasMissingMacros,
                source: .usda
            )
        }

        return results
    }

    func getFoodDetail(fdcId: Int) async throws -> FoodResult {
        let key = KeychainManager.load(key: Keys.usdaApiKey) ?? ""
        guard !key.isEmpty else { throw USDAServiceError.unauthorized }

        var comps = URLComponents(string: "\(baseURL)/food/\(fdcId)")
        guard comps != nil else { throw USDAServiceError.invalidURL }
        comps!.queryItems = [URLQueryItem(name: "api_key", value: key)]
        guard let url = comps?.url else { throw USDAServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw USDAServiceError.networkError("Invalid response")
        }
        switch http.statusCode {
        case 200...299:
            break
        case 401:
            throw USDAServiceError.unauthorized
        case 429:
            throw USDAServiceError.rateLimited
        case 404:
            throw USDAServiceError.networkError("Not found")
        default:
            throw USDAServiceError.networkError("HTTP \(http.statusCode)")
        }

        let wrapper: USDAFoodDetailResponse
        do {
            wrapper = try decoder.decode(USDAFoodDetailResponse.self, from: data)
        } catch {
            throw USDAServiceError.decodingFailed
        }

        let calories = foodMacro(wrapper.foodNutrients, nutrientId: 1008) ?? 0
        let protein = foodMacro(wrapper.foodNutrients, nutrientId: 1003) ?? 0
        let carbs = foodMacro(wrapper.foodNutrients, nutrientId: 1005) ?? 0
        let fat = foodMacro(wrapper.foodNutrients, nutrientId: 1004) ?? 0

        let hasMissingMacros = [
            foodMacro(wrapper.foodNutrients, nutrientId: 1008),
            foodMacro(wrapper.foodNutrients, nutrientId: 1003),
            foodMacro(wrapper.foodNutrients, nutrientId: 1005),
            foodMacro(wrapper.foodNutrients, nutrientId: 1004),
        ].contains(nil)

        let servingSize = wrapper.servingSize ?? wrapper.firstMeasureGrams ?? 100.0
        let servingUnit = wrapper.servingSizeUnit ?? "g"

        let servingOptions: [FoodResult.ServingOption] = (wrapper.foodMeasures ?? []).compactMap { measure in
            guard let grams = measure.gramWeight, grams > 0 else { return nil }
            let label = measure.disseminationText ?? "\(Int(grams)) g"
            return FoodResult.ServingOption(label: label, grams: grams)
        }

        let foodName = wrapper.description ?? "Unknown food"
        if foodName.isEmpty { throw USDAServiceError.missingFoodDescription }

        let finalServingOptions: [FoodResult.ServingOption]
        if servingOptions.isEmpty {
            finalServingOptions = [FoodResult.ServingOption(label: "\(servingSize, specifier: "%.0f") \(servingUnit)", grams: servingSize)]
        } else {
            finalServingOptions = servingOptions
        }

        return FoodResult(
            nixItemId: nil,
            foodName: foodName,
            brandName: wrapper.brandOwner,
            servingQty: 1.0,
            servingUnit: servingUnit,
            servingWeightGrams: servingSize,
            servingOptions: finalServingOptions,
            calories: calories,
            protein: protein,
            totalCarbohydrate: carbs,
            totalFat: fat,
            thumbnail: nil,
            hasMissingMacros: hasMissingMacros,
            source: .usda
        )
    }
}

// MARK: - Helpers

private extension USDAService {
    func foodMacro(_ nutrients: [USDAFoodNutrient]?, nutrientId: Int) -> Double? {
        guard let nutrients else { return nil }
        return nutrients.first(where: { $0.nutrientId == nutrientId })?.value
    }
}

// MARK: - USDA DTOs (subset we need)

private struct USDAFoodsSearchResponse: Decodable {
    let foods: [USDAFoodSearchItem]?
}

private struct USDAFoodSearchItem: Decodable {
    let fdcId: Int?
    let description: String?
    let brandOwner: String?

    let servingSize: Double?
    let servingSizeUnit: String?

    let foodNutrients: [USDAFoodNutrient]?
}

private struct USDAFoodDetailResponse: Decodable {
    let description: String?
    let brandOwner: String?

    let servingSize: Double?
    let servingSizeUnit: String?

    let foodNutrients: [USDAFoodNutrient]?
    let foodMeasures: [USDAFoodMeasure]?

    var firstMeasureGrams: Double? { foodMeasures?.first?.gramWeight }
    var firstMeasureLabel: String? { foodMeasures?.first?.disseminationText }
}

private struct USDAFoodNutrient: Decodable {
    let nutrientId: Int
    let value: Double?

    enum CodingKeys: String, CodingKey {
        case nutrientId
        case value
    }
}

private struct USDAFoodMeasure: Decodable {
    let disseminationText: String?
    let gramWeight: Double?

    enum CodingKeys: String, CodingKey {
        case disseminationText
        case gramWeight
    }
}

