//
//  ContentView.swift
//  NutrAItion
//

import SwiftData
import SwiftUI

/// Main tab navigation. Each tab is a placeholder until later phases.
struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house") }
            FoodLogView()
                .tabItem { Label("Food Log", systemImage: "list.bullet") }
            ChatLoggerView()
                .tabItem { Label("Chat", systemImage: "message") }
            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
