//
//  MealType.swift
//  NutrAItion
//

import Foundation

enum MealType: String, CaseIterable, Codable {
    case breakfast
    case lunch
    case dinner
    case snack

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }
}
