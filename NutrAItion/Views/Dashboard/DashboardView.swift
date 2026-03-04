//
//  DashboardView.swift
//  NutrAItion
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allEntries: [FoodEntry]

    @State private var todayWeight: Double?
    @State private var showQuickAdd = false
    @State private var showBarcodeScanner = false
    @State private var showFoodSearch = false

    private let calendar = Calendar.current

    private var todaysEntries: [FoodEntry] {
        allEntries.filter { calendar.isDateInToday($0.timestamp) }
    }

    private var loggedTotals: (cal: Double, p: Double, c: Double, f: Double) {
        todaysEntries.reduce((0, 0, 0, 0)) { acc, e in
            (acc.0 + e.calories, acc.1 + e.protein, acc.2 + e.carbs, acc.3 + e.fat)
        }
    }

    private var recentEntries: [FoodEntry] {
        Array(todaysEntries.prefix(3))
    }

    private var greeting: String {
        let hour = calendar.component(.hour, from: Date())
        let timeOfDay: String
        if hour < 12 { timeOfDay = "Good morning" }
        else if hour < 17 { timeOfDay = "Good afternoon" }
        else { timeOfDay = "Good evening" }
        return "\(timeOfDay), there"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    if let targets = appState.todaysMacroTargets {
                        calorieRingSection(targets: targets)
                        macroRingsSection(targets: targets)
                    }
                    effortAndWeightSection
                    quickAddSection
                    recentSection
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadTodayWeight() }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(
                    onScanBarcode: { showQuickAdd = false; showBarcodeScanner = true },
                    onSearchFood: { showQuickAdd = false; showFoodSearch = true },
                    onTellAI: { showQuickAdd = false },
                    onDismiss: { showQuickAdd = false }
                )
            }
            .fullScreenCover(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(
                    onBarcodeDetected: { _ in showBarcodeScanner = false },
                    onCancel: { showBarcodeScanner = false }
                )
            }
            .sheet(isPresented: $showFoodSearch) {
                FoodSearchView()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.title2)
                .fontWeight(.semibold)
            Text(selectedDateFormatted)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var selectedDateFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    private func calorieRingSection(targets: MacroTargets) -> some View {
        let remaining = max(0, targets.calories - loggedTotals.0)
        return MacroRingView(
            current: remaining,
            target: targets.calories,
            color: .orange,
            label: "Remaining",
            unit: "",
            isLarge: true
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func macroRingsSection(targets: MacroTargets) -> some View {
        HStack(spacing: 16) {
            MacroRingView(
                current: loggedTotals.1,
                target: targets.protein,
                color: .blue,
                label: "Protein",
                unit: "g",
                isLarge: false
            )
            .frame(maxWidth: .infinity)
            MacroRingView(
                current: loggedTotals.2,
                target: targets.carbs,
                color: .green,
                label: "Carbs",
                unit: "g"
            )
            .frame(maxWidth: .infinity)
            MacroRingView(
                current: loggedTotals.3,
                target: targets.fat,
                color: .purple,
                label: "Fat",
                unit: "g"
            )
            .frame(maxWidth: .infinity)
        }
    }

    private var effortAndWeightSection: some View {
        HStack(spacing: 16) {
            EffortBadgeView(level: appState.todaysEffortLevel)
            if let kg = todayWeight {
                Text("\(String(format: "%.1f", kg)) kg")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var quickAddSection: some View {
        Button {
            showQuickAdd = true
        } label: {
            Label("Quick add food", systemImage: "plus.circle.fill")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    FoodLogView()
                }
                .font(.subheadline)
            }
            if recentEntries.isEmpty {
                Text("No entries today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentEntries, id: \.id) { entry in
                    HStack {
                        Text(entry.name)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(entry.calories.rounded())) cal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func loadTodayWeight() async {
        todayWeight = await appState.healthKitManager.fetchTodayWeight()
    }
}

// MARK: - Quick add sheet

private struct QuickAddSheet: View {
    var onScanBarcode: () -> Void
    var onSearchFood: () -> Void
    var onTellAI: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onScanBarcode()
                } label: {
                    Label("Scan Barcode", systemImage: "barcode.viewfinder")
                }
                Button {
                    onSearchFood()
                } label: {
                    Label("Search Food", systemImage: "magnifyingglass")
                }
                Button {
                    onTellAI()
                } label: {
                    Label("Tell AI", systemImage: "message")
                }
            }
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
