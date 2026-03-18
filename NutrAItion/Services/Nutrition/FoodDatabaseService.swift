import Foundation

enum FoodDatabaseError: Error, Equatable {
    case notFound
    case unauthorized
    case rateLimited
    case networkError(String)
}

@Observable
final class FoodDatabaseService {
    private let openFoodFactsService = OpenFoodFactsService()
    private let usdaService = USDAService()
    private let claudeService = ClaudeAPIService()

    func searchFood(_ query: String) async throws -> [FoodResult] {
        let results: [FoodResult]
        do {
            results = try await usdaService.searchFood(query)
        } catch {
            // Map underlying service errors into a UI-friendly set.
            if let e = error as? USDAServiceError {
                switch e {
                case .unauthorized:
                    throw FoodDatabaseError.unauthorized
                case .rateLimited:
                    throw FoodDatabaseError.rateLimited
                case .networkError(let message):
                    throw FoodDatabaseError.networkError(message)
                case .invalidURL:
                    throw FoodDatabaseError.networkError("Invalid USDA URL")
                case .decodingFailed:
                    throw FoodDatabaseError.networkError("Failed to parse USDA response")
                case .missingFoodDescription:
                    throw FoodDatabaseError.networkError("Missing food description from USDA")
                }
            }
            throw FoodDatabaseError.networkError("Couldn't reach food database — check connection")
        }

        if results.isEmpty { throw FoodDatabaseError.notFound }
        return results
    }

    /// Barcode lookup. Returns `nil` if not found.
    /// If OFF has missing macros, calls Claude to estimate them.
    func lookupBarcode(_ upc: String) async -> FoodResult? {
        let result = try? await openFoodFactsService.lookupBarcode(upc)
        guard let result else { return nil }
        if result.hasMissingMacros {
            do {
                return try await fillMissingMacros(result)
            } catch {
                // If AI estimation fails, return OFF partial so the caller can fall back to manual entry.
                return result
            }
        }
        return result
    }

    private func fillMissingMacros(_ partial: FoodResult) async throws -> FoodResult {
        let estimated = try await claudeService.estimateFoodNutrition(partial.foodName)

        var filled = partial
        // Merge into fields that were missing from OFF. OFF uses `0` for missing macros.
        if partial.calories == 0 { filled.calories = estimated.estimatedCalories }
        if partial.protein == 0 { filled.protein = estimated.estimatedProtein }
        if partial.totalCarbohydrate == 0 { filled.totalCarbohydrate = estimated.estimatedCarbs }
        if partial.totalFat == 0 { filled.totalFat = estimated.estimatedFat }

        filled.hasMissingMacros = false
        filled.source = .ai
        return filled
    }
}

