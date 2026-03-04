//
//  ContentView.swift
//  NutrAItion
//

import SwiftUI

/// Main tab navigation. Each tab is a placeholder until later phases.
struct ContentView: View {
    var body: some View {
        TabView {
            Text("Coming soon")
                .tabItem { Label("Dashboard", systemImage: "house") }
            Text("Coming soon")
                .tabItem { Label("Food Log", systemImage: "list.bullet") }
            Text("Coming soon")
                .tabItem { Label("Chat", systemImage: "message") }
            Text("Coming soon")
                .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
        }
    }
}

#Preview {
    ContentView()
}
