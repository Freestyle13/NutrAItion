//
//  TrendsView.swift
//  NutrAItion
//

import SwiftData
import SwiftUI

struct TrendsView: View {
    @Environment(AppState.self) private var appState

    @Query(sort: \DayLog.date) private var dayLogs: [DayLog]
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allFoodEntries: [FoodEntry]

    @State private var segment: Segment = .weight

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    enum Segment: String, CaseIterable, Identifiable {
        case weight = "Weight"
        case tdee = "TDEE"
        case macros = "Macros"

        var id: String { rawValue }
    }

    var body: some View {
        let hasEnough = hasAtLeastSevenDaysOfTrendsData()
        NavigationStack {
            if !hasEnough {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.ringTrack.opacity(0.35), lineWidth: 2)
                            .frame(width: 90, height: 90)
                        Circle()
                            .stroke(Color.ringTrack.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .frame(width: 60, height: 60)
                    }

                    Text("Keep logging — your trends will appear here")
                        .font(Font.sectionTitle)
                        .foregroundStyle(Color.textMuted)
                        .multilineTextAlignment(.center)

                    Text("Log weight and foods to enable the engine and show charts.")
                        .font(Font.cardLabel)
                        .foregroundStyle(Color.textDim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Picker("Trends Segment", selection: $segment) {
                        ForEach(Segment.allCases) { seg in
                            Text(seg.rawValue)
                                .tag(seg)
                                .foregroundStyle(segment == seg ? Color.accentPurple : Color.textMuted)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Color.accentPurple)
                    .padding(.horizontal)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: .radiusCard))

                    Group {
                        switch segment {
                        case .weight:
                            WeightChartView()
                        case .tdee:
                            tdeeSegment()
                        case .macros:
                            macrosSegment()
                        }
                    }
                }
                .navigationTitle("Trends")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func tdeeSegment() -> some View {
        let weeksUsed = calculateWeeksUsed()
        return VStack(alignment: .leading, spacing: 12) {
            if let profile = appState.userProfile {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current TDEE estimate")
                        .font(Font.cardLabel)
                        .foregroundStyle(Color.textMuted)
                    Text("\(Int(profile.tdeeEstimate)) cal")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                }

                Text("Weeks of data used: \(weeksUsed)")
                    .font(Font.cardLabel)
                    .foregroundStyle(Color.textDim)
            } else {
                EmptyView()
            }

            TDEEHistoryView()
        }
    }

    private func macrosSegment() -> some View {
        return VStack(spacing: 12) {
            Text("Last 7 days macro breakdown")
                .font(Font.sectionTitle)
                .foregroundStyle(Color.textMuted)
                .padding(.horizontal)

            StackedMacroBars(lastNDays: 7, calendar: calendar, allFoodEntries: allFoodEntries)
                .padding(.horizontal)
        }
    }

    private func hasAtLeastSevenDaysOfTrendsData() -> Bool {
        let last30 = lastNDaysRange(n: 30).days
        let last7 = lastNDaysRange(n: 7).days

        let byDayStart = Dictionary(uniqueKeysWithValues: dayLogs.map { log in
            (calendar.startOfDay(for: log.date), log)
        })

        let weightDays = last30.filter { byDayStart[$0]?.smoothedWeight != nil }.count
        let macroDays = last7.filter { dayStart in
            allFoodEntries.contains { entry in
                calendar.isDate(entry.timestamp, inSameDayAs: dayStart)
            }
        }.count

        return weightDays >= 7 || macroDays >= 7
    }

    private func calculateWeeksUsed() -> Int {
        let last28 = lastNDaysRange(n: 28).days
        let byDayStart = Dictionary(uniqueKeysWithValues: dayLogs.map { log in
            (calendar.startOfDay(for: log.date), log)
        })

        let validDays = last28.filter { dayStart in
            guard let log = byDayStart[dayStart] else { return false }
            return log.smoothedWeight != nil && !log.entries.isEmpty
        }.count

        return max(0, validDays / 7)
    }

    private func lastNDaysRange(n: Int) -> (days: [Date], start: Date, end: Date) {
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(n - 1), to: end) ?? end
        let days = (0..<n).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
        return (days, start, end)
    }
}

private struct StackedMacroBars: View {
    let lastNDays: Int
    let calendar: Calendar
    let allFoodEntries: [FoodEntry]

    private let height: CGFloat = 220
    private let colors: MacroColors = .init(
        protein: .purple.opacity(0.9),
        carbs: .green.opacity(0.9),
        fat: .orange.opacity(0.9)
    )

    struct MacroColors {
        let protein: Color
        let carbs: Color
        let fat: Color
    }

    var body: some View {
        let dayStarts = last7DayStarts()

        let totalsByDay: [Date: MacroTotals] = {
            var dict: [Date: MacroTotals] = [:]
            for entry in allFoodEntries {
                let dayStart = calendar.startOfDay(for: entry.timestamp)
                guard dict.keys.contains(dayStart) || dayStarts.contains(dayStart) else { continue }
                var t = dict[dayStart] ?? MacroTotals(proteinCal: 0, carbsCal: 0, fatCal: 0)
                t.proteinCal += entry.protein * 4
                t.carbsCal += entry.carbs * 4
                t.fatCal += entry.fat * 9
                dict[dayStart] = t
            }
            // Ensure all dayStarts exist.
            for dayStart in dayStarts {
                dict[dayStart] = dict[dayStart] ?? MacroTotals(proteinCal: 0, carbsCal: 0, fatCal: 0)
            }
            return dict
        }()

        let maxTotal = max(
            1,
            dayStarts.map { totalsByDay[$0]?.totalCal ?? 0 }.max() ?? 0
        )

        HStack(alignment: .bottom, spacing: 10) {
            ForEach(dayStarts, id: \.self) { dayStart in
                let totals = totalsByDay[dayStart] ?? MacroTotals(proteinCal: 0, carbsCal: 0, fatCal: 0)
                let total = totals.totalCal
                MacroBar(
                    height: height,
                    total: total,
                    maxTotal: maxTotal,
                    proteinCal: totals.proteinCal,
                    carbsCal: totals.carbsCal,
                    fatCal: totals.fatCal,
                    proteinColor: colors.protein,
                    carbsColor: colors.carbs,
                    fatColor: colors.fat
                )
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(shortDayLabel(dayStart))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(total > 0 ? "\(Int(total))" : "—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func last7DayStarts() -> [Date] {
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(lastNDays - 1), to: end) ?? end
        return (0..<lastNDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    private func shortDayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EE"
        return f.string(from: date)
    }
}

private struct MacroTotals {
    var proteinCal: Double
    var carbsCal: Double
    var fatCal: Double

    var totalCal: Double { proteinCal + carbsCal + fatCal }
}

private struct MacroBar: View {
    let height: CGFloat
    let total: Double
    let maxTotal: Double
    let proteinCal: Double
    let carbsCal: Double
    let fatCal: Double

    let proteinColor: Color
    let carbsColor: Color
    let fatColor: Color

    var body: some View {
        // Outer container sets a consistent chart height; segments fill the bottom proportionally.
        ZStack(alignment: .bottom) {
            let scaledTotalHeight = total <= 0 ? 0 : height * CGFloat(total / maxTotal)
            if total > 0 {
                let fatH = scaledTotalHeight * CGFloat(fatCal / max(total, 0.0001))
                let carbsH = scaledTotalHeight * CGFloat(carbsCal / max(total, 0.0001))
                let proteinH = scaledTotalHeight * CGFloat(proteinCal / max(total, 0.0001))

                VStack(spacing: 0) {
                    Rectangle().fill(fatColor).frame(height: fatH)
                    Rectangle().fill(carbsColor).frame(height: carbsH)
                    Rectangle().fill(proteinColor).frame(height: proteinH)
                }
            }
        }
        .frame(height: height, alignment: .bottom)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

#Preview {
    TrendsView()
        .environment(AppState())
        .modelContainer(for: [DayLog.self, FoodEntry.self], inMemory: true)
}

