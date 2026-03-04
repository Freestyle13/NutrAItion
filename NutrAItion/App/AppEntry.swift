//
//  AppEntry.swift
//  NutrAItion
//

import SwiftUI
import SwiftData

@main
struct AppEntry: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodEntry.self,
            DayLog.self,
            UserProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Chooses OnboardingFlow vs ContentView based on onboarding state.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isOnboardingComplete {
                ContentView()
            } else {
                OnboardingFlow()
            }
        }
        .onAppear {
            appState.loadUserProfile(context: modelContext)
            appState.refreshMacroTargets()
        }
    }
}
