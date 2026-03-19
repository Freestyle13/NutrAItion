//
//  OnboardingProfileView.swift
//  NutrAItion
//

import SwiftUI

struct OnboardingProfileView: View {
    @Binding var age: Int
    @Binding var sex: BiologicalSex
    @Binding var weightLbs: Double
    @Binding var heightFeet: Int
    @Binding var heightInches: Double

    var onBack: () -> Void
    var onContinue: () -> Void

    private var canContinue: Bool {
        age >= 10
            && weightLbs >= 60
            && weightLbs <= 400
            && heightFeet >= 3
            && heightFeet <= 7
            && heightInches >= 0
            && heightInches <= 11.5
    }

    var body: some View {
        Form {
            Section {
                Stepper("Age: \(age)", value: $age, in: 10...100, step: 1)
            }

            Section("Biological Sex") {
                Picker("Sex", selection: $sex) {
                    ForEach(BiologicalSex.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Current Weight") {
                TextField("Weight (lbs)", value: $weightLbs, format: .number)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
            }

            Section("Height") {
                HStack {
                    TextField("Feet", value: $heightFeet, format: .number)
                        .keyboardType(.numberPad)
                    Text("ft")
                    TextField("Inches", value: $heightInches, format: .number)
                        .keyboardType(.decimalPad)
                    Text("in")
                }
            }

            Section {
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
            }
        }
        .navigationTitle("About You")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { onBack() }
                    .disabled(false)
            }
        }
    }
}

#Preview {
    OnboardingProfileView(
        age: .constant(30),
        sex: .constant(.other),
        weightLbs: .constant(150),
        heightFeet: .constant(5),
        heightInches: .constant(8),
        onBack: {},
        onContinue: {}
    )
}

