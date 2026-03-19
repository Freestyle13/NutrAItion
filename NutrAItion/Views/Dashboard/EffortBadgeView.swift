//
//  EffortBadgeView.swift
//  NutrAItion
//

import SwiftUI

struct EffortBadgeView: View {
    let level: EffortLevel?

    private var color: Color {
        guard let level else { return .gray }
        switch level {
        case .rest: return .effortRest
        case .low: return .effortLow
        case .moderate: return .effortModerate
        case .high: return .effortHigh
        case .veryHigh: return .effortVeryHigh
        }
    }

    private var label: String {
        level?.displayName ?? "—"
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(Font.entryMeta)
                .foregroundStyle(Color.textMuted)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        EffortBadgeView(level: .rest)
        EffortBadgeView(level: .low)
        EffortBadgeView(level: .moderate)
        EffortBadgeView(level: .high)
        EffortBadgeView(level: .veryHigh)
        EffortBadgeView(level: nil)
    }
    .padding()
}
