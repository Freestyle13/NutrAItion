//
//  BiologicalSex.swift
//  NutrAItion
//

import Foundation

enum BiologicalSex: String, CaseIterable, Codable {
    case male
    case female
    case other

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }
}
