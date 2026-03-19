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

    @State private var todayWeightKg: Double?
    @State private var weightDeltaKg: Double?
    @State private var showQuickAdd = false
    @State private var showBarcodeScanner = false
    @State private var showFoodSearch = false
    @State private var showManualEntry = false

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
                VStack(alignment: .leading, spacing: .sectionGap) {
                    headerSection
                    if let targets = appState.todaysMacroTargets {
                        calorieRingSection(targets: targets)
                        macroRingsSection(targets: targets)
                    }
                    effortAndWeightSection
                    quickAddSection
                    recentSection
                }
                .padding(.horizontal, .screenPadding)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadTodayWeight() }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(
                    onScanBarcode: { showQuickAdd = false; showBarcodeScanner = true },
                    onSearchFood: { showQuickAdd = false; showFoodSearch = true },
                    onManualEntry: { showQuickAdd = false; showManualEntry = true },
                    onTellAI: { showQuickAdd = false },
                    onDismiss: { showQuickAdd = false }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(
                    onBarcodeDetected: { _ in showBarcodeScanner = false },
                    onCancel: { showBarcodeScanner = false }
                )
            }
            .sheet(isPresented: $showFoodSearch) {
                FoodSearchView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showManualEntry) {
                ManualFoodEntryView(onDismiss: { showManualEntry = false })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .background(Color.appBackground)
        .scrollContentBackground(.hidden)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(Font.greeting)
                .foregroundStyle(Color.textMuted)
            Text("NutrAItion")
                .font(Font.screenTitle)
                .foregroundStyle(Color.textPrimary)
            Text(selectedDateFormatted)
                .font(Font.entryMeta)
                .foregroundStyle(Color.textDim)
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
            strokeColor: Color.accentPurple,
            trackColor: Color.ringTrack,
            label: "Remaining",
            unit: "",
            isLarge: true
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func macroRingsSection(targets: MacroTargets) -> some View {
        HStack(spacing: .cardGap) {
            macroCard {
                MacroRingView(
                    current: loggedTotals.1,
                    target: targets.protein,
                    strokeColor: Color.macroProtein,
                    trackColor: Color(hex: "#1E3830"),
                    label: "Protein",
                    unit: "g",
                    isLarge: false
                )
            }
            macroCard {
                MacroRingView(
                    current: loggedTotals.2,
                    target: targets.carbs,
                    strokeColor: Color.macroCarbs,
                    trackColor: Color(hex: "#382A18"),
                    label: "Carbs",
                    unit: "g",
                    isLarge: false
                )
            }
            macroCard {
                MacroRingView(
                    current: loggedTotals.3,
                    target: targets.fat,
                    strokeColor: Color.macroFat,
                    trackColor: Color(hex: "#38182E"),
                    label: "Fat",
                    unit: "g",
                    isLarge: false
                )
            }
        }
    }

    private var effortAndWeightSection: some View {
        macroCard {
            HStack(spacing: 16) {
                EffortBadgeView(level: appState.todaysEffortLevel)

                if let delta = weightDeltaKg {
                    let deltaStr = (delta >= 0 ? "+" : "") + String(format: "%.1f", delta)
                    let deltaColor: Color = delta < 0 ? .macroProtein : .textDim
                    Text("\(deltaStr) kg")
                        .font(Font.entryMeta)
                        .foregroundStyle(deltaColor)
                } else if let kg = todayWeightKg {
                    Text("\(String(format: "%.1f", kg)) kg")
                        .font(Font.entryMeta)
                        .foregroundStyle(Color.textDim)
                }

                Spacer()
            }
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
                    .font(Font.sectionTitle)
                Spacer()
                NavigationLink("See All") {
                    FoodLogView()
                }
                .font(Font.sectionTitle)
                .foregroundStyle(Color.accentPurple)
            }
            if recentEntries.isEmpty {
                Text("No entries today")
                    .font(Font.entryMeta)
                    .foregroundStyle(Color.textDim)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentEntries, id: \.id) { entry in
                    macroCard {
                        recentEntryRow(for: entry)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func macroCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .cardPaddingH)
            .padding(.vertical, .cardPaddingV)
            .background(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: .radiusCard)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: .radiusCard))
    }

    @ViewBuilder
    private func recentEntryRow(for entry: FoodEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack {
                entryIcon(for: entry)
            }
            .padding(.top, 2)

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
                        badgeAI()
                    } else if entry.confidence == .manual {
                        badgeManual()
                    } else {
                        badgeRecipe()
                    }
                }

                Text(macroString(for: entry))
                    .font(Font.entryMeta)
                    .foregroundStyle(Color.textDim)
            }

            Spacer()

            Text("\(Int(entry.calories.rounded())) cal")
                .font(Font.cardValue)
                .foregroundStyle(Color.accentPurple)
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func macroString(for entry: FoodEntry) -> String {
        let p = Int(entry.protein.rounded())
        let c = Int(entry.carbs.rounded())
        let f = Int(entry.fat.rounded())
        return "\(p)p · \(c)c · \(f)f"
    }

    private func entryIcon(for entry: FoodEntry) -> some View {
        let bg: Color = (entry.confidence == .estimated) ? .iconBgOrange : .iconBgPurple
        return RoundedRectangle(cornerRadius: .radiusSmall)
            .fill(bg)
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: "fork.knife")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            )
    }

    private func badgeAI() -> some View {
        Text("AI EST.")
            .font(Font.badgeText)
            .foregroundStyle(Color.badgeAI)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "#32220A"))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusBadge)
                    .stroke(Color(hex: "#4A3310"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: .radiusBadge))
    }

    private func badgeRecipe() -> some View {
        Text("PRECISE")
            .font(Font.badgeText)
            .foregroundStyle(Color.badgeRecipe)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "#0D1A2A"))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusBadge)
                    .stroke(Color(hex: "#0A2545"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: .radiusBadge))
    }

    private func badgeManual() -> some View {
        Text("MANUAL")
            .font(Font.badgeText)
            .foregroundStyle(Color.badgeRecipe)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "#0D1A2A"))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusBadge)
                    .stroke(Color(hex: "#0A2545"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: .radiusBadge))
    }

    private func loadTodayWeight() async {
        todayWeightKg = await appState.healthKitManager.fetchTodayWeight()

        // Best-effort: compute day-over-day delta for the effort/weight row.
        // If HealthKit has insufficient history, we fall back to just showing today's weight.
        let history = await appState.healthKitManager.fetchWeightHistory(days: 2)
        let todayStart = calendar.startOfDay(for: Date())
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

        func latestWeight(on dayStart: Date) -> Double? {
            let inDay = history.filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
            guard let latest = inDay.max(by: { $0.date < $1.date }) else { return nil }
            return latest.weightKg
        }

        let t = latestWeight(on: todayStart)
        let y = latestWeight(on: yesterdayStart)

        // If `fetchTodayWeight()` was nil but history provided a value, use it.
        if todayWeightKg == nil, let t {
            todayWeightKg = t
        }

        guard let t, let y else { return }
        weightDeltaKg = t - y
    }
}

// MARK: - Quick add sheet

private struct QuickAddSheet: View {
    var onScanBarcode: () -> Void
    var onSearchFood: () -> Void
    var onManualEntry: () -> Void
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
                    onManualEntry()
                } label: {
                    Label("Manual Entry", systemImage: "pencil.and.list.clipboard")
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
