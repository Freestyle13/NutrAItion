//
//  OnboardingGoalView.swift
//  NutrAItion
//

import SwiftUI

struct OnboardingGoalView: View {
    let selectedGoal: GoalType
    var onPickGoal: (GoalType) -> Void

    var onBack: () -> Void
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("What are you aiming for?")
                .font(.headline)
                .padding(.top, 12)

            GoalCard(
                goal: .cut,
                isSelected: selectedGoal == .cut,
                title: "Lose Fat",
                subtitle: "Small calorie deficit to lose weight steadily."
            ) {
                onPickGoal(.cut)
            }

            GoalCard(
                goal: .bulk,
                isSelected: selectedGoal == .bulk,
                title: "Build Muscle",
                subtitle: "Lean-bulk calories with conservative surplus."
            ) {
                onPickGoal(.bulk)
            }

            GoalCard(
                goal: .maintain,
                isSelected: selectedGoal == .maintain,
                title: "Maintain",
                subtitle: "Eat at your estimated maintenance."
            ) {
                onPickGoal(.maintain)
            }

            Spacer()

            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 12)
        }
        .padding(.horizontal)
        .navigationTitle("Your Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { onBack() }
            }
        }
    }
}

private struct GoalCard: View {
    let goal: GoalType
    let isSelected: Bool
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingGoalView(
        selectedGoal: .cut,
        onPickGoal: { _ in },
        onBack: {},
        onContinue: {}
    )
}

