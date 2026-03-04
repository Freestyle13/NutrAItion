//
//  WeightSmootherTests.swift
//  NutrAItionTests
//

import XCTest
@testable import NutrAItion

final class WeightSmootherTests: XCTestCase {
    private var calendar: Calendar!
    private var smoother: WeightSmoother!

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        smoother = WeightSmoother(calendar: calendar)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comp = DateComponents()
        comp.year = year
        comp.month = month
        comp.day = day
        return calendar.date(from: comp)!
    }

    func test_smooth_sevenConsistentEntries_returnsCorrectAverage() {
        // 7 days, same weight 70 kg every day → smoothed = 70
        let base = date(2025, 1, 1)
        let entries = (0..<7).map { i in
            (date: calendar.date(byAdding: .day, value: i, to: base)!, weightKg: 70.0)
        }
        let result = smoother.smooth(entries: entries)
        XCTAssertEqual(result.count, 7)
        for r in result {
            XCTAssertEqual(r.smoothedKg, 70.0, accuracy: 0.01)
        }
    }

    func test_smooth_missingDays_interpolatesCorrectly() {
        // Day 1 = 70, Day 7 = 76 (no entries on 2–6). Interpolate; 7-day window for day 7 includes interpolated values.
        let entries: [(date: Date, weightKg: Double)] = [
            (date(2025, 1, 1), 70.0),
            (date(2025, 1, 7), 76.0),
        ]
        let result = smoother.smooth(entries: entries)
        XCTAssertEqual(result.count, 2)
        // Day 1: window has only 2 entries (< 3) → raw 70
        XCTAssertEqual(result[0].smoothedKg, 70.0, accuracy: 0.01)
        // Day 7: window [Jan 1–7] has 2 entries, still < 3 → raw 76
        XCTAssertEqual(result[1].smoothedKg, 76.0, accuracy: 0.01)
    }

    func test_smooth_missingDays_interpolatesCorrectly_withEnoughInWindow() {
        // 4 entries; for Jan 3, window [Dec 28–Jan 3]: Dec 28–31 interpolate to 70, Jan 1=70, 2=71, 3=72 → avg ≈ 70.43
        let entries: [(date: Date, weightKg: Double)] = [
            (date(2025, 1, 1), 70.0),
            (date(2025, 1, 2), 71.0),
            (date(2025, 1, 3), 72.0),
            (date(2025, 1, 7), 76.0),
        ]
        let result = smoother.smooth(entries: entries)
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[2].smoothedKg, 70.43, accuracy: 0.1)
    }

    func test_smooth_fewerThanThreePoints_returnsRawValue() {
        let entries: [(date: Date, weightKg: Double)] = [
            (date(2025, 1, 1), 80.0),
            (date(2025, 1, 2), 81.0),
        ]
        let result = smoother.smooth(entries: entries)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].smoothedKg, 80.0)
        XCTAssertEqual(result[1].smoothedKg, 81.0)
    }

    func test_weightDelta_correctlyCalculatesChange() {
        let smoothedEntries: [(date: Date, smoothedKg: Double)] = [
            (date(2025, 1, 1), 70.0),
            (date(2025, 1, 7), 71.5),
        ]
        let delta = smoother.weightDelta(from: date(2025, 1, 1), to: date(2025, 1, 7), in: smoothedEntries)
        XCTAssertEqual(delta!, 1.5, accuracy: 0.01)
    }

    func test_weightDelta_missingDate_returnsNil() {
        let smoothedEntries: [(date: Date, smoothedKg: Double)] = [
            (date(2025, 1, 1), 70.0),
        ]
        XCTAssertNil(smoother.weightDelta(from: date(2025, 1, 1), to: date(2025, 1, 7), in: smoothedEntries))
    }

    func test_rollingAverage_insufficientData_returnsNil() {
        let entries: [(date: Date, weightKg: Double)] = [
            (date(2025, 1, 1), 70.0),
            (date(2025, 1, 2), 71.0),
        ]
        XCTAssertNil(smoother.rollingAverage(for: date(2025, 1, 2), in: entries))
    }

    func test_rollingAverage_sufficientData_returnsAverage() {
        let base = date(2025, 1, 1)
        let entries = (0..<7).map { i in
            (date: calendar.date(byAdding: .day, value: i, to: base)!, weightKg: 70.0 + Double(i))
        }
        let avg = smoother.rollingAverage(for: date(2025, 1, 7), in: entries)
        XCTAssertNotNil(avg)
        XCTAssertEqual(avg!, 73.0, accuracy: 0.1) // 70+71+...+76 / 7 = 73
    }
}
