//
//  MacroRingView.swift
//  NutrAItion
//

import SwiftUI

struct MacroRingView: View {
    let current: Double
    let target: Double
    let strokeColor: Color
    let trackColor: Color
    let label: String
    let unit: String
    let isLarge: Bool
    private let caloriesLabel = "REMAINING"

    @State private var animationProgress: Double = 0

    init(
        current: Double,
        target: Double,
        strokeColor: Color,
        trackColor: Color,
        label: String,
        unit: String = "g",
        isLarge: Bool = false
    ) {
        self.current = current
        self.target = target
        self.strokeColor = strokeColor
        self.trackColor = trackColor
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
        let actualProgress = progress

        let diameter: CGFloat = isLarge ? 180 : (label == "Protein" ? 72 : 64)
        let strokeWidth: CGFloat = isLarge ? 14 : 8
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: strokeWidth)
                Circle()
                    .trim(from: 0, to: animationProgress)
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if isLarge {
                    Text(displayValue)
                        .font(Font.calRingVal)
                        .foregroundStyle(Color.textPrimary)
                } else {
                    Text(displayValue)
                        .font(Font.macroRingVal)
                        .foregroundStyle(Color.textPrimary)
                        .fontWeight(.bold)
                }
            }
            .frame(width: diameter, height: diameter)

            if isLarge {
                VStack(spacing: 2) {
                    Text(caloriesLabel)
                        .font(Font.calRingLabel)
                        .foregroundStyle(Color.textMuted)
                        .textCase(.uppercase)

                    Text("of \(Int(target.rounded())) cal")
                        .font(Font.entryMeta)
                        .foregroundStyle(Color.textDim)
                }
            } else {
                Text(label.uppercased())
                    .font(Font.cardLabel)
                    .foregroundStyle(Color.textMuted)
                    .textCase(.uppercase)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = actualProgress
            }
        }
        .onChange(of: actualProgress) { _, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = newValue
            }
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        MacroRingView(
            current: 1840,
            target: 2100,
            strokeColor: Color.accentPurple,
            trackColor: Color.ringTrack,
            label: "Remaining",
            unit: "",
            isLarge: true
        )
        MacroRingView(current: 142, target: 165, strokeColor: Color.macroCarbs, trackColor: Color(hex: "#1E3830"), label: "Protein")
        MacroRingView(current: 180, target: 210, strokeColor: Color.macroProtein, trackColor: Color(hex: "#382A18"), label: "Carbs")
        MacroRingView(current: 52, target: 58, strokeColor: Color.macroFat, trackColor: Color(hex: "#38182E"), label: "Fat")
    }
    .padding()
}
