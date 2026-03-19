//
//  WeightChartView.swift
//  NutrAItion
//

import Charts
import SwiftData
import SwiftUI

struct WeightChartView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \DayLog.date) private var dayLogs: [DayLog]

    @State private var selectedDayStart: Date?

    private let lbsPerKg = 2.2046
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    var body: some View {
        let (rangeStart, rangeEnd, dayStarts) = lastNDaysRange(n: 30)
        let byDayStart = bestDayLogByDayStart(dayStarts: dayStarts)

        let rawPoints: [(dayStart: Date, lbs: Double)] = dayStarts.compactMap { dayStart in
            guard let raw = byDayStart[dayStart]?.rawWeight else { return nil }
            return (dayStart, raw * lbsPerKg)
        }
        let smoothedPoints: [(dayStart: Date, lbs: Double)] = dayStarts.compactMap { dayStart in
            guard let smoothed = byDayStart[dayStart]?.smoothedWeight else { return nil }
            return (dayStart, smoothed * lbsPerKg)
        }
        let predictedPoints: [(dayStart: Date, lbs: Double)] = predictedSeries(
            dayStarts: dayStarts,
            byDayStart: byDayStart,
            rangeStart: rangeStart
        )

        VStack(spacing: 8) {
            Chart {
                // Raw weigh-ins (small dots).
                ForEach(rawPoints, id: \.dayStart) { point in
                    PointMark(
                        x: .value("Date", point.dayStart),
                        y: .value("Weight", point.lbs)
                    )
                    .foregroundStyle(Color.textGhost)
                    .symbolSize(4)
                }

                // Smoothed 7-day average (solid line).
                ForEach(smoothedPoints, id: \.dayStart) { point in
                    LineMark(
                        x: .value("Date", point.dayStart),
                        y: .value("Weight", point.lbs)
                    )
                    .foregroundStyle(Color.accentPurple)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }

                // Predicted trend (dashed).
                if !predictedPoints.isEmpty {
                    ForEach(predictedPoints, id: \.dayStart) { point in
                        LineMark(
                            x: .value("Date", point.dayStart),
                            y: .value("Weight", point.lbs)
                        )
                        .foregroundStyle(Color.accentPurple.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6]))
                    }
                }
            }
            .background(Color.appBackground)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.cardBorder)
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(Font.entryMeta)
                        .foregroundStyle(Color.textDim)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.cardBorder)
                    AxisValueLabel()
                        .font(Font.entryMeta)
                        .foregroundStyle(Color.textDim)
                }
            }
            .chartYScale(domain: weightDomain(from: rawPoints + smoothedPoints + predictedPoints))
            .chartXSelection(value: $selectedDayStart)
            .frame(height: 280)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let selectedDayStart,
                       let lbs = weightForSelectedDay(
                        selectedDayStart: selectedDayStart,
                        byDayStart: byDayStart,
                        rawPoints: rawPoints,
                        smoothedPoints: smoothedPoints
                       )
                    {
                        let x = proxy.position(forX: selectedDayStart) ?? geo.size.width / 2
                        VStack(spacing: 2) {
                            Text(formattedShortDate(selectedDayStart))
                                .font(Font.entryMeta)
                                .foregroundStyle(Color.textPrimary)
                            Text("\(String(format: "%.1f", lbs)) lb")
                                .font(Font.entryMeta.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.cardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.cardBorder, lineWidth: 1)
                                )
                        }
                        .position(x: x, y: 18)
                    }
                }
            }

            WeightSummary(rawPoints: rawPoints, smoothedPoints: smoothedPoints)
        }
    }

    private func lastNDaysRange(n: Int) -> (Date, Date, [Date]) {
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(n - 1), to: end) ?? end
        let days = (0..<n).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
        return (start, end, days)
    }

    private func bestDayLogByDayStart(dayStarts: [Date]) -> [Date: DayLog] {
        var best: [Date: DayLog] = [:]
        for log in dayLogs {
            let dayStart = calendar.startOfDay(for: log.date)
            guard dayStarts.contains(dayStart) else { continue }
            if let existing = best[dayStart] {
                if log.date > existing.date {
                    best[dayStart] = log
                }
            } else {
                best[dayStart] = log
            }
        }
        return best
    }

    private func predictedSeries(
        dayStarts: [Date],
        byDayStart: [Date: DayLog],
        rangeStart: Date
    ) -> [(dayStart: Date, lbs: Double)] {
        guard let profile = appState.userProfile else { return [] }

        let targetCalories: Double = {
            switch profile.goalType {
            case .cut: return profile.tdeeEstimate - 400
            case .bulk: return profile.tdeeEstimate + 300
            case .maintain: return profile.tdeeEstimate
            }
        }()

        // Weight change from a constant daily calorie surplus/deficit (ignoring effort).
        let dailyDeltaKg = (targetCalories - profile.tdeeEstimate) / 7700.0

        // Baseline: first smoothed (fall back to first raw).
        let baselineKg: Double? = {
            for dayStart in dayStarts {
                if let smoothed = byDayStart[dayStart]?.smoothedWeight { return smoothed }
                if let raw = byDayStart[dayStart]?.rawWeight { return raw }
            }
            return nil
        }()

        guard let baselineKg else { return [] }

        return dayStarts.map { dayStart in
            let dayIndex = calendar.dateComponents([.day], from: rangeStart, to: dayStart).day ?? 0
            let predictedKg = baselineKg + (Double(dayIndex) * dailyDeltaKg)
            return (dayStart, predictedKg * lbsPerKg)
        }
    }

    private func weightForSelectedDay(
        selectedDayStart: Date,
        byDayStart: [Date: DayLog],
        rawPoints: [(dayStart: Date, lbs: Double)],
        smoothedPoints: [(dayStart: Date, lbs: Double)]
    ) -> Double? {
        if let smoothed = byDayStart[selectedDayStart]?.smoothedWeight {
            return smoothed * lbsPerKg
        }
        if let raw = byDayStart[selectedDayStart]?.rawWeight {
            return raw * lbsPerKg
        }
        // Fallbacks if the relationship has not been populated yet.
        if let point = smoothedPoints.first(where: { $0.dayStart == selectedDayStart }) { return point.lbs }
        if let point = rawPoints.first(where: { $0.dayStart == selectedDayStart }) { return point.lbs }
        return nil
    }

    private func formattedShortDate(_ dayStart: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: dayStart)
    }

    private func weightDomain(from points: [(dayStart: Date, lbs: Double)]) -> ClosedRange<Double> {
        let values = points.map(\.lbs)
        guard let minVal = values.min(), let maxVal = values.max() else {
            return 100...220
        }
        let padding = Swift.max((maxVal - minVal) * 0.15, 2)
        return (minVal - padding)...(maxVal + padding)
    }
}

private struct WeightSummary: View {
    let rawPoints: [(dayStart: Date, lbs: Double)]
    let smoothedPoints: [(dayStart: Date, lbs: Double)]

    var body: some View {
        let points = smoothedPoints.isEmpty ? rawPoints : smoothedPoints
        if points.count < 2 {
            Text("Keep logging — your trends will appear here.")
                .font(Font.sectionTitle)
                .foregroundStyle(Color.textMuted)
                .padding(.horizontal)
        } else {
            let first = points.first!.lbs
            let last = points.last!.lbs
            let totalDelta = last - first
            let weeklyAvg = totalDelta / Double(Swift.max(1, points.count - 1) / 7)
            HStack {
                VStack(alignment: .leading) {
                    Text("Total change (7-day smoothed)")
                        .font(Font.cardLabel)
                        .foregroundStyle(Color.textMuted)
                    Text("\(String(format: "%.1f", totalDelta)) lb")
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Weekly average")
                        .font(Font.cardLabel)
                        .foregroundStyle(Color.textMuted)
                    Text("\(String(format: "%.2f", weeklyAvg)) lb/week")
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .padding(.horizontal)
        }
    }
}

