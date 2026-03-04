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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            macroLine(label: "Cal", logged: loggedCalories, target: targetCalories, unit: "")
            macroLine(label: "P", logged: loggedProtein, target: targetProtein, unit: "g")
            macroLine(label: "C", logged: loggedCarbs, target: targetCarbs, unit: "g")
            macroLine(label: "F", logged: loggedFat, target: targetFat, unit: "g")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.bar, in: RoundedRectangle(cornerRadius: 10))
    }

    private func macroLine(label: String, logged: Double, target: Double, unit: String) -> some View {
        let t = Int(target.rounded())
        let l = Int(logged.rounded())
        return HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
            Text("\(l)/\(t)\(unit)")
                .font(.caption)
        }
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
        targetFat: 58
    )
    .padding()
}
