//
//  FoodSearchView.swift
//  NutrAItion
//

import SwiftUI

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var results: [FoodResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFood: FoodResult?
    @State private var showManualEntry = false

    private let nutritionix = NutritionixService()
    private let debounceSeconds: Double = 0.3

    var body: some View {
        NavigationStack {
            Group {
                if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if isLoading {
                        ProgressView("Searching…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let msg = errorMessage {
                        VStack(spacing: 16) {
                            Text(msg)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            manualEntryButton
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else if results.isEmpty {
                        VStack(spacing: 16) {
                            Text("No results for \"\(searchQuery)\"")
                                .foregroundStyle(.secondary)
                            manualEntryButton
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        List(results, id: \.foodName) { item in
                            Button {
                                selectedFood = item
                            } label: {
                                FoodResultRow(item: item)
                            }
                        }
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
            }
            .sheet(isPresented: $showManualEntry) {
                ManualFoodEntryView(onDismiss: { showManualEntry = false })
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
            results = try await nutritionix.searchFood(query: query)
        } catch NutritionixError.notFound {
            results = []
        } catch NutritionixError.unauthorized {
            errorMessage = "Couldn't reach food database — check connection"
            results = []
        } catch NutritionixError.rateLimited {
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

#Preview {
    FoodSearchView()
}
