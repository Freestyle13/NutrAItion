//
//  OnboardingCompleteView.swift
//  NutrAItion
//

import SwiftUI

struct OnboardingCompleteView: View {
    let tdee: Double
    let targets: MacroTargets

    var onBack: () -> Void
    var onStartTracking: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("All Set")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                Text("Your starting targets: \(Int(targets.calories)) cal · \(Int(targets.protein))g protein · \(Int(targets.carbs))g carbs · \(Int(targets.fat))g fat")
                    .font(.headline)
                    .multilineTextAlignment(.leading)

                Text("Starting TDEE estimate: \(Int(tdee)) calories/day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Spacer()

            Button("Start Tracking") {
                onStartTracking()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .navigationTitle("Ready")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { onBack() }
            }
        }
    }
}

#Preview {
    OnboardingCompleteView(
        tdee: 2500,
        targets: MacroTargets(
            calories: 2500,
            protein: 150,
            carbs: 250,
            fat: 70,
            goalType: .maintain,
            generatedAt: Date()
        ),
        onBack: {},
        onStartTracking: {}
    )
}

