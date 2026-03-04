//
//  OnboardingFlow.swift
//  NutrAItion
//

import SwiftUI
import SwiftData

/// Shown when no UserProfile exists. Phase 6 will replace with full onboarding steps.
struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to NutrAItion")
                .font(.title)
            Text("Track nutrition and let the app learn your metabolism.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Get Started") {
                completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func completeOnboarding() {
        let profile = UserProfile(
            age: 30,
            sex: .other,
            heightCm: 170,
            currentWeightKg: 70,
            goalType: .maintain,
            tdeeEstimate: 2000
        )
        modelContext.insert(profile)
        do {
            try modelContext.save()
        } catch {
            return
        }
        appState.loadUserProfile(context: modelContext)
        appState.refreshMacroTargets()
    }
}

#Preview {
    OnboardingFlow()
        .environment(AppState())
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
