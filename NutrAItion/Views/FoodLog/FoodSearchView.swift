//
//  FoodSearchView.swift
//  NutrAItion
//

import SwiftUI
import SwiftData

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomFood.lastUsedAt, order: .reverse) private var customFoods: [CustomFood]
    @State private var searchQuery = ""
    @State private var results: [FoodResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFood: FoodResult?
    @State private var selectedCustomFood: CustomFood?
    @State private var showManualEntry = false

    private let debounceSeconds: Double = 0.3

    var body: some View {
        NavigationStack {
            Group {
                if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let customMatches = filteredCustomFoods
                    if let msg = errorMessage, customMatches.isEmpty {
                        VStack(spacing: 16) {
                            Text(msg)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            manualEntryButton
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else if results.isEmpty && customMatches.isEmpty && !isLoading {
                        VStack(spacing: 16) {
                            Text("No results for \"\(searchQuery)\"")
                                .foregroundStyle(.secondary)
                            manualEntryButton
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        List {
                            if !customMatches.isEmpty {
                                Section("My Foods") {
                                    ForEach(customMatches) { food in
                                        Button {
                                            selectedCustomFood = food
                                        } label: {
                                            CustomFoodRow(food: food)
                                        }
                                    }
                                }
                            }

                            Section("Database") {
                                if isLoading {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                        Text("Searching…")
                                            .foregroundStyle(.secondary)
                                    }
                                } else if results.isEmpty {
                                    Text("No database matches")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(results, id: \.foodName) { item in
                                        Button {
                                            selectedFood = item
                                        } label: {
                                            FoodResultRow(item: item)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Start typing to search foods")
                            .foregroundStyle(.secondary)
                        manualEntryButton
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Search Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchQuery, prompt: "Food name or brand")
            .sheet(item: $selectedFood) { food in
                ServingSizePickerView(
                    food: food,
                    onLog: { selectedFood = nil; dismiss() },
                    onDismiss: { selectedFood = nil }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedCustomFood) { food in
                CustomFoodLogSheet(
                    customFood: food,
                    onLog: { selectedCustomFood = nil; dismiss() },
                    onDismiss: { selectedCustomFood = nil }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showManualEntry) {
                ManualFoodEntryView(onDismiss: { showManualEntry = false })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .task(id: searchQuery) {
                await performSearch()
            }
        }
    }

    private var manualEntryButton: some View {
        Button("Not finding it? Add it manually") {
            showManualEntry = true
        }
        .buttonStyle(.bordered)
    }

    private var filteredCustomFoods: [CustomFood] {
        let q = searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !q.isEmpty else { return [] }
        return customFoods.filter { $0.name.lowercased().contains(q) }
    }

    private func performSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        try? await Task.sleep(nanoseconds: UInt64(debounceSeconds * 1_000_000_000))
        guard searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            results = try await appState.foodDatabaseService.searchFood(query)
        } catch FoodDatabaseError.notFound {
            results = []
        } catch FoodDatabaseError.unauthorized {
            errorMessage = "Couldn't reach food database — check connection"
            results = []
        } catch FoodDatabaseError.rateLimited {
            errorMessage = "Too many requests — try again in a moment"
            results = []
        } catch {
            errorMessage = "Couldn't reach food database — check connection"
            results = []
        }
    }
}

// Allow sheet(item:) with FoodResult (identifiable)
extension FoodResult: Identifiable {
    var id: String { nixItemId ?? foodName + (brandName ?? "") }
}

private struct CustomFoodRow: View {
    let food: CustomFood

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.iconBgPurple)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Text("MANUAL")
                    .font(Font.badgeText)
                    .foregroundStyle(Color.badgeRecipe)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#0D1A2A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: .radiusBadge)
                            .stroke(Color(hex: "#0A2545"), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: .radiusBadge))
            }

            Spacer()

            Text("\(Int(food.calories.rounded())) cal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct CustomFoodLogSheet: View {
    let customFood: CustomFood
    var onLog: () -> Void
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var servings: Double = 1.0
    @State private var mealType: MealType = .lunch

    private var totalCalories: Double { customFood.calories * servings }
    private var totalProtein: Double { customFood.protein * servings }
    private var totalCarbs: Double { customFood.carbs * servings }
    private var totalFat: Double { customFood.fat * servings }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    Picker("Meal type", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Servings") {
                    Stepper(value: $servings, in: 0.5...20, step: 0.5) {
                        Text("Servings: \(servings, specifier: "%.1f")")
                    }
                }

                Section("Totals") {
                    LabeledContent("Calories", value: "\(Int(totalCalories.rounded()))")
                    LabeledContent("Protein", value: "\(Int(totalProtein.rounded())) g")
                    LabeledContent("Carbs", value: "\(Int(totalCarbs.rounded())) g")
                    LabeledContent("Fat", value: "\(Int(totalFat.rounded())) g")
                }

                Section {
                    Button {
                        log()
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
            .navigationTitle(customFood.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
            .background(Color.appBackground)
            .scrollContentBackground(.hidden)
        }
    }

    private func log() {
        let entry = FoodEntry(
            name: customFood.name,
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
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

        customFood.useCount += 1
        customFood.lastUsedAt = Date()

        try? modelContext.save()
        appState.triggerJustLoggedAnimation()
        onLog()
    }
}

#Preview {
    FoodSearchView()
        .environment(AppState())
        .modelContainer(for: [FoodEntry.self, CustomFood.self], inMemory: true)
}
