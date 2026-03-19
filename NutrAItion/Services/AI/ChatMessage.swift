//
//  ChatMessage.swift
//  NutrAItion
//

import Foundation

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
}

struct ExtractedFoodItem: Codable, Equatable, Sendable, Identifiable {
    var id: String { name + portionDescription + "\(estimatedCalories)" }

    var name: String
    var estimatedCalories: Double
    var estimatedProtein: Double
    var estimatedCarbs: Double
    var estimatedFat: Double
    /// Raw string from Claude, e.g. "low|medium|high" — logging uses `.estimated` regardless.
    var confidence: String
    var portionDescription: String

    enum CodingKeys: String, CodingKey {
        case name
        case estimatedCalories = "estimated_calories"
        case estimatedProtein = "estimated_protein"
        case estimatedCarbs = "estimated_carbs"
        case estimatedFat = "estimated_fat"
        case confidence
        case portionDescription = "portion_description"
    }
}

struct ChatMessage: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var extractedFoodItems: [ExtractedFoodItem]?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        extractedFoodItems: [ExtractedFoodItem]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.extractedFoodItems = extractedFoodItems
    }
}
