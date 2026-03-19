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
    @Environment(AppState.self) private var appState
    @State private var servingMultiplier: Double = 1.0
    @State private var selectedServingOptionIndex: Int = 0
    @State private var selectedMealType: MealType = .lunch

    private var baseServingGrams: Double { food.servingWeightGrams ?? 100.0 }

    private var availableServingOptions: [FoodResult.ServingOption] {
        if food.servingOptions.isEmpty {
            let grams = baseServingGrams
            return [FoodResult.ServingOption(label: "\(Int(grams)) g", grams: grams)]
        }
        return food.servingOptions
    }

    private var selectedServingOption: FoodResult.ServingOption {
        let idx = min(max(selectedServingOptionIndex, 0), availableServingOptions.count - 1)
        return availableServingOptions[idx]
    }

    /// Ratio between the selected serving grams and the grams used to compute `food.calories`.
    private var gramsRatio: Double {
        guard baseServingGrams > 0 else { return 1.0 }
        return selectedServingOption.grams / baseServingGrams
    }

    private var caloriesPerSelectedServing: Double { food.calories * gramsRatio }
    private var proteinPerSelectedServing: Double { food.protein * gramsRatio }
    private var carbsPerSelectedServing: Double { food.totalCarbohydrate * gramsRatio }
    private var fatPerSelectedServing: Double { food.totalFat * gramsRatio }

    private var scaledCalories: Double { caloriesPerSelectedServing * servingMultiplier }
    private var scaledProtein: Double { proteinPerSelectedServing * servingMultiplier }
    private var scaledCarbs: Double { carbsPerSelectedServing * servingMultiplier }
    private var scaledFat: Double { fatPerSelectedServing * servingMultiplier }

    var body: some View {
        NavigationStack {
            Form {
                Section("Macros per serving") {
                    LabeledContent("Calories", value: "\(Int(caloriesPerSelectedServing.rounded()))")
                    LabeledContent("Protein", value: "\(Int(proteinPerSelectedServing.rounded())) g")
                    LabeledContent("Carbs", value: "\(Int(carbsPerSelectedServing.rounded())) g")
                    LabeledContent("Fat", value: "\(Int(fatPerSelectedServing.rounded())) g")
                }
                Section {
                    if availableServingOptions.count > 1 {
                        Picker("Serving size", selection: $selectedServingOptionIndex) {
                            ForEach(availableServingOptions.indices, id: \.self) { idx in
                                Text(availableServingOptions[idx].label).tag(idx)
                            }
                        }
                    }
                    Stepper(value: $servingMultiplier, in: 0.5...20, step: 0.5) {
                        Text("Servings: \(servingMultiplier, specifier: "%.1f")")
                    }
                    Text("Serving: \(selectedServingOption.label)")
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
            .onAppear {
                selectedServingOptionIndex = 0
            }
        }
    }

    private func logFood() {
        // Adjust multiplier so the entry scales to the selected serving size.
        let adjustedMultiplier = servingMultiplier * gramsRatio
        let confidence: Confidence = (food.source == .ai) ? .estimated : .precise
        let entry = food.toFoodEntry(
            servingMultiplier: adjustedMultiplier,
            mealType: selectedMealType,
            confidence: confidence
        )

        guard let profile = appState.userProfile else {
            modelContext.insert(entry)
            try? modelContext.save()
            onLog()
            return
        }

        modelContext.insert(entry)
        let synchronizer = DayLogSynchronizer(
            healthKitManager: appState.healthKitManager,
            calendar: Calendar.current
        )
        synchronizer.attachFoodEntryToDayLog(entry, modelContext: modelContext, userProfile: profile)
        try? modelContext.save()
        // Trigger a brief animation pulse on the macro summary bar.
        appState.triggerJustLoggedAnimation()
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
