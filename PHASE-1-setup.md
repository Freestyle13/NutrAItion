# PHASE 1 — Project Setup & HealthKit Foundation
# Copy these prompts into Cursor one at a time.
# Complete each prompt fully before moving to the next.
# =========================================================

## BEFORE YOU START
- Open Xcode → New Project → iOS App
- Product Name: [your app name]
- Interface: SwiftUI
- Language: Swift
- Storage: SwiftData
- Save to your GitHub repo folder
- Open that folder in Cursor

=========================================================
## PROMPT 1.1 — Core Data Models
=========================================================

Paste this into Cursor chat:

---
Create the core SwiftData data models for a nutrition tracking iOS app. 
Place each model in the Models/ folder.

Create these files:

**Models/FoodEntry.swift**
SwiftData @Model class with:
- id: UUID (default UUID())
- name: String
- calories: Double
- protein: Double
- carbs: Double
- fat: Double
- confidence: Confidence enum (.precise, .manual, or .estimated)
- mealType: MealType enum (.breakfast, .lunch, .dinner, .snack)
- timestamp: Date (default Date())
- notes: String? (optional, for chat-logged context)

**Models/DayLog.swift**
SwiftData @Model class with:
- id: UUID
- date: Date
- effortLevel: EffortLevel enum (.rest, .low, .moderate, .high, .veryHigh)
- rawWeight: Double? (from HealthKit weigh-in, optional)
- smoothedWeight: Double? (7-day rolling average, computed by engine)
- tdeeEstimateAtDate: Double (snapshot of TDEE estimate that day)
- entries relationship to [FoodEntry] with cascade delete rule

**Models/UserProfile.swift**  
SwiftData @Model class (singleton — only one ever exists) with:
- id: UUID
- age: Int
- sex: BiologicalSex enum (.male, .female, .other)
- heightCm: Double
- currentWeightKg: Double
- goalType: GoalType enum (.cut, .bulk, .maintain)
- tdeeEstimate: Double (the adaptive learned value, starts from formula)
- effortMultipliers: dictionary [String: Double] for per-bucket adjustments
- weeklyAdjustmentCount: Int (how many weeks of data the engine has processed)
- leanMassKg: Double? (optional, from DEXA scan — V3 feature)
- createdAt: Date

**Models/MacroTargets.swift**
Simple Swift struct (NOT a SwiftData model — computed on the fly, not persisted):
- calories: Double
- protein: Double
- carbs: Double  
- fat: Double
- goalType: GoalType
- generatedAt: Date

Include a computed var summary: String that returns a readable summary like
"2,100 cal · 165g protein · 210g carbs · 58g fat"

All enums should be defined in their own files in Models/ and conform to
String, CaseIterable, Codable, and have a displayName: String computed property.

For Java context: @Model is like @Entity in JPA. SwiftData handles all the
persistence automatically. No repository classes needed.
---

=========================================================
## PROMPT 1.2 — HealthKit Setup
=========================================================

---
Create the HealthKit integration layer for the iOS nutrition app.
Place files in Services/HealthKit/

**Services/HealthKit/HealthKitPermissions.swift**
A struct with static properties defining all HKQuantityType and HKObjectType
we need to read:
- activeEnergyBurned (read)
- basalEnergyBurned (read)  
- heartRate (read)
- bodyMass (read + write)
- workoutType (read)

Include a static var readTypes: Set<HKSampleType> and writeTypes: Set<HKSampleType>
computed from the above.

**Services/HealthKit/HealthKitManager.swift**
An @Observable class (iOS 17) with:

Properties:
- isAuthorized: Bool
- isAvailable: Bool (checks HKHealthStore.isHealthDataAvailable())

Methods (all async, using withCheckedContinuation to wrap HK callbacks):
- requestAuthorization() async throws
- fetchDailyActiveCalories(for date: Date) async -> Double
- fetchDailyBasalCalories(for date: Date) async -> Double  
- fetchHeartRateSamples(for date: Date) async -> [HKQuantitySample]
- fetchWeightHistory(days: Int) async -> [(date: Date, weightKg: Double)]
- fetchTodayWeight() async -> Double?
- saveWeight(_ weightKg: Double, date: Date) async throws

Error handling: if HealthKit is unavailable or unauthorized, methods should
return sensible defaults (0.0 for calories, empty arrays for samples) with
a print statement — do NOT crash or throw for unavailability.

For Java context: HKHealthStore is like a local database client. 
withCheckedContinuation wraps the callback-based HK queries into 
Swift's async/await — similar to CompletableFuture.completedFuture() 
wrapping a callback in Java.
---

=========================================================
## PROMPT 1.3 — Keychain Manager
=========================================================

---
Create a Keychain utility for secure API key storage.
Place in Utilities/KeychainManager.swift

Create a KeychainManager enum with static methods:

- save(key: String, value: String) -> Bool
- load(key: String) -> String?
- delete(key: String) -> Bool

Use kSecClassGenericPassword with kSecAttrService set to the app bundle ID.
Handle all OSStatus error codes gracefully — return false/nil on failure,
never throw or crash.

Also create a Keys enum nested inside or alongside with static string
constants for all key names we'll use:
- Keys.usdaApiKey = "usda_api_key"
- Keys.anthropicApiKey = "anthropic_api_key"
(No key needed for Open Food Facts — it is fully public)

For Java context: iOS Keychain is the equivalent of Java KeyStore —
hardware-backed secure credential storage. Never store API keys in
UserDefaults (equivalent of Java Properties files) — that's not secure.
---

=========================================================
## PROMPT 1.4 — AppState & Environment Setup
=========================================================

---
Create the app-level state and entry point files.

**App/AppState.swift**
An @Observable class that acts as the app-wide state container
(inject via .environmentObject into the view hierarchy).

Properties:
- userProfile: UserProfile? (loaded from SwiftData on launch)
- healthKitManager: HealthKitManager (singleton instance)
- isOnboardingComplete: Bool (derived from whether userProfile exists)
- todaysMacroTargets: MacroTargets? (computed by engine, cached here)

Methods:
- loadUserProfile(context: ModelContext) 
- refreshMacroTargets() — triggers MacroTargetCalculator

**App/AppEntry.swift** (this is the @main entry point)
Sets up:
- .modelContainer for all SwiftData models
- AppState as an @EnvironmentObject
- Conditional navigation: show OnboardingFlow if !isOnboardingComplete,
  else show ContentView (main tab navigation)

**App/ContentView.swift**
A TabView with 4 tabs:
- Dashboard (house icon)
- Food Log (list icon)  
- Chat (message bubble icon)
- Trends (chart icon)

Each tab shows a placeholder Text("Coming soon") view for now — 
we'll replace these in later phases.
---

=========================================================
## AFTER PHASE 1

Checkpoint before moving on:
✅ Project compiles with no errors
✅ App launches in simulator
✅ TabView shows 4 tabs with placeholder screens
✅ HealthKit permission dialog appears on first launch
✅ No API keys hardcoded anywhere in source

Common issues:
- "HealthKit not available in simulator": normal for some query types,
  add mock data in simulator's Health app
- SwiftData container error: make sure all @Model classes are included
  in the modelContainer configuration in AppEntry.swift
- Missing entitlement: go to project target → Signing & Capabilities
  → + Capability → HealthKit

Next: Phase 2 — Effort Score Engine
