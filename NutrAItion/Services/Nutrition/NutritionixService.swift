//
//  NutritionixService.swift
//  NutrAItion
//

import Foundation

enum NutritionixError: Error {
    case notFound           // 404 — caller should offer manual entry
    case unauthorized       // 401
    case rateLimited        // 429
    case networkError(String)
}

@Observable
final class NutritionixService {
    private let baseURL = "https://trackapi.nutritionix.com/v2"
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private func authHeaders() throws -> [String: String] {
        guard let appId = KeychainManager.load(key: Keys.nutritionixAppId),
              let appKey = KeychainManager.load(key: Keys.nutritionixAppKey) else {
            throw NutritionixError.unauthorized
        }
        return [
            "x-app-id": appId,
            "x-app-key": appKey,
            "Content-Type": "application/json",
        ]
    }

    private func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NutritionixError.networkError("Invalid response")
        }
        switch http.statusCode {
        case 404: throw NutritionixError.notFound
        case 401: throw NutritionixError.unauthorized
        case 429: throw NutritionixError.rateLimited
        case 200...299: break
        default: throw NutritionixError.networkError("HTTP \(http.statusCode)")
        }
        return (data, http)
    }

    /// GET /v2/search/instant
    func searchFood(query: String) async throws -> [FoodResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/instant?query=\(encoded)&self=false&branded=true&common=true") else {
            throw NutritionixError.networkError("Invalid query")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (k, v) in try authHeaders() { request.setValue(v, forHTTPHeaderField: k) }

        let (data, _) = try await data(for: request)
        let wrapper = try decoder.decode(InstantSearchResponse.self, from: data)
        return wrapper.common + wrapper.branded
    }

    /// GET /v2/search/item?upc=
    func lookupBarcode(upc: String) async throws -> FoodResult? {
        guard let encoded = upc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/item?upc=\(encoded)") else {
            throw NutritionixError.networkError("Invalid UPC")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (k, v) in try authHeaders() { request.setValue(v, forHTTPHeaderField: k) }

        do {
            let (data, _) = try await data(for: request)
            let wrapper = try decoder.decode(BarcodeItemResponse.self, from: data)
            return wrapper.foods.first
        } catch NutritionixError.notFound {
            return nil
        }
    }

    /// POST /v2/natural/nutrients for detailed breakdown when search result is missing macros.
    func getNutritionDetails(for item: FoodResult) async throws -> FoodResult {
        guard let url = URL(string: "\(baseURL)/natural/nutrients") else {
            throw NutritionixError.networkError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (k, v) in try authHeaders() { request.setValue(v, forHTTPHeaderField: k) }
        let body = ["query": item.foodName]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await data(for: request)
        let wrapper = try decoder.decode(NaturalNutrientsResponse.self, from: data)
        guard let first = wrapper.foods.first else {
            throw NutritionixError.networkError("No food in nutrients response")
        }
        return first
    }
}

// MARK: - Response DTOs (Nutritionix API shape)

private struct InstantSearchResponse: Codable {
    var common: [FoodResult] = []
    var branded: [FoodResult] = []
}

private struct BarcodeItemResponse: Codable {
    var foods: [FoodResult] = []
}

private struct NaturalNutrientsResponse: Codable {
    var foods: [FoodResult] = []
}
