//
//  FoodLogView.swift
//  NutrAItion
//

import SwiftUI
import SwiftData

struct FoodLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allEntries: [FoodEntry]

    @State private var selectedDate = Date()
    @State private var showBarcodeScanner = false
    @State private var showFoodSearch = false
    @State private var showAddActions = false

    private let calendar = Calendar.current

    private var entriesForSelectedDay: [FoodEntry] {
        allEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
    }

    private var isViewingToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var groupedByMeal: [(MealType, [FoodEntry])] {
        let grouped = Dictionary(grouping: entriesForSelectedDay, by: { $0.mealType })
        return MealType.allCases.compactMap { type in
            guard let list = grouped[type], !list.isEmpty else { return nil }
            return (type, list.sorted { $0.timestamp < $1.timestamp })
        }
    }

    private var loggedTotals: (cal: Double, p: Double, c: Double, f: Double) {
        entriesForSelectedDay.reduce((0, 0, 0, 0)) { acc, e in
            (acc.0 + e.calories, acc.1 + e.protein, acc.2 + e.carbs, acc.3 + e.fat)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let targets = appState.todaysMacroTargets {
                    MacroSummaryBar(
                        loggedCalories: loggedTotals.0,
                        loggedProtein: loggedTotals.1,
                        loggedCarbs: loggedTotals.2,
                        loggedFat: loggedTotals.3,
                        targetCalories: targets.calories,
                        targetProtein: targets.protein,
                        targetCarbs: targets.carbs,
                        targetFat: targets.fat
                    )
                    .padding(.horizontal)
                }
                List {
                    ForEach(groupedByMeal, id: \.0) { mealType, entries in
                        Section(mealType.displayName) {
                            ForEach(entries, id: \.id) { entry in
                                FoodLogEntryRow(entry: entry)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteEntry(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        if !isViewingToday {
                                            Button {
                                                copyToToday(entry)
                                            } label: {
                                                Label("Copy to today", systemImage: "doc.on.doc")
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle(formattedDate(selectedDate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddActions = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .confirmationDialog("Add food", isPresented: $showAddActions) {
                Button("Scan Barcode") {
                    showBarcodeScanner = true
                }
                Button("Search Food") {
                    showFoodSearch = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("How do you want to add food?")
            }
            .fullScreenCover(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(
                    onBarcodeDetected: { _ in
                        showBarcodeScanner = false
                        showFoodSearch = false
                        // Phase 3: barcode flow could open lookup then ServingSizePicker
                    },
                    onCancel: { showBarcodeScanner = false }
                )
            }
            .sheet(isPresented: $showFoodSearch) {
                FoodSearchView()
            }
        }
    }

    private func deleteEntry(_ entry: FoodEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    private func copyToToday(_ entry: FoodEntry) {
        let copy = FoodEntry(
            name: entry.name,
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            confidence: entry.confidence,
            mealType: entry.mealType,
            timestamp: Date()
        )
        modelContext.insert(copy)
        try? modelContext.save()
    }
}

// MARK: - Row for one log entry

private struct FoodLogEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.name)
                    .font(.headline)
                if entry.confidence == .estimated {
                    Text("Est.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            Text("\(Int(entry.calories.rounded())) cal · P \(Int(entry.protein.rounded()))g · C \(Int(entry.carbs.rounded()))g · F \(Int(entry.fat.rounded()))g")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    FoodLogView()
        .environment(AppState())
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
