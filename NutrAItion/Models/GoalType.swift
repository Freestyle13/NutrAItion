//
//  GoalType.swift
//  NutrAItion
//

import Foundation

enum GoalType: String, CaseIterable, Codable {
    case cut
    case bulk
    case maintain

    var displayName: String {
        switch self {
        case .cut: return "Cut"
        case .bulk: return "Bulk"
        case .maintain: return "Maintain"
        }
    }
}
