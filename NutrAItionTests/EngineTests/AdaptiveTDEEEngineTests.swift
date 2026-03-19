//
//  AdaptiveTDEEEngineTests.swift
//  NutrAItionTests
//

import XCTest
import SwiftData
@testable import NutrAItion

final class AdaptiveTDEEEngineTests: XCTestCase {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private var engine: AdaptiveTDEEEngine {
        AdaptiveTDEEEngine(calendar: utcCalendar)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([DayLog.self, FoodEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @discardableResult
    private func insertDay(
        context: ModelContext,
        dayIndex: Int,
        baseDate: Date,
        smoothedWeight: Double,
        calories: Double,
        confidence: Confidence,
        effort: EffortLevel = .moderate
    ) -> DayLog {
        let date = utcCalendar.date(byAdding: .day, value: dayIndex, to: baseDate)!
        let log = DayLog(date: date, effortLevel: effort, smoothedWeight: smoothedWeight, tdeeEstimateAtDate: 2500)
        let entry = FoodEntry(
            name: "Test",
            calories: calories,
            protein: 0,
            carbs: 0,
            fat: 0,
            confidence: confidence,
            mealType: .breakfast
        )
        entry.dayLog = log
        log.entries.append(entry)
        context.insert(log)
        context.insert(entry)
        return log
    }

    // MARK: - 1

    func test_analyze_insufficientData_returnsNoChange() throws {
        let ctx = try makeInMemoryContext()
        let base = utcCalendar.date(from: DateComponents(year: 2025, month: 6, day: 1))!
        for i in 0..<10 {
            insertDay(context: ctx, dayIndex: i, baseDate: base, smoothedWeight: 80, calories: 2000, confidence: .precise)
        }
        let logs = try ctx.fetch(FetchDescriptor<DayLog>())
        let result = engine.analyze(dayLogs: logs, currentTDEE: 2500)
        XCTAssertEqual(result.confidence, .insufficient)
        XCTAssertEqual(result.delta, 0, accuracy: 0.01)
        XCTAssertEqual(result.recommendedTDEE, 2500, accuracy: 0.01)
    }

    // MARK: - 2

    func test_analyze_weightLossSlowerThanExpected_increasesTDEE() throws {
        let ctx = try makeInMemoryContext()
        let base = utcCalendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        for i in 0..<28 {
            let w: Double
            if i < 14 {
                w = 81
            } else {
                let j = Double(i - 14)
                w = 80.0 - 0.5 * (j / 13.0)
            }
            insertDay(context: ctx, dayIndex: i, baseDate: base, smoothedWeight: w, calories: 2000, confidence: .precise)
        }
        let logs = try ctx.fetch(FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.date)]))
        let result = engine.analyze(dayLogs: logs, currentTDEE: 2500)
        XCTAssertGreaterThan(result.delta, 0, "Slower loss than predicted → higher TDEE")
        XCTAssertEqual(result.confidence, .high)
    }

    // MARK: - 3

    func test_analyze_weightLossMatchesPrediction_minimalAdjustment() throws {
        let ctx = try makeInMemoryContext()
        let base = utcCalendar.date(from: DateComponents(year: 2025, month: 3, day: 1))!
        let expectedDeltaKg = (-500.0 * 14.0) / 7700.0
        let startW = 80.0
        let endW = startW + expectedDeltaKg
        for i in 0..<28 {
            let w: Double
            if i < 14 {
                w = startW
            } else {
                let j = Double(i - 14)
                w = startW + (endW - startW) * (j / 13.0)
            }
            insertDay(context: ctx, dayIndex: i, baseDate: base, smoothedWeight: w, calories: 2000, confidence: .precise)
        }
        let logs = try ctx.fetch(FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.date)]))
        let result = engine.analyze(dayLogs: logs, currentTDEE: 2500)
        XCTAssertLessThan(abs(result.delta), 15, "Near-zero adjustment when trajectory matches prediction")
    }

    // MARK: - 4

    func test_analyze_anomalousWeightChange_skipsAdjustment() throws {
        let ctx = try makeInMemoryContext()
        let base = utcCalendar.date(from: DateComponents(year: 2025, month: 4, day: 1))!
        for i in 0..<28 {
            let w: Double
            if i < 14 {
                w = 80
            } else {
                let j = Double(i - 14)
                w = 80.0 - 4.0 * (j / 13.0)
            }
            insertDay(context: ctx, dayIndex: i, baseDate: base, smoothedWeight: w, calories: 2000, confidence: .precise)
        }
        let logs = try ctx.fetch(FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.date)]))
        let result = engine.analyze(dayLogs: logs, currentTDEE: 2500)
        XCTAssertEqual(result.delta, 0, accuracy: 0.01)
        XCTAssertEqual(result.recommendedTDEE, 2500, accuracy: 0.01)
        XCTAssertEqual(result.confidence, .low)
    }

    // MARK: - 5

    func test_analyze_adjustmentCappedAt100Calories() throws {
        let ctx = try makeInMemoryContext()
        let base = utcCalendar.date(from: DateComponents(year: 2025, month: 5, day: 1))!
        for i in 0..<28 {
            let w: Double
            if i < 14 {
                w = 78
            } else {
                let j = Double(i - 14)
                w = 78.0 + 2.0 * (j / 13.0)
            }
            insertDay(context: ctx, dayIndex: i, baseDate: base, smoothedWeight: w, calories: 2500, confidence: .precise)
        }
        let logs = try ctx.fetch(FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.date)]))
        let result = engine.analyze(dayLogs: logs, currentTDEE: 2500)
        XCTAssertEqual(result.delta, 100, accuracy: 0.01)
        XCTAssertEqual(result.recommendedTDEE, 2600, accuracy: 0.01)
    }

    // MARK: - 6

    func test_analyze_estimatedEntriesWeightedCorrectly() throws {
        let base = utcCalendar.date(from: DateComponents(year: 2025, month: 7, day: 1))!

        func run(confidence: Confidence) throws -> TDEEAdjustment {
            let ctx = try makeInMemoryContext()
            for i in 0..<28 {
                let w: Double
                if i < 14 {
                    w = 79
                } else {
                    let j = Double(i - 14)
                    w = 79.0 - 1.0 * (j / 13.0)
                }
                insertDay(context: ctx, dayIndex: i, baseDate: base, smoothedWeight: w, calories: 2000, confidence: confidence)
            }
            let logs = try ctx.fetch(FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.date)]))
            return engine.analyze(dayLogs: logs, currentTDEE: 2500)
        }

        let precise = try run(confidence: .precise)
        let estimated = try run(confidence: .estimated)
        XCTAssertNotEqual(precise.recommendedTDEE, estimated.recommendedTDEE, accuracy: 0.5)
    }
}
