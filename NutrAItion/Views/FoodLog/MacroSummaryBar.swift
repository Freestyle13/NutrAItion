//
//  MacroSummaryBar.swift
//  NutrAItion
//

import SwiftUI

struct MacroSummaryBar: View {
    let loggedCalories: Double
    let loggedProtein: Double
    let loggedCarbs: Double
    let loggedFat: Double
    let targetCalories: Double
    let targetProtein: Double
    let targetCarbs: Double
    let targetFat: Double
    let justLogged: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                macroColumn(
                    label: "CAL",
                    value: Int(loggedCalories.rounded()),
                    target: Int(targetCalories.rounded()),
                    color: Color.accentPurple,
                    sublabel: "of \(Int(targetCalories.rounded())) cal"
                )

                macroColumn(
                    label: "P",
                    value: Int(loggedProtein.rounded()),
                    target: Int(targetProtein.rounded()),
                    color: Color.macroProtein,
                    sublabel: "of \(Int(targetProtein.rounded()))g"
                )

                macroColumn(
                    label: "C",
                    value: Int(loggedCarbs.rounded()),
                    target: Int(targetCarbs.rounded()),
                    color: Color.macroCarbs,
                    sublabel: "of \(Int(targetCarbs.rounded()))g"
                )

                macroColumn(
                    label: "F",
                    value: Int(loggedFat.rounded()),
                    target: Int(targetFat.rounded()),
                    color: Color.macroFat,
                    sublabel: "of \(Int(targetFat.rounded()))g"
                )
            }

            VStack(spacing: 6) {
                FractionBar(
                    progress: ratio(logged: loggedCalories, target: targetCalories),
                    fillColor: Color.accentPurple
                )

                HStack(spacing: 8) {
                    FractionBar(
                        progress: ratio(logged: loggedProtein, target: targetProtein),
                        fillColor: Color.macroProtein
                    )
                    FractionBar(
                        progress: ratio(logged: loggedCarbs, target: targetCarbs),
                        fillColor: Color.macroCarbs
                    )
                    FractionBar(
                        progress: ratio(logged: loggedFat, target: targetFat),
                        fillColor: Color.macroFat
                    )
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: .radiusCard)
                .fill(Color.cardBackground)
        )
        .scaleEffect(justLogged ? 1.04 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: justLogged)
        .overlay(
            RoundedRectangle(cornerRadius: .radiusCard)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }

    private func macroColumn(label: String, value: Int, target: Int, color: Color, sublabel: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Font.cardLabel)
                .foregroundStyle(Color.textMuted)
                .textCase(.uppercase)

            Text("\(value)")
                .font(Font.cardValue)
                .foregroundStyle(color)

            Text(sublabel)
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Color.textDim)
        }
        .frame(maxWidth: .infinity)
    }

    private func ratio(logged: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(1, max(0, logged / target))
    }
}

private struct FractionBar: View {
    let progress: Double
    let fillColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.ringTrack)
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(fillColor)
                    .frame(width: proxy.size.width * progress, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 6)
        .clipped()
    }
}

#Preview {
    MacroSummaryBar(
        loggedCalories: 1200,
        loggedProtein: 80,
        loggedCarbs: 100,
        loggedFat: 40,
        targetCalories: 2100,
        targetProtein: 165,
        targetCarbs: 210,
        targetFat: 58,
        justLogged: false
    )
    .padding()
}
