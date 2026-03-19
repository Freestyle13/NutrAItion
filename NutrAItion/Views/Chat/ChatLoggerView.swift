//
//  ChatLoggerView.swift
//  NutrAItion
//

import SwiftData
import SwiftUI

struct ChatLoggerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allEntries: [FoodEntry]

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var claude = ClaudeAPIService()
    /// Meal picker for the assistant message at each index (keyed by message id).
    @State private var mealTypeByMessageId: [UUID: MealType] = [:]

    private let calendar = Calendar.current
    private let parser = FoodExtractionParser()

    private var todaysLogged: (cal: Double, protein: Double) {
        let today = allEntries.filter { calendar.isDateInToday($0.timestamp) }
        let cal = today.reduce(0) { $0 + $1.calories }
        let p = today.reduce(0) { $0 + $1.protein }
        return (cal, p)
    }

    private func dayContext() -> DayContext {
        let targets = appState.todaysMacroTargets
        let calTarget = targets?.calories ?? 2000
        let proteinTarget = targets?.protein ?? 150
        let logged = todaysLogged
        return DayContext(
            calorieTarget: calTarget,
            remainingCalories: max(0, calTarget - logged.cal),
            proteinTarget: proteinTarget,
            proteinLogged: logged.protein,
            goalType: appState.userProfile?.goalType ?? .maintain,
            effortLevel: appState.todaysEffortLevel
        )
    }

    private func mealBinding(for messageId: UUID) -> Binding<MealType> {
        Binding(
            get: { mealTypeByMessageId[messageId] ?? .lunch },
            set: { mealTypeByMessageId[messageId] = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if messages.isEmpty {
                                emptyState
                            }
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                                MessageBubbleView(
                                    message: msg,
                                    index: index,
                                    messages: $messages,
                                    mealTypeForMessage: mealBinding(for: msg.id),
                                    onLogExtraction: logExtraction(at:),
                                    onStartOverExtraction: startOverExtraction(at:)
                                )
                                .id(msg.id)
                            }
                            if claude.isLoading {
                                typingIndicator
                                    .id("typing")
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: claude.isLoading) { _, loading in
                        if loading {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }

                inputBar
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("Tell me what you ate, or ask me anything about your nutrition.")
                .font(.body)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 32)

            VStack(alignment: .leading, spacing: 10) {
                quickPrompt("I just had…") {
                    inputText = "I just had "
                }
                quickPrompt("How am I doing today?") {
                    inputText = "How am I doing today?"
                }
                quickPrompt("What should I eat for dinner?") {
                    inputText = "What should I eat for dinner?"
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }

    private func quickPrompt(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Font.entryMeta)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var typingIndicator: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 4,
            bottomTrailingRadius: 18,
            topTrailingRadius: 18
        )

        return TimelineView(.periodic(from: .now, by: 0.12)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = t * 6.0 + Double(i) * 0.6
                    let raw = (sin(phase) + 1.0) / 2.0 // 0...1
                    Circle()
                        .fill(Color.textMuted)
                        .frame(width: 8, height: 8)
                        .opacity(0.35 + raw * 0.65)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.cardBackground)
            .overlay(shape.stroke(Color.cardBorder, lineWidth: 1))
            .clipShape(shape)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }

    private var inputBar: some View {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSend = !trimmed.isEmpty && !claude.isLoading

        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.tabBorder)
                .frame(height: 1)

            HStack(spacing: 12) {
                TextField(
                    "",
                    text: $inputText,
                    prompt: Text("Message…").foregroundStyle(Color.textDim)
                )
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.cardBackground)
                )

                Button {
                    Task { await sendMessage() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? Color.accentPurple : Color.cardBorder)
                            .frame(width: 52, height: 52)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 22, height: 22)
                    }
                }
                .disabled(!canSend)
                .buttonStyle(AccentPressableButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.deepBackground)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.2)) {
                if claude.isLoading {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else if let last = messages.last?.id {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)

        let context = dayContext()
        let extracted = await claude.extractFood(from: text, context: context)

        if !extracted.isEmpty {
            let assistantId = UUID()
            mealTypeByMessageId[assistantId] = .lunch
            messages.append(
                ChatMessage(
                    id: assistantId,
                    role: .assistant,
                    content: "Here's what I captured. Adjust anything if needed, then log.",
                    extractedFoodItems: extracted
                )
            )
            return
        }

        let reply = await claude.chat(
            message: text,
            history: Array(messages.dropLast()),
            context: context
        )
        let body = reply.isEmpty ? (claude.errorMessage ?? "Something went wrong. Try again.") : reply
        messages.append(ChatMessage(role: .assistant, content: body))
    }

    private func logExtraction(at index: Int) {
        guard messages.indices.contains(index),
              let items = messages[index].extractedFoodItems,
              !items.isEmpty else { return }
        let meal = mealTypeByMessageId[messages[index].id] ?? .lunch
        let entries = parser.toFoodEntries(items, mealType: meal)

        guard let profile = appState.userProfile else {
            for entry in entries {
                modelContext.insert(entry)
            }
            try? modelContext.save()
            appState.triggerJustLoggedAnimation()
            return
        }

        let synchronizer = DayLogSynchronizer(
            healthKitManager: appState.healthKitManager,
            calendar: Calendar.current
        )

        for entry in entries {
            modelContext.insert(entry)
            synchronizer.attachFoodEntryToDayLog(entry, modelContext: modelContext, userProfile: profile)
        }
        try? modelContext.save()
        appState.triggerJustLoggedAnimation()
        messages[index].extractedFoodItems = nil
        messages[index].content = "Logged \(entries.count) item(s). What else did you have?"
        mealTypeByMessageId[messages[index].id] = nil
    }

    private func startOverExtraction(at index: Int) {
        guard messages.indices.contains(index) else { return }
        let msg = messages[index]
        mealTypeByMessageId[msg.id] = nil
        guard msg.role == .assistant else { return }
        messages.remove(at: index)
        if index > 0 {
            messages.remove(at: index - 1)
        }
    }
}

#Preview {
    ChatLoggerView()
        .environment(AppState())
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
