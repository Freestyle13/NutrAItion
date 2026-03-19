//
//  ClaudeAPIService.swift
//  NutrAItion
//

import Foundation

enum ClaudeAPIServiceError: Error {
    case unauthorized
    case rateLimited
    case networkError(String)
    case malformedResponse
}

/// Macro-only estimate JSON (used by FoodDatabaseService / Open Food Facts gap-fill).
struct EstimatedNutrition: Decodable, Equatable {
    var estimatedCalories: Double
    var estimatedProtein: Double
    var estimatedCarbs: Double
    var estimatedFat: Double
}

@Observable
final class ClaudeAPIService {
    var isLoading = false
    var errorMessage: String?

    private let session = URLSession.shared
    private let parser = FoodExtractionParser()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Phase 4.1 — Food extraction

    func extractFood(from message: String, context: DayContext) async -> [ExtractedFoodItem] {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        _ = context // Reserved for future prompts (e.g. remaining macros).

        let systemPrompt = """
        You are a nutrition assistant. Extract all food items from the user's message.
        Return ONLY a valid JSON object with this exact structure, no other text:
        {
          "items": [
            {
              "name": "food name",
              "estimated_calories": 0,
              "estimated_protein": 0,
              "estimated_carbs": 0,
              "estimated_fat": 0,
              "confidence": "low|medium|high",
              "portion_description": "portion size description"
            }
          ]
        }
        If no food items are mentioned, return {"items": []}.
        Use average restaurant/home cooking portions if size is not specified.
        """

        do {
            let text = try await postMessages(
                system: systemPrompt,
                messages: [["role": "user", "content": message]],
                maxTokens: 1000
            )
            return try parser.parse(jsonString: text)
        } catch {
            errorMessage = "Couldn’t extract food from your message. Try rephrasing."
            return []
        }
    }

    // MARK: - Phase 4.1 — Coach chat

    func chat(message: String, history: [ChatMessage], context: DayContext) async -> String {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let systemPrompt = """
        You are a personalized nutrition coach. Here is the user's current data:
        - Daily calorie target: \(Int(context.calorieTarget)) cal
        - Remaining today: \(Int(context.remainingCalories)) cal
        - Protein target: \(Int(context.proteinTarget))g (logged: \(Int(context.proteinLogged))g)
        - Goal: \(context.goalType.displayName)
        - Today's effort level: \(context.effortDescription)
        Answer nutrition questions based on this context. Be concise and practical.
        """

        var payload: [[String: String]] = []
        for m in history {
            let role = m.role == .user ? "user" : "assistant"
            payload.append(["role": role, "content": m.content])
        }
        payload.append(["role": "user", "content": message])

        do {
            let text = try await postMessages(
                system: systemPrompt,
                messages: payload,
                maxTokens: 2000
            )
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "I couldn’t generate a reply. Try again." : trimmed
        } catch {
            errorMessage = "Couldn’t reach the coach. Check your connection and API key."
            return ""
        }
    }

    // MARK: - FoodDatabaseService — single-item macro estimate

    func estimateFoodNutrition(_ foodName: String) async throws -> EstimatedNutrition {
        let apiKey = KeychainManager.load(key: Keys.anthropicApiKey)
        guard let apiKey, !apiKey.isEmpty else {
            throw ClaudeAPIServiceError.unauthorized
        }

        let systemPrompt = """
        You are a nutrition assistant. Estimate typical nutrition macros for ONE food by name.
        Return ONLY a valid JSON object with this exact structure:
        {
          "estimated_calories": 0,
          "estimated_protein": 0,
          "estimated_carbs": 0,
          "estimated_fat": 0
        }
        No markdown, no backticks, no commentary.
        Numbers should be plain JSON numbers.
        """

        let text = try await postMessages(
            system: systemPrompt,
            messages: [["role": "user", "content": "Food: \(foodName)"]],
            maxTokens: 1000,
            apiKey: apiKey
        )

        guard let jsonData = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            throw ClaudeAPIServiceError.malformedResponse
        }
        return try decoder.decode(EstimatedNutrition.self, from: jsonData)
    }

    // MARK: - HTTP

    private func postMessages(
        system: String,
        messages: [[String: String]],
        maxTokens: Int,
        apiKey: String? = nil
    ) async throws -> String {
        let key = apiKey ?? KeychainManager.load(key: Keys.anthropicApiKey) ?? ""
        guard !key.isEmpty else { throw ClaudeAPIServiceError.unauthorized }

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": maxTokens,
            "system": system,
            "messages": messages,
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw ClaudeAPIServiceError.networkError("Invalid Claude URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeAPIServiceError.networkError("Invalid response")
        }
        switch http.statusCode {
        case 200...299:
            break
        case 401:
            throw ClaudeAPIServiceError.unauthorized
        case 429:
            throw ClaudeAPIServiceError.rateLimited
        default:
            throw ClaudeAPIServiceError.networkError("HTTP \(http.statusCode)")
        }

        let anthropic = try decoder.decode(AnthropicMessagesResponse.self, from: data)
        let text = anthropic.contentText
        guard !text.isEmpty else {
            throw ClaudeAPIServiceError.malformedResponse
        }
        return text
    }
}

// MARK: - Anthropic DTOs

private struct AnthropicMessagesResponse: Decodable {
    let content: [AnthropicContentBlock]

    var contentText: String {
        content.compactMap(\.text).joined(separator: "\n")
    }
}

private struct AnthropicContentBlock: Decodable {
    let type: String?
    let text: String?
}
