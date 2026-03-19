//
//  FoodConfirmationCard.swift
//  NutrAItion
//

import SwiftUI

struct FoodConfirmationCard: View {
    @Binding var items: [ExtractedFoodItem]
    @Binding var selectedMealType: MealType
    var onLog: () -> Void
    var onStartOver: () -> Void

    @State private var editingIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("I found these items")
                .font(Font.sectionTitle)
                .foregroundStyle(Color.textPrimary)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(Font.entryName)
                                .foregroundStyle(Color.textPrimary)
                            if !item.portionDescription.isEmpty {
                                Text(item.portionDescription)
                                    .font(Font.entryMeta)
                                    .foregroundStyle(Color.textDim)
                            }
                            Text(
                                "\(Int(item.estimatedCalories)) cal · P \(Int(item.estimatedProtein))g · C \(Int(item.estimatedCarbs))g · F \(Int(item.estimatedFat))g"
                            )
                            .font(Font.entryMeta)
                            .foregroundStyle(Color.textDim)
                        }
                        Spacer(minLength: 8)
                        Button("Edit") {
                            editingIndex = index
                        }
                        .font(Font.cardLabel)
                        .foregroundStyle(Color.textMuted)
                    }
                }
                .padding(.vertical, 4)
            }

            Picker("Meal", selection: $selectedMealType) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button("Start Over") {
                    onStartOver()
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )

                Button {
                    onLog()
                } label: {
                    Text("Looks Good")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentPurple, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color.textPrimary)
                }
                .buttonStyle(AccentPressableButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: .radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusCard)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .sheet(isPresented: Binding(
            get: { editingIndex != nil },
            set: { if !$0 { editingIndex = nil } }
        )) {
            if let idx = editingIndex, items.indices.contains(idx) {
                EditExtractedItemSheet(
                    items: $items,
                    index: idx,
                    onDismiss: { editingIndex = nil }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct EditExtractedItemSheet: View {
    @Binding var items: [ExtractedFoodItem]
    let index: Int
    var onDismiss: () -> Void

    @State private var name: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var portion: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Portion (e.g. 1 cup)", text: $portion)
                }
                Section("Macros") {
                    TextField("Calories", text: $calories)
                        .keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbs)
                        .keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyEdits()
                        onDismiss()
                    }
                }
            }
            .onAppear {
                let item = items[index]
                name = item.name
                portion = item.portionDescription
                calories = String(format: "%.0f", item.estimatedCalories)
                protein = String(format: "%.1f", item.estimatedProtein)
                carbs = String(format: "%.1f", item.estimatedCarbs)
                fat = String(format: "%.1f", item.estimatedFat)
            }
        }
    }

    private func applyEdits() {
        guard items.indices.contains(index) else { return }
        var item = items[index]
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.portionDescription = portion.trimmingCharacters(in: .whitespacesAndNewlines)
        item.estimatedCalories = Double(calories.replacingOccurrences(of: ",", with: "")) ?? item.estimatedCalories
        item.estimatedProtein = Double(protein.replacingOccurrences(of: ",", with: "")) ?? item.estimatedProtein
        item.estimatedCarbs = Double(carbs.replacingOccurrences(of: ",", with: "")) ?? item.estimatedCarbs
        item.estimatedFat = Double(fat.replacingOccurrences(of: ",", with: "")) ?? item.estimatedFat
        items[index] = item
    }
}

#Preview {
    struct PreviewWrap: View {
        @State var items: [ExtractedFoodItem] = [
            ExtractedFoodItem(
                name: "Greek yogurt",
                estimatedCalories: 130,
                estimatedProtein: 17,
                estimatedCarbs: 6,
                estimatedFat: 5,
                confidence: "medium",
                portionDescription: "1 cup"
            ),
        ]
        @State var meal: MealType = .breakfast
        var body: some View {
            FoodConfirmationCard(
                items: $items,
                selectedMealType: $meal,
                onLog: {},
                onStartOver: {}
            )
            .padding()
        }
    }
    return PreviewWrap()
}
