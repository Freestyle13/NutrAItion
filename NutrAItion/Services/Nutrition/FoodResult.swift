//
//  FoodResult.swift
//  NutrAItion
//

import Foundation
import SwiftData

/// Food item returned from Nutritionix API. Codable for JSON decoding.
struct FoodResult: Codable {
    var nixItemId: String?
    var foodName: String
    var brandName: String?
    var servingQty: Double
    var servingUnit: String
    var servingWeightGrams: Double?
    var calories: Double
    var protein: Double
    var totalCarbohydrate: Double
    var totalFat: Double
    var thumbnail: URL?

    enum CodingKeys: String, CodingKey {
        case nixItemId = "nix_item_id"
        case foodName = "food_name"
        case brandName = "brand_name"
        case servingQty = "serving_qty"
        case servingUnit = "serving_unit"
        case servingWeightGrams = "serving_weight_grams"
        case calories = "nf_calories"
        case protein = "nf_protein"
        case totalCarbohydrate = "nf_total_carbohydrate"
        case totalFat = "nf_total_fat"
        case photo
    }

    init(
        nixItemId: String? = nil,
        foodName: String,
        brandName: String? = nil,
        servingQty: Double,
        servingUnit: String,
        servingWeightGrams: Double? = nil,
        calories: Double,
        protein: Double,
        totalCarbohydrate: Double,
        totalFat: Double,
        thumbnail: URL? = nil
    ) {
        self.nixItemId = nixItemId
        self.foodName = foodName
        self.brandName = brandName
        self.servingQty = servingQty
        self.servingUnit = servingUnit
        self.servingWeightGrams = servingWeightGrams
        self.calories = calories
        self.protein = protein
        self.totalCarbohydrate = totalCarbohydrate
        self.totalFat = totalFat
        self.thumbnail = thumbnail
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nixItemId = try c.decodeIfPresent(String.self, forKey: .nixItemId)
        foodName = try c.decode(String.self, forKey: .foodName)
        brandName = try c.decodeIfPresent(String.self, forKey: .brandName)
        servingQty = try c.decodeIfPresent(Double.self, forKey: .servingQty) ?? 1
        servingUnit = try c.decodeIfPresent(String.self, forKey: .servingUnit) ?? "serving"
        servingWeightGrams = try c.decodeIfPresent(Double.self, forKey: .servingWeightGrams)
        calories = try c.decodeIfPresent(Double.self, forKey: .calories) ?? 0
        protein = try c.decodeIfPresent(Double.self, forKey: .protein) ?? 0
        totalCarbohydrate = try c.decodeIfPresent(Double.self, forKey: .totalCarbohydrate) ?? 0
        totalFat = try c.decodeIfPresent(Double.self, forKey: .totalFat) ?? 0
        if c.contains(.photo) {
            let photo = try c.nestedContainer(keyedBy: PhotoKeys.self, forKey: .photo)
            thumbnail = try photo.decodeIfPresent(URL.self, forKey: .thumb)
        } else {
            thumbnail = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(nixItemId, forKey: .nixItemId)
        try c.encode(foodName, forKey: .foodName)
        try c.encodeIfPresent(brandName, forKey: .brandName)
        try c.encode(servingQty, forKey: .servingQty)
        try c.encode(servingUnit, forKey: .servingUnit)
        try c.encodeIfPresent(servingWeightGrams, forKey: .servingWeightGrams)
        try c.encode(calories, forKey: .calories)
        try c.encode(protein, forKey: .protein)
        try c.encode(totalCarbohydrate, forKey: .totalCarbohydrate)
        try c.encode(totalFat, forKey: .totalFat)
        if let thumbnail {
            var photo = c.nestedContainer(keyedBy: PhotoKeys.self, forKey: .photo)
            try photo.encode(thumbnail, forKey: .thumb)
        }
    }

    private enum PhotoKeys: String, CodingKey { case thumb }

    /// Local property alias for totalCarbohydrate.
    var carbs: Double { totalCarbohydrate }
    /// Local property alias for totalFat.
    var fat: Double { totalFat }

    /// Creates a FoodEntry from this result with optional serving multiplier, meal type, and confidence.
    func toFoodEntry(
        servingMultiplier: Double = 1.0,
        mealType: MealType,
        confidence: Confidence
    ) -> FoodEntry {
        FoodEntry(
            name: foodName,
            calories: calories * servingMultiplier,
            protein: protein * servingMultiplier,
            carbs: totalCarbohydrate * servingMultiplier,
            fat: totalFat * servingMultiplier,
            confidence: confidence,
            mealType: mealType
        )
    }
}
