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
        case .rest: return .gray
        case .low: return .blue
        case .moderate: return .green
        case .high: return .orange
        case .veryHigh: return .red
        }
    }

    private var icon: String {
        guard let level else { return "minus" }
        switch level {
        case .rest: return "bed.double.fill"
        case .low: return "figure.walk"
        case .moderate: return "flame"
        case .high: return "flame.fill"
        case .veryHigh: return "flame.circle.fill"
        }
    }

    private var label: String {
        level?.displayName ?? "—"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color, in: Capsule())
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
