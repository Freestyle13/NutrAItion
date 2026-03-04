//
//  MacroRingView.swift
//  NutrAItion
//

import SwiftUI

struct MacroRingView: View {
    let current: Double
    let target: Double
    let color: Color
    let label: String
    let unit: String
    let isLarge: Bool

    init(
        current: Double,
        target: Double,
        color: Color,
        label: String,
        unit: String = "g",
        isLarge: Bool = false
    ) {
        self.current = current
        self.target = target
        self.color = color
        self.label = label
        self.unit = unit
        self.isLarge = isLarge
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, current / target)
    }

    private var displayValue: String {
        let n = Int(current.rounded())
        if unit.isEmpty { return NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal) }
        return "\(n)\(unit)"
    }

    var body: some View {
        let size: CGFloat = isLarge ? 160 : (label == "Protein" ? 72 : 64)
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: isLarge ? 14 : 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: isLarge ? 14 : 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(displayValue)
                    .font(isLarge ? .title : .subheadline)
                    .fontWeight(.semibold)
            }
            .frame(width: size, height: size)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        MacroRingView(current: 1840, target: 2100, color: .orange, label: "Calories", unit: "", isLarge: true)
        MacroRingView(current: 142, target: 165, color: .blue, label: "Protein")
        MacroRingView(current: 180, target: 210, color: .green, label: "Carbs")
        MacroRingView(current: 52, target: 58, color: .purple, label: "Fat")
    }
    .padding()
}
