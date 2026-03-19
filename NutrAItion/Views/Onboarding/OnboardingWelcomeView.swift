//
//  OnboardingWelcomeView.swift
//  NutrAItion
//

import SwiftUI

struct OnboardingWelcomeView: View {
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("NutrAItion")
                .font(.largeTitle.weight(.bold))
            Text("Learns your metabolism. Gets smarter every week.")
                .multilineTextAlignment(.center)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button {
                onGetStarted()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    OnboardingWelcomeView(onGetStarted: {})
}

