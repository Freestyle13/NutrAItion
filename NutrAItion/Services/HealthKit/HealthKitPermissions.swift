//
//  HealthKitPermissions.swift
//  NutrAItion
//

import Foundation
import HealthKit

/// Central definition of HealthKit types we read and write.
struct HealthKitPermissions {
    // MARK: - Quantity types (read)
    static let activeEnergyBurned = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    static let basalEnergyBurned = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
    static let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    static let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass)!

    // MARK: - Object types (read)
    static let workoutType = HKObjectType.workoutType()

    // MARK: - Type sets for requestAuthorization (read: Set<HKObjectType>, toShare: Set<HKSampleType>)
    static var readTypes: Set<HKObjectType> {
        Set([
            activeEnergyBurned,
            basalEnergyBurned,
            heartRate,
            bodyMass,
            workoutType,
        ])
    }

    static var writeTypes: Set<HKSampleType> {
        Set([bodyMass])
    }
}
