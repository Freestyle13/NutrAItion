//
//  OnboardingFlow.swift
//  NutrAItion
//

import SwiftData
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case profile
    case goal
    case healthKit
    case complete
}

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var step: OnboardingStep = .welcome

    // About You
    @State private var age: Int = 30
    @State private var sex: BiologicalSex = .other
    @State private var weightLbs: Double = 150
    @State private var heightFeet: Int = 5
    @State private var heightInches: Double = 8

    // Your Goal
    @State private var goalType: GoalType = .maintain

    // HealthKit
    @State private var healthKitStatusText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepContent
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeView(
                onGetStarted: { step = .profile }
            )
        case .profile:
            OnboardingProfileView(
                age: $age,
                sex: $sex,
                weightLbs: $weightLbs,
                heightFeet: $heightFeet,
                heightInches: $heightInches,
                onBack: { step = .welcome },
                onContinue: { step = .goal }
            )
        case .goal:
            OnboardingGoalView(
                selectedGoal: goalType,
                onPickGoal: { goalType = $0 },
                onBack: { step = .profile },
                onContinue: { step = .healthKit }
            )
        case .healthKit:
            OnboardingHealthKitView(
                statusText: healthKitStatusText,
                onBack: { step = .goal },
                onConnect: connectHealthKit,
                onSkip: { step = .complete }
            )
        case .complete:
            let tdee = initialTdee()
            let weightKg = currentWeightKg()
            let targets = MacroTargetCalculator.calculate(
                tdee: tdee,
                goalType: goalType,
                bodyWeightKg: weightKg,
                leanMassKg: nil
            )
            OnboardingCompleteView(
                tdee: tdee,
                targets: targets,
                onBack: { step = .healthKit },
                onStartTracking: {
                    saveProfile(tdee: tdee, weightKg: weightKg, heightCm: currentHeightCm())
                }
            )
        }
    }

    private func saveProfile(tdee: Double, weightKg: Double, heightCm: Double) {
        let profile = UserProfile(
            age: age,
            sex: sex,
            heightCm: heightCm,
            currentWeightKg: weightKg,
            goalType: goalType,
            tdeeEstimate: tdee
        )

        modelContext.insert(profile)
        do {
            try modelContext.save()
        } catch {
            return
        }

        appState.userProfile = profile
        appState.refreshMacroTargets()
    }

    private func connectHealthKit() async {
        do {
            try await appState.healthKitManager.requestAuthorization()
            healthKitStatusText = "Connected"
        } catch {
            healthKitStatusText = "HealthKit not connected (continuing)"
        }
        step = .complete
    }

    // MARK: - Conversions

    private func currentWeightKg() -> Double {
        weightLbs * 0.45359237
    }

    private func currentHeightCm() -> Double {
        let totalInches = Double(heightFeet * 12) + heightInches
        return totalInches * 2.54
    }

    // MARK: - TDEE

    private func initialTdee() -> Double {
        let weightKg = currentWeightKg()
        let heightCm = currentHeightCm()
        let age = self.age

        // Mifflin-St Jeor:
        // Men: (10 × kg) + (6.25 × cm) - (5 × age) + 5
        // Women: (10 × kg) + (6.25 × cm) - (5 × age) - 161
        let bmrMale = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
        let bmrFemale = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) - 161

        let bmr: Double
        switch sex {
        case .male: bmr = bmrMale
        case .female: bmr = bmrFemale
        case .other: bmr = (bmrMale + bmrFemale) / 2
        }

        // Moderate activity assumption (engine will correct later).
        return bmr * 1.4
    }
}

#Preview {
    OnboardingFlow()
        .environment(AppState())
        .modelContainer(for: [UserProfile.self], inMemory: true)
}

