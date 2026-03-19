//
//  OnboardingHealthKitView.swift
//  NutrAItion
//

import SwiftUI

struct OnboardingHealthKitView: View {
    var statusText: String?

    var onBack: () -> Void
    var onConnect: () async -> Void
    var onSkip: () -> Void

    @State private var isConnecting: Bool = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connect Apple Health")
                    .font(.title2.weight(.semibold))

                Text("We use your activity and weight data to estimate effort and update your adaptive calorie targets.")
                    .foregroundStyle(.secondary)

                if let statusText, !statusText.isEmpty {
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 10) {
                    DataTypeRow(title: "Active calories", detail: "Used to compute your effort level each day.")
                    DataTypeRow(title: "Basal calories", detail: "Used as supportive context for daily energy burn.")
                    DataTypeRow(title: "Heart rate", detail: "Used to score workout intensity and effort.")
                    DataTypeRow(title: "Body weight", detail: "Used to calculate your 7-day smoothed weight trend.")
                    DataTypeRow(title: "Workouts", detail: "Helps identify periods of activity for better effort scoring.")
                }
                .padding(.vertical, 4)

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }

                Button {
                    isConnecting = true
                    errorText = nil
                    Task {
                        await onConnect()
                    }
                } label: {
                    if isConnecting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Connect Apple Health")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)

                Button("Skip for now") {
                    onSkip()
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle("HealthKit Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { onBack() }
            }
        }
        .onChange(of: isConnecting) { _, _ in
            // Kept intentionally simple: status is provided by parent via `statusText`.
            // If needed later, we can wire an async error return.
        }
    }
}

private struct DataTypeRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        OnboardingHealthKitView(
            statusText: nil,
            onBack: {},
            onConnect: {},
            onSkip: {}
        )
    }
}

