//
//  TDEEHistoryView.swift
//  NutrAItion
//

import SwiftData
import SwiftUI

struct TDEEHistoryView: View {
    @Query(sort: \TDEEAdjustmentHistory.date, order: .reverse) private var history: [TDEEAdjustmentHistory]

    @State private var selectedPoint: WeeklyTDEEPoint?

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    var body: some View {
        let points = weeklyPoints()
        if points.isEmpty {
            VStack(spacing: 8) {
                Text("No engine history yet")
                    .font(Font.sectionTitle)
                    .foregroundStyle(Color.textMuted)
                Text("Keep logging — the engine will start learning after enough data.")
                    .font(Font.cardLabel)
                    .foregroundStyle(Color.textDim)
            }
            .padding()
        } else {
            VStack(spacing: 14) {
                let maxTdee = points.map(\.tdee).max() ?? 1
                let minHeight: CGFloat = 18
                let maxHeight: CGFloat = 160

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(points) { point in
                        let barHeight = CGFloat(max(0, point.tdee / maxTdee)) * maxHeight
                        VStack(spacing: 6) {
                            Button {
                                selectedPoint = point
                            } label: {
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.accentPurple)
                                        .frame(width: 18, height: max(minHeight, barHeight))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(Color.cardBorder, lineWidth: 1)
                                        )
                                }
                            }
                            .buttonStyle(.plain)

                            Text(deltaText(point.delta))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(deltaColor(point.delta))

                            Text(weekMiniLabel(point.weekStart))
                                .font(Font.badgeText)
                                .foregroundStyle(Color.textDim)
                                .frame(width: 28)
                                .lineLimit(1)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .sheet(item: $selectedPoint) { point in
                VStack(alignment: .leading, spacing: 16) {
                    Text(weekLabel(point.weekStart))
                        .font(Font.screenTitle)
                        .foregroundStyle(Color.textPrimary)
                    Text("Recommended TDEE: \(Int(point.tdee)) cal")
                        .font(Font.sectionTitle)
                        .foregroundStyle(Color.textMuted)

                    Divider()

                    Text(point.reasoning)
                        .font(.body)
                        .foregroundStyle(Color.textDim)

                    Spacer()
                }
                .padding()
                .background(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: .radiusCard)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func weeklyPoints() -> [WeeklyTDEEPoint] {
        // Last ~12 weeks of history (enough to see trend without a huge list).
        guard !history.isEmpty else { return [] }

        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -90, to: end) ?? end

        let filtered = history.filter { $0.date >= start }
        guard !filtered.isEmpty else { return [] }

        // Group by weekStart, take the latest entry per week (based on `date`).
        let grouped: [Date: [TDEEAdjustmentHistory]] = Dictionary(grouping: filtered) { item in
            weekStart(for: item.date)
        }

        let weekly = grouped.compactMap { (weekStart, weekItems) -> (weekStart: Date, tdee: Double, reasoning: String)? in
            guard let latest = weekItems.max(by: { $0.date < $1.date }) else { return nil }
            let confidence = latest.confidence
            let reasoning = latest.reasoning + " (Confidence: \(confidence))"
            return (weekStart, latest.newTDEE, reasoning)
        }
        .sorted { $0.weekStart < $1.weekStart } // oldest -> newest

        guard !weekly.isEmpty else { return [] }

        var result: [WeeklyTDEEPoint] = []
        var prevTdee: Double?
        for item in weekly {
            let delta = prevTdee.map { item.tdee - $0 }
            result.append(
                WeeklyTDEEPoint(
                    id: item.weekStart,
                    weekStart: item.weekStart,
                    tdee: item.tdee,
                    delta: delta,
                    reasoning: item.reasoning
                )
            )
            prevTdee = item.tdee
        }

        return result
    }

    private func weekStart(for date: Date) -> Date {
        // Monday-based weeks.
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        comps.weekday = 2 // Monday
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    private func weekLabel(_ weekStart: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "Week of \(f.string(from: weekStart))"
    }
}

private struct WeeklyTDEEPoint: Identifiable, Equatable {
    let id: Date
    let weekStart: Date
    let tdee: Double
    let delta: Double?
    let reasoning: String
}

private extension TDEEHistoryView {
    func deltaColor(_ delta: Double?) -> Color {
        guard let delta else { return Color.textDim }
        return delta >= 0 ? Color.macroProtein : Color.macroFat
    }

    func deltaText(_ delta: Double?) -> String {
        guard let delta else { return "—" }
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(Int(delta.rounded()))"
    }

    func weekMiniLabel(_ weekStart: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f.string(from: weekStart)
    }
}

