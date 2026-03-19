//
//  MessageBubbleView.swift
//  NutrAItion
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    let index: Int
    @Binding var messages: [ChatMessage]
    @Binding var mealTypeForMessage: MealType
    var onLogExtraction: (Int) -> Void
    var onStartOverExtraction: (Int) -> Void

    @State private var showTimestamp = false

    private var isUser: Bool { message.role == .user }

    private var bubbleAlignment: HorizontalAlignment {
        isUser ? .trailing : .leading
    }

    var body: some View {
        VStack(alignment: bubbleAlignment, spacing: 10) {
            bubble
                .onLongPressGesture {
                    showTimestamp = true
                }

            if showTimestamp {
                Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(Font.entryMeta)
                    .foregroundStyle(Color.textDim)
            }

            if message.role == .assistant,
               let items = message.extractedFoodItems,
               !items.isEmpty {
                FoodConfirmationCard(
                    items: Binding(
                        get: {
                            guard messages.indices.contains(index) else { return [] }
                            return messages[index].extractedFoodItems ?? []
                        },
                        set: { newItems in
                            guard messages.indices.contains(index) else { return }
                            messages[index].extractedFoodItems = newItems.isEmpty ? nil : newItems
                        }
                    ),
                    selectedMealType: $mealTypeForMessage,
                    onLog: { onLogExtraction(index) },
                    onStartOver: { onStartOverExtraction(index) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var bubble: some View {
        let shape = isUser
            ? UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 4,
                topTrailingRadius: 18
            )
            : UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 18,
                topTrailingRadius: 18
            )

        Text(message.content)
            .font(.body)
            .foregroundStyle(isUser ? Color.textPrimary : Color.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isUser ? Color.accentPurple : Color.cardBackground
            )
            .overlay(
                Group {
                    if !isUser {
                        shape.stroke(Color.cardBorder, lineWidth: 1)
                    }
                }
            )
            .clipShape(shape)
    }
}

#Preview {
    struct P: View {
        @State var messages: [ChatMessage] = [
            ChatMessage(role: .user, content: "I had oatmeal"),
            ChatMessage(role: .assistant, content: "Here's what I captured:", extractedFoodItems: [
                ExtractedFoodItem(
                    name: "Oatmeal",
                    estimatedCalories: 150,
                    estimatedProtein: 5,
                    estimatedCarbs: 27,
                    estimatedFat: 3,
                    confidence: "medium",
                    portionDescription: "1 cup cooked"
                ),
            ]),
        ]
        @State var meal = MealType.breakfast
        var body: some View {
            ScrollView {
                MessageBubbleView(
                    message: messages[0],
                    index: 0,
                    messages: $messages,
                    mealTypeForMessage: $meal,
                    onLogExtraction: { _ in },
                    onStartOverExtraction: { _ in }
                )
                MessageBubbleView(
                    message: messages[1],
                    index: 1,
                    messages: $messages,
                    mealTypeForMessage: $meal,
                    onLogExtraction: { _ in },
                    onStartOverExtraction: { _ in }
                )
            }
        }
    }
    return P()
}
