//
//  EngineCoordinator.swift
//  NutrAItion
//

import Foundation
import SwiftData
import Observation
import UserNotifications

/// Orchestrates the adaptive TDEE engine run.
/// - Trigger: app foreground (see `AppEntry`)
/// - Gating: only run if 7+ days have passed since the last run
@Observable
@MainActor
final class EngineCoordinator {
    private enum DefaultsKeys {
        static let lastEngineRunDate = "tdeeEngineLastRunDate"
    }

    private let calendar: Calendar
    private let engine: AdaptiveTDEEEngine

    init() {
        let cal = Calendar.current
        self.calendar = cal
        self.engine = AdaptiveTDEEEngine(calendar: cal)
    }

    func runIfDue(
        modelContext: ModelContext,
        appState: AppState
    ) {
        Task { await runIfDueAsync(modelContext: modelContext, appState: appState) }
    }

    private func runIfDueAsync(
        modelContext: ModelContext,
        appState: AppState
    ) async {
        // Ensure onboarding is complete (we need a UserProfile to read current TDEE + effort multipliers).
        if appState.userProfile == nil {
            appState.loadUserProfile(context: modelContext)
        }
        guard let profile = appState.userProfile else { return }

        let now = Date()
        let lastRun = UserDefaults.standard.object(forKey: DefaultsKeys.lastEngineRunDate) as? Date
        let daysSinceLastRun: Int = {
            guard let lastRun else { return Int.max } // due immediately
            return calendar.dateComponents([.day], from: lastRun, to: now).day ?? 0
        }()

        guard daysSinceLastRun >= 7 else { return }

        // Ensure DayLogs exist and `smoothedWeight` is up to date before analyzing.
        let synchronizer = DayLogSynchronizer(
            healthKitManager: appState.healthKitManager,
            calendar: calendar
        )
        await synchronizer.synchronizeIfNeeded(modelContext: modelContext, userProfile: profile)

        // Pull all existing day logs for the engine analysis.
        let dayLogs: [DayLog]
        do {
            dayLogs = try modelContext.fetch(FetchDescriptor<DayLog>())
        } catch {
            return
        }

        let result = engine.analyze(
            dayLogs: dayLogs,
            currentTDEE: profile.tdeeEstimate,
            effortMultipliers: profile.effortMultipliers
        )

        // Always store history for the trends view (even if insufficient data).
        let history = TDEEAdjustmentHistory(
            date: now,
            previousTDEE: result.previousTDEE,
            newTDEE: result.recommendedTDEE,
            delta: result.delta,
            confidence: result.confidence.rawValue,
            reasoning: result.reasoning
        )
        modelContext.insert(history)

        let shouldUpdateTDEE = result.confidence != .insufficient
        if shouldUpdateTDEE {
            profile.tdeeEstimate = result.recommendedTDEE
            profile.weeklyAdjustmentCount += 1
        }

        do {
            try modelContext.save()
            UserDefaults.standard.set(now, forKey: DefaultsKeys.lastEngineRunDate)
        } catch {
            return
        }

        // Update in-memory macro targets after persistence.
        if shouldUpdateTDEE {
            appState.refreshMacroTargets()
            Task { await self.sendMacroTargetsUpdatedNotification() }
        }
    }

    private func sendMacroTargetsUpdatedNotification() async {
        let center = UNUserNotificationCenter.current()

        // Request permission if we haven't asked yet.
        let settings = await getNotificationSettings(center)
        if settings.authorizationStatus == .notDetermined {
            do {
                _ = try await requestNotificationAuthorization(center)
            } catch {
                // Non-fatal; we can still proceed without notifications.
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "NutrAItion"
        content.body = "Your macro targets were updated based on your progress"
        content.sound = .default

        // Fire soon after the foreground transition.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await addNotificationRequest(center, request)
        } catch {
            // Non-fatal.
        }
    }

    private func getNotificationSettings(_ center: UNUserNotificationCenter) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestNotificationAuthorization(_ center: UNUserNotificationCenter) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func addNotificationRequest(_ center: UNUserNotificationCenter, _ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

