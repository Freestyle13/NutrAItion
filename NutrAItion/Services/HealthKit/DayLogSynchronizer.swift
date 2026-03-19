//
//  DayLogSynchronizer.swift
//  NutrAItion
//

import Foundation
import SwiftData
import HealthKit

/// Populates `DayLog` records from HealthKit and keeps `smoothedWeight` up to date.
///
/// - Runs at most once per day (guarded by `UserDefaults`).
/// - Ensures each day in the last 30 days has:
///   - `effortLevel` (from active calories + heart rate)
///   - `rawWeight` (from weight samples)
///   - `smoothedWeight` (computed via `WeightSmoother`)
struct DayLogSynchronizer {
    private enum DefaultsKeys {
        static let lastSyncDate = "dayLogLastSyncDate"
    }

    private let healthKit: HealthKitManager
    private let effortCalculator: EffortScoreCalculator
    private let weightSmoother: WeightSmoother
    private let calendar: Calendar

    init(
        healthKitManager: HealthKitManager,
        calendar: Calendar = .current,
        effortCalculator: EffortScoreCalculator = EffortScoreCalculator(),
        weightSmoother: WeightSmoother? = nil
    ) {
        self.healthKit = healthKitManager
        self.effortCalculator = effortCalculator
        self.calendar = calendar
        self.weightSmoother = weightSmoother ?? WeightSmoother(calendar: calendar)
    }

    /// Synchronize DayLogs from HealthKit (once per day).
    func synchronizeIfNeeded(modelContext: ModelContext, userProfile: UserProfile) async {
        guard healthKit.isAvailable else { return }

        let now = Date()
        if let last = UserDefaults.standard.object(forKey: DefaultsKeys.lastSyncDate) as? Date,
           calendar.isDate(last, inSameDayAs: now) {
            return
        }

        // Build last-30-days day starts.
        let todayStart = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let dayStarts: [Date] = (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }

        // Preload existing logs for those days.
        let allLogs: [DayLog]
        do {
            allLogs = try modelContext.fetch(FetchDescriptor<DayLog>())
        } catch {
            return
        }

        let logsByDayStart: [Date: DayLog] = {
            var dict: [Date: DayLog] = [:]
            for log in allLogs {
                let key = calendar.startOfDay(for: log.date)
                if dayStarts.contains(key) {
                    dict[key] = log
                }
            }
            return dict
        }()

        var workingLogsByDayStart = logsByDayStart

        // Fetch weight history once, map to per-day start-of-day.
        let weightSamples = await healthKit.fetchWeightHistory(days: 30)
        let weightByDayStart: [Date: Double] = {
            var dict: [Date: (date: Date, weightKg: Double)] = [:]
            for (date, weightKg) in weightSamples {
                let dayStart = calendar.startOfDay(for: date)
                // If multiple samples exist in a day, use the latest sample time.
                if let existing = dict[dayStart] {
                    if existing.date < date {
                        dict[dayStart] = (date: date, weightKg: weightKg)
                    }
                } else {
                    dict[dayStart] = (date: date, weightKg: weightKg)
                }
            }
            return dict.mapValues { $0.weightKg }
        }()

        // Ensure logs exist and compute effort for days missing effort/weight data.
        for dayStart in dayStarts {
            if workingLogsByDayStart[dayStart] == nil {
                let created = DayLog(
                    date: dayStart,
                    effortLevel: .moderate,
                    rawWeight: nil,
                    smoothedWeight: nil,
                    tdeeEstimateAtDate: userProfile.tdeeEstimate
                )
                modelContext.insert(created)
                workingLogsByDayStart[dayStart] = created
            }

            guard let log = workingLogsByDayStart[dayStart] else { continue }

            // Update raw weight if we have it.
            if let w = weightByDayStart[dayStart], log.rawWeight != w {
                log.rawWeight = w
            }

            // Compute effort if the log still doesn't have weight or smoothed weight.
            let needsEffort = (log.rawWeight == nil) || (log.smoothedWeight == nil)
            if needsEffort {
                let activeCalories = await healthKit.fetchDailyActiveCalories(for: dayStart)
                let hrSamples = await healthKit.fetchHeartRateSamples(for: dayStart)
                let effort = effortCalculator.calculate(
                    heartRateSamples: hrSamples,
                    activeCalories: activeCalories,
                    age: userProfile.age
                )
                log.effortLevel = effort
            }
        }

        // Recompute smoothed weight for all logs in range.
        let weightEntries: [(date: Date, weightKg: Double)] = weightByDayStart
            .map { (date: $0.key, weightKg: $0.value) }
            .sorted { $0.date < $1.date }

        for dayStart in dayStarts {
            guard let log = workingLogsByDayStart[dayStart] else { continue }
            log.smoothedWeight = weightSmoother.rollingAverage(for: log.date, in: weightEntries)
        }

        do {
            try modelContext.save()
            UserDefaults.standard.set(now, forKey: DefaultsKeys.lastSyncDate)
        } catch {
            return
        }
    }

    /// Ensures a `DayLog` exists for the day of `entry.timestamp`, and attaches the entry to it.
    ///
    /// This does not call HealthKit; it’s intended to keep the engine inputs consistent
    /// immediately after logging food.
    func attachFoodEntryToDayLog(
        _ entry: FoodEntry,
        modelContext: ModelContext,
        userProfile: UserProfile
    ) {
        let dayStart = calendar.startOfDay(for: entry.timestamp)

        var descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate { log in
                log.date == dayStart
            }
        )
        descriptor.fetchLimit = 1

        let existing = (try? modelContext.fetch(descriptor).first)

        let log: DayLog
        if let existing {
            log = existing
        } else {
            log = DayLog(
                date: dayStart,
                effortLevel: .moderate,
                rawWeight: nil,
                smoothedWeight: nil,
                tdeeEstimateAtDate: userProfile.tdeeEstimate
            )
            modelContext.insert(log)
        }

        entry.dayLog = log
        if !log.entries.contains(where: { $0.id == entry.id }) {
            log.entries.append(entry)
        }
    }
}

