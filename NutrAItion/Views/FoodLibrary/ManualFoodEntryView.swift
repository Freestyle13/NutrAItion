//
//  ManualFoodEntryView.swift
//  NutrAItion
//

import SwiftUI
import SwiftData

/// Placeholder for Phase 3. Phase 3+ will add full form: name, calories, protein, carbs, fat, meal type, save to SwiftData/CustomFoodLibrary.
struct ManualFoodEntryView: View {
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Add food manually")
                    .font(.headline)
                Text("Full form coming in a later phase.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }
}

#Preview {
    ManualFoodEntryView(onDismiss: {})
}
