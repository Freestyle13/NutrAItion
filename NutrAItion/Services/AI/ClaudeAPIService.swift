import Foundation

enum ClaudeAPIServiceError: Error {
    case unauthorized
    case rateLimited
    case networkError(String)
    case malformedResponse
}

struct EstimatedNutrition: Decodable, Equatable {
    var estimatedCalories: Double
    var estimatedProtein: Double
    var estimatedCarbs: Double
    var estimatedFat: Double
}

@Observable
final class ClaudeAPIService {
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

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

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 1000,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": "Food: \(foodName)"
                ]
            ]
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw ClaudeAPIServiceError.networkError("Invalid Claude URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])

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
        let contentText = anthropic.contentText

        // Claude may return JSON as text; parse it as JSON from the content string.
        guard let jsonData = contentText.data(using: .utf8) else {
            throw ClaudeAPIServiceError.malformedResponse
        }
        let estimate = try decoder.decode(EstimatedNutrition.self, from: jsonData)
        return estimate
    }
}

// MARK: - Anthropic DTOs

private struct AnthropicMessagesResponse: Decodable {
    let content: [AnthropicContentBlock]

    var contentText: String {
        // We assume the assistant returns a single text block containing the JSON.
        content.first?.text ?? ""
    }
}

private struct AnthropicContentBlock: Decodable {
    let text: String?
}

