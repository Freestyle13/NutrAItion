//
//  SettingsView.swift
//  NutrAItion
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \UserProfile.createdAt, order: .reverse) private var profiles: [UserProfile]
    @Query(sort: \TDEEAdjustmentHistory.date, order: .reverse) private var adjustmentHistory: [TDEEAdjustmentHistory]

    // Profile drafts
    @State private var draftAge: Int = 30
    @State private var draftWeightLbs: Double = 150
    @State private var draftHeightFeet: Int = 5
    @State private var draftHeightInches: Double = 8
    @State private var draftGoalType: GoalType = .maintain

    // API key inputs
    @State private var usdaApiKeyInput = ""
    @State private var anthropicApiKeyInput = ""
    @State private var usdaSavedNotice = false
    @State private var anthropicSavedNotice = false

    // API test status
    @State private var usdaTestStatus: String?
    @State private var anthropicTestStatus: String?
    @State private var isTestingUSDA = false
    @State private var isTestingClaude = false

    // Targets help
    @State private var showHowCalculated = false

    // Export / reset
    @State private var exportFileURL: URL?
    @State private var showResetConfirm = false
    @State private var isResetting = false

    private let lbsPerKg = 2.2046
    private let inPerCm = 1 / 2.54

    private var profile: UserProfile? { profiles.first }
    private var lastTargetsUpdateDate: Date? { adjustmentHistory.first?.date }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                myTargetsSection
                apiKeysSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                usdaApiKeyInput = KeychainManager.load(key: Keys.usdaApiKey) ?? ""
                anthropicApiKeyInput = KeychainManager.load(key: Keys.anthropicApiKey) ?? ""
                if let profile {
                    loadDrafts(from: profile)
                }
            }
        }
        .sheet(isPresented: $showHowCalculated) {
            VStack(alignment: .leading, spacing: 16) {
                Text("How your adaptive targets are calculated")
                    .font(.title2.weight(.semibold))

                Text(
                    """
                    The app periodically compares your last 14 days of logged intake (weighted by entry confidence)
                    to your current TDEE estimate, adjusted by your effort level (from HealthKit when available).

                    It then updates TDEE with a small learning-rate step, clamped to ±100 cal/week.
                    Confidence tiers prevent unstable changes when data coverage is low.
                    """
                )
                .font(.body)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Reset learning engine?",
            isPresented: $showResetConfirm
        ) {
            Button("Reset", role: .destructive) {
                Task { await resetLearningEngine() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .disabled(isResetting)
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section("Profile") {
            Stepper("Age: \(draftAge)", value: $draftAge, in: 10...100, step: 1)

            Stepper("Weight (lbs): \(Int(draftWeightLbs.rounded()))", value: $draftWeightLbs, in: 60...400, step: 1)

            HStack(spacing: 12) {
                Stepper("Height (ft): \(draftHeightFeet)", value: $draftHeightFeet, in: 3...7, step: 1)
                Stepper("Height (in): \(Int(draftHeightInches.rounded()))", value: $draftHeightInches, in: 0...11, step: 1)
            }

            Picker("Goal type", selection: $draftGoalType) {
                ForEach(GoalType.allCases, id: \.self) { g in
                    Text(g.displayName).tag(g)
                }
            }

            Button("Save profile changes") {
                saveProfileChanges()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var myTargetsSection: some View {
        Section("My Targets (engine-managed)") {
            if let profile {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current TDEE estimate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(profile.tdeeEstimate)) cal")
                            .font(.title3.weight(.semibold))
                    }
                    Spacer()
                    Button {
                        showHowCalculated = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                let targets = MacroTargetCalculator.calculate(
                    tdee: profile.tdeeEstimate,
                    goalType: profile.goalType,
                    bodyWeightKg: profile.currentWeightKg,
                    leanMassKg: profile.leanMassKg
                )

                Text("Daily targets: Protein \(Int(targets.protein))g · Carbs \(Int(targets.carbs))g · Fat \(Int(targets.fat))g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let lastTargetsUpdateDate {
                    Text("Last updated: \(formattedDate(lastTargetsUpdateDate))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Last updated: —")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Finish onboarding to see your targets.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var apiKeysSection: some View {
        Section("API Keys") {
            VStack(alignment: .leading, spacing: 10) {
                SecureField("USDA API Key", text: $usdaApiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.password)

                HStack {
                    Button("Save USDA key") { saveUSDA() }
                    Spacer()
                    Button("Test") {
                        Task { await testUSDAKey() }
                    }
                    .disabled(isTestingUSDA)
                }

                if usdaSavedNotice {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let usdaTestStatus, !usdaTestStatus.isEmpty {
                    Text(usdaTestStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SecureField("Anthropic API Key", text: $anthropicApiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.password)

                HStack {
                    Button("Save Claude key") { saveAnthropic() }
                    Spacer()
                    Button("Test") {
                        Task { await testClaudeKey() }
                    }
                    .disabled(isTestingClaude)
                }

                if anthropicSavedNotice {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let anthropicTestStatus, !anthropicTestStatus.isEmpty {
                    Text(anthropicTestStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button("Export my data") {
                exportDataCSV()
            }
            .buttonStyle(.bordered)

            Button("Reset learning engine") {
                showResetConfirm = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            if let exportFileURL {
                ShareLink(item: exportFileURL) {
                    Text("Share CSV export")
                }
                .padding(.top, 6)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Text("App version: \(appVersion())")
            Link("Privacy policy", destination: URL(string: "https://example.com/privacy")!)
        }
    }

    // MARK: - Actions

    private func loadDrafts(from profile: UserProfile) {
        draftAge = profile.age
        draftGoalType = profile.goalType
        draftWeightLbs = profile.currentWeightKg * lbsPerKg

        let totalInches = profile.heightCm * inPerCm
        draftHeightFeet = Int(totalInches / 12)
        draftHeightInches = totalInches.truncatingRemainder(dividingBy: 12)
    }

    private func saveProfileChanges() {
        guard let profile else { return }

        let weightKg = draftWeightLbs / lbsPerKg
        let heightTotalInches = Double(draftHeightFeet * 12) + draftHeightInches
        let heightCm = heightTotalInches * 2.54

        profile.age = draftAge
        profile.goalType = draftGoalType
        profile.currentWeightKg = weightKg
        profile.heightCm = heightCm

        try? modelContext.save()
        appState.refreshMacroTargets()
    }

    private func saveUSDA() {
        usdaSavedNotice = KeychainManager.save(key: Keys.usdaApiKey, value: usdaApiKeyInput)
        if usdaSavedNotice {
            usdaTestStatus = nil
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { usdaSavedNotice = false }
            }
        }
    }

    private func saveAnthropic() {
        anthropicSavedNotice = KeychainManager.save(key: Keys.anthropicApiKey, value: anthropicApiKeyInput)
        if anthropicSavedNotice {
            anthropicTestStatus = nil
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { anthropicSavedNotice = false }
            }
        }
    }

    private func testUSDAKey() async {
        isTestingUSDA = true
        defer { isTestingUSDA = false }

        usdaTestStatus = nil
        let service = USDAService()
        do {
            _ = try await service.searchFood("apple")
            usdaTestStatus = "USDA key looks valid."
        } catch {
            usdaTestStatus = "USDA test failed: \(error.localizedDescription)"
        }
    }

    private func testClaudeKey() async {
        isTestingClaude = true
        defer { isTestingClaude = false }

        anthropicTestStatus = nil
        let service = ClaudeAPIService()
        do {
            _ = try await service.estimateFoodNutrition("apple")
            anthropicTestStatus = "Claude key looks valid."
        } catch {
            anthropicTestStatus = "Claude test failed: \(error.localizedDescription)"
        }
    }

    private func exportDataCSV() {
        do {
            let entries = try modelContext.fetch(
                FetchDescriptor<FoodEntry>(
                    sortBy: [SortDescriptor(\.timestamp)]
                )
            )

            var csv = "timestamp,name,mealType,confidence,calories,protein,carbs,fat,notes\n"
            let iso = ISO8601DateFormatter()
            for e in entries {
                let ts = iso.string(from: e.timestamp)
                let notes = e.notes?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
                let safeNotes = notes.contains(",") ? "\"\(notes)\"" : notes
                let safeName = e.name.replacingOccurrences(of: "\"", with: "\"\"")
                csv += "\(ts),\"\(safeName)\",\(e.mealType.rawValue),\(e.confidence.rawValue),\(e.calories),\(e.protein),\(e.carbs),\(e.fat),\(safeNotes)\n"
            }

            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("nutraiton_export_\(Int(Date().timeIntervalSince1970)).csv")
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            exportFileURL = fileURL
        } catch {
            exportFileURL = nil
        }
    }

    private func resetLearningEngine() async {
        guard let profile else { return }

        isResetting = true
        defer { isResetting = false }

        // Clear history.
        for item in adjustmentHistory {
            modelContext.delete(item)
        }

        // Reset to Mifflin-St Jeor baseline (same as onboarding assumption).
        let weightKg = profile.currentWeightKg
        let heightCm = profile.heightCm
        let age = profile.age

        let bmrMale = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
        let bmrFemale = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) - 161

        let bmr: Double
        switch profile.sex {
        case .male: bmr = bmrMale
        case .female: bmr = bmrFemale
        case .other: bmr = (bmrMale + bmrFemale) / 2
        }

        profile.tdeeEstimate = bmr * 1.4
        profile.weeklyAdjustmentCount = 0

        // Save + refresh.
        try? modelContext.save()
        appState.refreshMacroTargets()

        // Allow engine to run again soon after reset.
        UserDefaults.standard.removeObject(forKey: "tdeeEngineLastRunDate")
    }

    // MARK: - Helpers

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

#Preview {
    SettingsView()
}

