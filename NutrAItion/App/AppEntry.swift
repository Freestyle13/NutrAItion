//
//  AppEntry.swift
//  NutrAItion
//

import Foundation
import UIKit
import SwiftUI
import SwiftData

@main
struct AppEntry: App {
    // TESTFLIGHT CHECKLIST:
    // ☐ All API keys removed from source (using Keychain only)
    // ☐ No hardcoded test data or mock bypasses active
    // ☐ Error messages are user-friendly (no raw error objects shown)
    // ☐ App icon set (required — TestFlight rejects without one)
    // ☐ Privacy manifest file added (Apple requirement as of 2024)
    // ☐ NSHealthShareUsageDescription in Info.plist (required for HealthKit)
    // ☐ NSHealthUpdateUsageDescription in Info.plist (for weight writing)
    // ☐ NSCameraUsageDescription in Info.plist (for barcode scanner)
    // ☐ Minimum iOS version set to 17.0 in project settings
    // ☐ Bundle ID matches App Store Connect app record
    // ☐ Version: 1.0 Build: 1
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodEntry.self,
            DayLog.self,
            UserProfile.self,
            TDEEAdjustmentHistory.self,
            CustomFood.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema changed (e.g. effortMultipliersData → Data)? Delete the app to recreate the store, or we fall back to in-memory so the app still launches.
            #if DEBUG
            print("SwiftData persistent container failed (\(error)); using in-memory store. Delete the app to fix persistent storage.")
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let fallback = try? ModelContainer(for: schema, configurations: [inMemory]) {
                return fallback
            }
            #endif
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                RootView()
                    .environment(appState)
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            let context = ModelContext(sharedModelContainer)
            appState.engineCoordinator.runIfDue(modelContext: context, appState: appState)
        }
    }
}

private extension AppEntry {
    static func uiColor(hex: String) -> UIColor {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        // Background + top separator.
        appearance.backgroundColor = Self.uiColor(hex: "#1A1A32") // deepBackground
        appearance.shadowColor = Self.uiColor(hex: "#2E2E52") // tabBorder
        appearance.shadowImage = UIImage()

        let unselectedText = Self.uiColor(hex: "#484878") // textGhost
        let selectedText = Self.uiColor(hex: "#7B7BE8") // accentPurple

        let unselectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: unselectedText
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: selectedText
        ]

        // Title + icon colors.
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = unselectedAttrs
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        appearance.stackedLayoutAppearance.normal.iconColor = unselectedText
        appearance.stackedLayoutAppearance.selected.iconColor = selectedText

        // iOS may use a different layout depending on device.
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = unselectedAttrs
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        appearance.inlineLayoutAppearance.normal.iconColor = unselectedText
        appearance.inlineLayoutAppearance.selected.iconColor = selectedText

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

/// Chooses OnboardingFlow vs ContentView based on onboarding state.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

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
            if scenePhase == .active {
                appState.engineCoordinator.runIfDue(modelContext: modelContext, appState: appState)
            }
        }
    }
}
