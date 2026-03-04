//
//  HealthKitManager.swift
//  NutrAItion
//

import Foundation
import HealthKit

@Observable
final class HealthKitManager {
    private let store = HKHealthStore()

    var isAuthorized = false
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else {
            print("HealthKit: not available on this device")
            return
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: HealthKitPermissions.writeTypes, read: HealthKitPermissions.readTypes) { [weak self] _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                self?.isAuthorized = true
                continuation.resume()
            }
        }
    }

    // MARK: - Daily calories (return 0 if unavailable/unauthorized)

    func fetchDailyActiveCalories(for date: Date) async -> Double {
        guard isAvailable else {
            print("HealthKit: unavailable, returning 0 for active calories")
            return 0
        }
        return await withCheckedContinuation { continuation in
            let type = HealthKitPermissions.activeEnergyBurned
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    func fetchDailyBasalCalories(for date: Date) async -> Double {
        guard isAvailable else {
            print("HealthKit: unavailable, returning 0 for basal calories")
            return 0
        }
        return await withCheckedContinuation { continuation in
            let type = HealthKitPermissions.basalEnergyBurned
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    // MARK: - Heart rate samples (return empty if unavailable)

    func fetchHeartRateSamples(for date: Date) async -> [HKQuantitySample] {
        guard isAvailable else {
            print("HealthKit: unavailable, returning empty heart rate samples")
            return []
        }
        return await withCheckedContinuation { continuation in
            let type = HealthKitPermissions.heartRate
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                let list = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: list)
            }
            store.execute(query)
        }
    }

    // MARK: - Weight (read)

    func fetchWeightHistory(days: Int) async -> [(date: Date, weightKg: Double)] {
        guard isAvailable else {
            print("HealthKit: unavailable, returning empty weight history")
            return []
        }
        return await withCheckedContinuation { continuation in
            let type = HealthKitPermissions.bodyMass
            let end = Date()
            let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                let list = (samples as? [HKQuantitySample])?
                    .map { sample in
                        (date: sample.startDate, weightKg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                    } ?? []
                continuation.resume(returning: list)
            }
            store.execute(query)
        }
    }

    func fetchTodayWeight() async -> Double? {
        guard isAvailable else {
            print("HealthKit: unavailable, returning nil for today weight")
            return nil
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = Date()
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let type = HealthKitPermissions.bodyMass
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    // MARK: - Weight (write)

    func saveWeight(_ weightKg: Double, date: Date) async throws {
        guard isAvailable else {
            print("HealthKit: unavailable, cannot save weight")
            return
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let type = HealthKitPermissions.bodyMass
            let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
            let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
            store.save(sample) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
