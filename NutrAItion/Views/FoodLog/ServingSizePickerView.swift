//
//  ServingSizePickerView.swift
//  NutrAItion
//

import SwiftUI
import SwiftData

struct ServingSizePickerView: View {
    let food: FoodResult
    var onLog: () -> Void
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var servingMultiplier: Double = 1.0
    @State private var selectedMealType: MealType = .lunch

    private var scaledCalories: Double { food.calories * servingMultiplier }
    private var scaledProtein: Double { food.protein * servingMultiplier }
    private var scaledCarbs: Double { food.totalCarbohydrate * servingMultiplier }
    private var scaledFat: Double { food.totalFat * servingMultiplier }

    var body: some View {
        NavigationStack {
            Form {
                Section("Macros per serving") {
                    LabeledContent("Calories", value: "\(Int(food.calories.rounded()))")
                    LabeledContent("Protein", value: "\(Int(food.protein.rounded())) g")
                    LabeledContent("Carbs", value: "\(Int(food.totalCarbohydrate.rounded())) g")
                    LabeledContent("Fat", value: "\(Int(food.totalFat.rounded())) g")
                }
                Section {
                    Stepper(value: $servingMultiplier, in: 0.5...20, step: 0.5) {
                        Text("Servings: \(servingMultiplier, specifier: "%.1f")")
                    }
                    Text("Unit: \(food.servingUnit)")
                        .foregroundStyle(.secondary)
                }
                Section("Meal") {
                    Picker("Meal type", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total: \(Int(scaledCalories.rounded())) cal · P \(Int(scaledProtein.rounded()))g · C \(Int(scaledCarbs.rounded()))g · F \(Int(scaledFat.rounded()))g")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Log This Food") {
                            logFood()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(food.foodName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }

    private func logFood() {
        let entry = food.toFoodEntry(
            servingMultiplier: servingMultiplier,
            mealType: selectedMealType,
            confidence: .precise
        )
        modelContext.insert(entry)
        try? modelContext.save()
        onLog()
    }
}

#Preview {
    ServingSizePickerView(
        food: FoodResult(
            foodName: "Greek Yogurt",
            servingQty: 1,
            servingUnit: "cup",
            calories: 130,
            protein: 17,
            totalCarbohydrate: 6,
            totalFat: 5
        ),
        onLog: {},
        onDismiss: {}
    )
    .modelContainer(for: FoodEntry.self, inMemory: true)
}
