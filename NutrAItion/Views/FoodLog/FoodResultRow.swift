//
//  FoodResultRow.swift
//  NutrAItion
//

import SwiftUI

struct FoodResultRow: View {
    let item: FoodResult

    var body: some View {
        HStack(spacing: 12) {
            if let url = item.thumbnail {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.foodName)
                    .font(.headline)
                if let brand = item.brandName, !brand.isEmpty {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(Int(item.calories.rounded())) cal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        FoodResultRow(item: FoodResult(
            foodName: "Chicken Breast",
            brandName: "Generic",
            servingQty: 1,
            servingUnit: "piece",
            calories: 165,
            protein: 31,
            totalCarbohydrate: 0,
            totalFat: 3.6
        ))
    }
}
