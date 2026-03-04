//
//  WeightSmoother.swift
//  NutrAItion
//

import Foundation

/// 7-day rolling average smoothing for body weight. Pure logic, no external dependencies.
struct WeightSmoother {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Takes raw weight entries sorted by date; returns one (date, smoothedKg) per input date.
    /// Uses trailing 7-day window; interpolates missing days; returns raw value if fewer than 3 data points in window.
    func smooth(entries: [(date: Date, weightKg: Double)]) -> [(date: Date, smoothedKg: Double)] {
        guard !entries.isEmpty else { return [] }
        return entries.map { entry in
            let windowStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: entry.date))!
            let windowEnd = calendar.startOfDay(for: entry.date)
            let entriesInWindow = entries.filter { e in
                let d = calendar.startOfDay(for: e.date)
                return d >= windowStart && d <= windowEnd
            }
            if entriesInWindow.count < 3 {
                return (date: entry.date, smoothedKg: entry.weightKg)
            }
            var sum = 0.0
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: windowEnd) else { continue }
                let w = interpolatedWeight(for: day, in: entries) ?? entry.weightKg
                sum += w
            }
            return (date: entry.date, smoothedKg: sum / 7.0)
        }
    }

    /// Smoothed weight for a specific date using a trailing window. Nil if fewer than 3 entries in window.
    func rollingAverage(for date: Date, in entries: [(date: Date, weightKg: Double)], windowDays: Int = 7) -> Double? {
        let dayStart = calendar.startOfDay(for: date)
        let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: dayStart)!
        let entriesInWindow = entries.filter { e in
            let d = calendar.startOfDay(for: e.date)
            return d >= windowStart && d <= dayStart
        }
        if entriesInWindow.count < 3 { return nil }
        var sum = 0.0
        for offset in 0..<windowDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: dayStart) else { continue }
            guard let w = interpolatedWeight(for: day, in: entries) else { return nil }
            sum += w
        }
        return sum / Double(windowDays)
    }

    /// Change in smoothed weight between two dates. Nil if either date not present in smoothed entries.
    func weightDelta(from startDate: Date, to endDate: Date, in smoothedEntries: [(date: Date, smoothedKg: Double)]) -> Double? {
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        guard let w1 = smoothedEntries.first(where: { calendar.isDate($0.date, inSameDayAs: startDay) })?.smoothedKg,
              let w2 = smoothedEntries.first(where: { calendar.isDate($0.date, inSameDayAs: endDay) })?.smoothedKg else {
            return nil
        }
        return w2 - w1
    }

    // MARK: - Private

    /// Linear interpolation for a calendar day from sorted entries. Uses first/last weight if outside range.
    private func interpolatedWeight(for day: Date, in entries: [(date: Date, weightKg: Double)]) -> Double? {
        guard !entries.isEmpty else { return nil }
        let dayStart = calendar.startOfDay(for: day)
        let sorted = entries.sorted { calendar.startOfDay(for: $0.date) < calendar.startOfDay(for: $1.date) }
        let first = calendar.startOfDay(for: sorted[0].date)
        let last = calendar.startOfDay(for: sorted[sorted.count - 1].date)
        if dayStart <= first { return sorted[0].weightKg }
        if dayStart >= last { return sorted[sorted.count - 1].weightKg }
        for i in 0..<(sorted.count - 1) {
            let d1 = calendar.startOfDay(for: sorted[i].date)
            let d2 = calendar.startOfDay(for: sorted[i + 1].date)
            if dayStart >= d1 && dayStart <= d2 {
                let w1 = sorted[i].weightKg, w2 = sorted[i + 1].weightKg
                let t = d2.timeIntervalSince(d1)
                guard t > 0 else { return w1 }
                let s = dayStart.timeIntervalSince(d1) / t
                return w1 + (w2 - w1) * s
            }
        }
        return nil
    }
}
