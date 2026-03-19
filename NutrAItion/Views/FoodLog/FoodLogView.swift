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
                        targetFat: targets.fat,
                        justLogged: appState.justLoggedFoodEntry
                    )
                    .padding(.horizontal, .screenPadding)
                    .padding(.top, 12)
                }
                List {
                    ForEach(groupedByMeal, id: \.0) { mealType, entries in
                        Section {
                            ForEach(entries, id: \.id) { entry in
                                FoodLogEntryRow(
                                    entry: entry,
                                    canCopyToToday: !isViewingToday
                                ) {
                                    copyToToday(entry)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteEntry(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            mealSectionHeader(mealType: mealType, entries: entries)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.bottom, 84)
            }
            .navigationTitle(formattedDate(selectedDate))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.appBackground)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showAddActions = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentPurple)
                            .frame(width: 52, height: 52)
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 22, height: 22)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .buttonStyle(AccentPressableButtonStyle())
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
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
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
        if let profile = appState.userProfile {
            let synchronizer = DayLogSynchronizer(
                healthKitManager: appState.healthKitManager,
                calendar: Calendar.current
            )
            synchronizer.attachFoodEntryToDayLog(copy, modelContext: modelContext, userProfile: profile)
        }
        try? modelContext.save()
        // Pulse the summary bar to confirm a new entry was added.
        appState.triggerJustLoggedAnimation()
    }

    private func mealSectionHeader(mealType: MealType, entries: [FoodEntry]) -> some View {
        let totalCalories = entries.reduce(0.0) { $0 + $1.calories }
        return HStack {
            Text(mealType.displayName.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.88) // 0.08em for a ~11pt font
                .foregroundStyle(Color.textMuted)

            Spacer()

            Text("\(Int(totalCalories.rounded())) cal")
                .font(Font.entryMeta)
                .foregroundStyle(Color.textDim)
        }
        .padding(.horizontal, .screenPadding)
        .padding(.vertical, 6)
    }
}

// MARK: - Row for one log entry

private struct FoodLogEntryRow: View {
    let entry: FoodEntry
    let canCopyToToday: Bool
    let onCopyToToday: () -> Void

    init(
        entry: FoodEntry,
        canCopyToToday: Bool,
        onCopyToToday: @escaping () -> Void
    ) {
        self.entry = entry
        self.canCopyToToday = canCopyToToday
        self.onCopyToToday = onCopyToToday
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: .radiusSmall)
                .fill(iconBackground)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.name)
                    .font(Font.entryName)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(formattedTime(entry.timestamp))
                    .font(Font.entryMeta)
                    .foregroundStyle(Color.textDim)

                HStack(spacing: 6) {
                    if entry.confidence == .estimated {
                        badgeAI
                    } else if entry.confidence == .manual {
                        badgeManual
                    } else {
                        badgeRecipe
                    }
                }

                Text(macroString)
                    .font(Font.entryMeta)
                    .foregroundStyle(Color.textDim)
            }

            Spacer()

            Text("\(Int(entry.calories.rounded())) cal")
                .font(Font.cardValue)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, .cardPaddingH)
        .padding(.vertical, .cardPaddingV)
        .background(Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: .radiusCard)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: .radiusCard))
        .contextMenu {
            if canCopyToToday {
                Button("Copy to today") {
                    onCopyToToday()
                }
            }
        }
    }

    private var iconBackground: Color {
        entry.confidence == .estimated ? .iconBgOrange : .iconBgPurple
    }

    private var macroString: String {
        let p = Int(entry.protein.rounded())
        let c = Int(entry.carbs.rounded())
        let f = Int(entry.fat.rounded())
        return "\(p)p · \(c)c · \(f)f"
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private var badgeAI: some View {
        Text("AI EST.")
            .font(Font.badgeText)
            .foregroundStyle(Color.badgeAI)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "#32220A"))
            .overlay {
                RoundedRectangle(cornerRadius: .radiusBadge)
                    .stroke(Color(hex: "#4A3310"), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: .radiusBadge))
    }

    private var badgeRecipe: some View {
        Text("PRECISE")
            .font(Font.badgeText)
            .foregroundStyle(Color.badgeRecipe)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "#0D1A2A"))
            .overlay {
                RoundedRectangle(cornerRadius: .radiusBadge)
                    .stroke(Color(hex: "#0A2545"), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: .radiusBadge))
    }

    private var badgeManual: some View {
        Text("MANUAL")
            .font(Font.badgeText)
            .foregroundStyle(Color.badgeRecipe)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "#0D1A2A"))
            .overlay {
                RoundedRectangle(cornerRadius: .radiusBadge)
                    .stroke(Color(hex: "#0A2545"), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: .radiusBadge))
    }
}

#Preview {
    FoodLogView()
        .environment(AppState())
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
