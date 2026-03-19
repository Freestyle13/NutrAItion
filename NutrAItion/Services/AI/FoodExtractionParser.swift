//
//  FoodExtractionParser.swift
//  NutrAItion
//

import Foundation

enum FoodExtractionParserError: Error, LocalizedError {
    case emptyInput
    case invalidUTF8
    case malformedJSON(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "Empty JSON input"
        case .invalidUTF8: return "Could not encode string as UTF-8"
        case .malformedJSON(let detail): return "Malformed food extraction JSON: \(detail)"
        }
    }
}

struct FoodExtractionParser: Sendable {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private struct Root: Decodable {
        let items: [ExtractedFoodItem]
    }

    private static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            return nil
        }
        guard start <= end else { return nil }
        return String(text[start...end])
    }

    /// Strips ```json ... ``` fences and surrounding whitespace.
    static func stripMarkdownFences(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("```") else { return s }
        // Remove leading opening fence.
        s.removeFirst(3)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove optional language identifier (e.g. `json`) after the fence.
        // We only drop a contiguous alphabetic token to avoid eating real JSON.
        let langToken = s.prefix(while: { $0.isLetter })
        if !langToken.isEmpty {
            s = String(s.dropFirst(langToken.count))
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let endRange = s.range(of: "```") {
            s = String(s[..<endRange.lowerBound])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parse(jsonString: String) throws -> [ExtractedFoodItem] {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FoodExtractionParserError.emptyInput }

        let cleaned = Self.stripMarkdownFences(from: trimmed)
        // Be extra defensive: extract the first JSON object so that any leftover
        // tokens (language ids, extra newlines, etc.) can't break decoding.
        let candidate = Self.extractJSONObject(from: cleaned) ?? cleaned
        guard let data = candidate.data(using: .utf8) else {
            throw FoodExtractionParserError.invalidUTF8
        }

        do {
            let root = try decoder.decode(Root.self, from: data)
            return root.items
        } catch {
            throw FoodExtractionParserError.malformedJSON(error.localizedDescription)
        }
    }

    func toFoodEntries(_ items: [ExtractedFoodItem], mealType: MealType) -> [FoodEntry] {
        items.map { item in
            let notes: String?
            if item.portionDescription.isEmpty {
                notes = nil
            } else {
                notes = "Portion: \(item.portionDescription)"
            }
            return FoodEntry(
                name: item.name,
                calories: item.estimatedCalories,
                protein: item.estimatedProtein,
                carbs: item.estimatedCarbs,
                fat: item.estimatedFat,
                confidence: .estimated,
                mealType: mealType,
                notes: notes
            )
        }
    }
}
