//
//  AppState.swift
//  NutrAItion
//

import Foundation
import SwiftData

@Observable
final class AppState {
    var userProfile: UserProfile?
    let healthKitManager = HealthKitManager()
    var todaysMacroTargets: MacroTargets?
    /// Set when today's DayLog/effort is computed (Phase 4+). Nil = show placeholder in dashboard.
    var todaysEffortLevel: EffortLevel?

    var isOnboardingComplete: Bool { userProfile != nil }

    /// Loads the singleton UserProfile from SwiftData (there should be at most one).
    func loadUserProfile(context: ModelContext) {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        do {
            let results = try context.fetch(descriptor)
            userProfile = results.first
        } catch {
            userProfile = nil
        }
    }

    /// Recomputes today's macro targets from the current user profile and caches the result.
    func refreshMacroTargets() {
        guard let profile = userProfile else {
            todaysMacroTargets = nil
            return
        }
        todaysMacroTargets = MacroTargetCalculator.calculate(
            tdee: profile.tdeeEstimate,
            goalType: profile.goalType,
            bodyWeightKg: profile.currentWeightKg,
            leanMassKg: profile.leanMassKg
        )
    }
}
