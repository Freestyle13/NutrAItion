//
//  EffortLevel.swift
//  NutrAItion
//

import Foundation

enum EffortLevel: String, CaseIterable, Codable {
    case rest
    case low
    case moderate
    case high
    case veryHigh

    var displayName: String {
        switch self {
        case .rest: return "Rest"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
}
