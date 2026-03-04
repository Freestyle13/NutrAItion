//
//  Confidence.swift
//  NutrAItion
//

import Foundation

enum Confidence: String, CaseIterable, Codable {
    case precise   // barcode scan, Nutritionix text search
    case estimated // AI chat logging, AI-prefilled suggestion

    var displayName: String {
        switch self {
        case .precise: return "Precise"
        case .estimated: return "Estimated"
        }
    }
}
