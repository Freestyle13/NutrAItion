//
//  ManualFoodEntryView.swift
//  NutrAItion
//

import SwiftUI
import SwiftData

struct ManualFoodEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var onDismiss: () -> Void

    @State private var foodName: String = ""
    @State private var mealType: MealType = .lunch

    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""

    @State private var errorMessage: String?

    private func upsertCustomFood(
        name: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) {
        var descriptor = FetchDescriptor<CustomFood>(
            predicate: #Predicate { food in
                food.name == name
            }
        )
        descriptor.fetchLimit = 1

        if let existing = (try? modelContext.fetch(descriptor).first) {
            existing.calories = calories
            existing.protein = protein
            existing.carbs = carbs
            existing.fat = fat
        } else {
            let custom = CustomFood(
                name: name,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat
            )
            modelContext.insert(custom)
        }
    }

    private func parseMacro(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private func logFood() {
        errorMessage = nil

        let trimmedName = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a food name."
            return
        }

        guard
            let calories = parseMacro(caloriesText),
            let protein = parseMacro(proteinText),
            let carbs = parseMacro(carbsText),
            let fat = parseMacro(fatText)
        else {
            errorMessage = "Please enter calories and all macros (P/C/F)."
            return
        }

        let entry = FoodEntry(
            name: trimmedName,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            // Manual form values are self-reported, so we treat them as manual-confidence.
            confidence: .manual,
            mealType: mealType,
            timestamp: Date()
        )

        modelContext.insert(entry)

        if let profile = appState.userProfile {
            let synchronizer = DayLogSynchronizer(
                healthKitManager: appState.healthKitManager,
                calendar: Calendar.current
            )
            synchronizer.attachFoodEntryToDayLog(entry, modelContext: modelContext, userProfile: profile)
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Couldn't save entry. Please try again."
            return
        }

        // Save/update the reusable custom food so it appears in search.
        upsertCustomFood(
            name: trimmedName,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
        try? modelContext.save()

        appState.triggerJustLoggedAnimation()
        onDismiss()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Food name", text: $foodName)
                        .textInputAutocapitalization(.words)
                }

                Section("Meal") {
                    Picker("Meal type", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Macros (grams)") {
                    TextField("Calories (cal)", text: $caloriesText)
                        .keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $proteinText)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbsText)
                        .keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fatText)
                        .keyboardType(.decimalPad)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        logFood()
                    } label: {
                        Text("Log Food")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                    .background(Color.accentPurple, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.textPrimary)
                    .buttonStyle(AccentPressableButtonStyle())
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                }
            }
            .background(Color.appBackground)
            .scrollContentBackground(.hidden)
        }
    }
}

#Preview {
    ManualFoodEntryView(onDismiss: {})
        .environment(AppState())
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
