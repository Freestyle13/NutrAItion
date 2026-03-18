# DEBUGGING GUIDE
# Common problems and exactly how to fix them.
# Organized by the phase where you'll most likely hit them.
# =========================================================

## HOW TO READ XCODE ERRORS

Xcode errors appear in two places:
1. Red markers on the left side of your code (inline)
2. The Issue Navigator (Cmd+5) — shows ALL errors in one list

Always fix errors from TOP to BOTTOM. One error often causes a
cascade of fake errors below it. Fix the first one and the others
frequently disappear.

The error format is:
[File]:[Line]: error: [description]

Copy the description and paste it into Cursor like:
"Fix this Xcode error in [filename]: [paste error]"

---

## PHASE 1 — SETUP & HEALTHKIT

**Problem: "No such module 'HealthKit'"**
Fix: Go to project target → Signing & Capabilities → + Capability → HealthKit
The entitlement must be explicitly added, it doesn't come automatically.

**Problem: HealthKit permission dialog never appears**
Fix: Check Info.plist has NSHealthShareUsageDescription key.
Without this string, iOS silently suppresses the permission request.
Also check: are you calling requestAuthorization() on the main thread?
Wrap in Task { @MainActor in ... } if needed.

**Problem: HealthKit returns 0.0 for all queries in simulator**
This is expected. The simulator has no real health data.
Fix: Open the Health app in the simulator → Browse → add data manually.
Add some steps, heart rate samples, and a body weight entry.
Alternatively, create a HealthKitMockService that returns test data
when running in simulator (#if targetEnvironment(simulator)).

**Problem: SwiftData "ModelContainer" crash on launch**
Fix: Make sure every @Model class is included in the modelContainer
configuration in AppEntry.swift:
.modelContainer(for: [FoodEntry.self, DayLog.self, UserProfile.self])
Missing a model here causes a crash.

**Problem: "Cannot find type 'X' in scope"**
Fix: The file defining type X either doesn't exist yet or isn't in
the right target. Check the file is added to the app target
(click the file → File Inspector → Target Membership checkbox).

---

## PHASE 2 — ENGINE

**Problem: Unit tests not appearing in Xcode test navigator**
Fix: Test functions MUST start with "test" (lowercase).
func testCalculate() ✅
func calculateTest() ❌
Also: the test file must be in the test target, not the app target.

**Problem: HKQuantitySample creation in tests fails**
Fix: Use HKQuantityType.quantityType(forIdentifier: .heartRate)!
to get the type. In tests, you can't use the real HealthKit store —
create mock samples using HKQuantitySample(type:quantity:start:end:).

**Problem: Engine adjustment seems too aggressive**
Fix: Check that the 0.7x weighting for .estimated entries is applied.
Check that the ±100 calorie cap is enforced.
Print the intermediate values (expectedDelta, actualDelta, errorCal)
to see where the calculation diverges from expectation.

---

## PHASE 3 — NUTRITION LOGGING

**Problem: USDA returns 401 Unauthorized**
Fix: API keys not being sent correctly. Verify:
- Keys are stored in Keychain correctly (test with KeychainManager.load())
- Key is passed as ?api_key= query param (NOT a header)
- Verify key stored in Keychain under Keys.usdaApiKey
- Keys don't have leading/trailing whitespace when saved

**Problem: Open Food Facts returns status 0 (barcode not found)**
This is normal — not every barcode is in their database.
Do NOT dead-end the user — BarcodeResultHandler.state = .notFound
should show an ActionSheet: "Search by name" or "Enter manually".
Never show a plain "not found" with no action path.

**Problem: JSONDecoder fails to parse Open Food Facts nutriments**
OFF uses hyphens in field names like "energy-kcal_100g".
keyDecodingStrategy = .convertFromSnakeCase does NOT handle hyphens.
Fix: use a CodingKeys enum with explicit string keys for the
nutriments struct, e.g. case caloriesPer100g = "energy-kcal_100g".

**Problem: OFF macros look 8-10x too large**
You are reading energy_100g (kilojoules) not energy-kcal_100g (calories).
Always use the field named exactly "energy-kcal_100g".

**Problem: SwiftUI list not updating after saving FoodEntry**
Fix: Make sure you're saving to the modelContext correctly:
modelContext.insert(entry)  ← inserts the object
try? modelContext.save()    ← persists to disk (optional, autosave usually works)
If using @Query in the view, it should update automatically.
If not, check that the @Query predicate isn't filtering out new entries.

**Problem: Barcode scanner sheet dismisses immediately**
Fix: DataScannerViewController needs the camera permission.
Add NSCameraUsageDescription to Info.plist.
Also check that isSupported and isAvailable are both true before
presenting the scanner.

---

## PHASE 4 — AI / CLAUDE API

**Problem: Claude returns JSON wrapped in markdown backticks**
Claude sometimes wraps JSON in ```json ... ``` even when told not to.
Fix: Strip markdown fences before parsing:
let cleaned = response
    .replacingOccurrences(of: "```json", with: "")
    .replacingOccurrences(of: "```", with: "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
This is already in FoodExtractionParser — make sure it's being called.

**Problem: Claude returns text instead of JSON for food extraction**
The model ignored the JSON instruction. Fix the system prompt:
Add: "IMPORTANT: Your entire response must be valid JSON only.
Do not include any text before or after the JSON object."
Also add a concrete example of the exact JSON structure you want.

**Problem: Claude API returns 401**
Fix: API key wrong or not being sent. Check:
- x-api-key header (not "Authorization: Bearer")
- Key loaded from Keychain correctly
- anthropic-version header is present: "2023-06-01"

**Problem: Claude API returns 529 (overloaded)**
This happens occasionally under high API load.
Fix: Add retry logic with exponential backoff — wait 1s, retry,
wait 2s, retry, wait 4s, then give up and show error message.

**Problem: Chat UI not scrolling to bottom on new message**
Fix: Use ScrollViewReader with scrollTo() triggered in .onChange:
ScrollViewReader { proxy in
    ScrollView { ... }
    .onChange(of: messages.count) {
        proxy.scrollTo(messages.last?.id, anchor: .bottom)
    }
}

---

## PHASE 5 — LEARNING ENGINE INTEGRATION

**Problem: Engine never runs (no adjustments happening)**
Check these in order:
1. Is lastRunDate being saved to UserDefaults? Print it.
2. Is the 7-day check passing? Engine only runs if 7+ days since last run.
3. Are DayLogs being created for past days? Query them and print count.
4. Are FoodEntries attached to DayLogs? Check the relationship.
5. Does the user have 28+ days of data? Engine requires this minimum.

**Problem: smoothedWeight is nil on all DayLogs**
Fix: WeightSmoother is not being called, or its output isn't being
saved back to SwiftData. Check DayLogSynchronizer is:
1. Running after HealthKit weight fetch
2. Calling WeightSmoother.smooth()
3. Saving the smoothed values back to each DayLog in SwiftData

**Problem: TDEE adjustment is always 0**
Fix: Either the confidence is .insufficient (print the reasoning string
to see why) or the error signal is too small to produce an adjustment
above the minimum threshold. This is often correct behavior — it means
the current estimate is accurate.

**Problem: TDEE estimate drifts to an unrealistic value**
Fix: The ±100 cal/week cap should prevent this. If it's happening,
check that the cap is being applied after the learning rate multiplication,
not before. Also check that .estimated entries are being weighted at 0.7x.

---

## GENERAL SWIFT / SWIFTUI

**Problem: "Publishing changes from background threads is not allowed"**
Fix: You're updating @State or @Observable properties from a background
thread. Wrap the update in MainActor:
await MainActor.run { self.someProperty = newValue }
Or mark the function @MainActor.

**Problem: Mysterious crash with no error message**
Fix: Add an Exception Breakpoint in Xcode:
Breakpoint Navigator (Cmd+8) → + → Exception Breakpoint → Add
This catches crashes and shows you exactly which line caused them.

**Problem: SwiftUI preview crashes**
Previews are finicky. Common fixes:
- Add #Preview macro with mock data that doesn't need SwiftData
- Use .previewEnvironment to inject mock dependencies
- When all else fails, just delete the preview and test in simulator

**Problem: App works in simulator but crashes on real device**
Usually one of:
- Missing entitlement (HealthKit, camera)
- Missing Info.plist usage description
- Code that assumes simulator behavior (like mock data paths)
- Architecture issue (simulator runs x86_64, device runs arm64)
Check the device logs: Xcode → Window → Devices and Simulators →
select your device → View Device Logs

---

## WHEN TO ASK CURSOR vs GOOGLE vs APPLE DOCS

**Ask Cursor:**
- Fix this specific error: [paste error + code]
- Explain this Swift concept in Java terms
- Write a unit test for this function
- Why is this SwiftUI view not updating?

**Google / Stack Overflow:**
- "HealthKit HKStatisticsQuery example Swift"
- "SwiftData relationship cascade delete"
- Anything where you want multiple human perspectives

**Apple Developer Docs (developer.apple.com/documentation):**
- Exact API signatures and parameters
- What a HealthKit query type actually returns
- SwiftData @Model property wrapper behavior
- Authoritative source — always check here if Cursor and Google disagree

**WWDC Videos (developer.apple.com/videos):**
- "Meet SwiftData" (WWDC 2023) — essential
- "Model your schema with SwiftData" (WWDC 2023) — essential  
- "Explore HealthKit" (any recent year) — for query patterns
- These are 20-30 min each and worth the time for any framework
  you're using heavily


---

## PHASE 3.5 — MANUAL ENTRY & RECIPES

**Problem: AI prefill never appears (form always opens blank)**
Fix: Check ClaudeAPIService.estimateFoodNutrition() is being called.
Add a print statement to verify the Claude response.
Common causes: API key missing from Keychain, or the 2-second timeout
is firing before Claude responds. Increase timeout to 4s for testing.

**Problem: Recipe macros don't match expected values**
Fix: Verify the snapshot is being taken correctly at save time.
Print each RecipeIngredient's calories before and after saving.
Check that totalServings is > 0 (division by zero gives NaN).
The per-serving calculation is: totalCalories / totalServings.
XCTAssertFalse(perServing.calories.isNaN) is a good test to add.

**Problem: Editing a recipe mutates the original instead of creating new**
This is a critical bug — it would corrupt historical food logs.
Fix: In RecipeBuilderView edit mode, make sure you are calling
CustomFoodLibrary.saveRecipe() with a NEW CustomRecipe object
(new UUID, new createdAt), not modifying the existing one.
Never call modelContext.insert on the existing recipe with changed values.

**Problem: Custom foods not appearing in search results**
Fix: Verify CustomFoodLibrary.searchCustomFoods() is being called
alongside FoodDatabaseService.searchFood() and both results are
being merged into the same list. Check the search is case-insensitive:
use .localizedCaseInsensitiveContains() not == for string matching.

**Problem: "Recently Used" not showing on empty search**
Fix: Check CustomFoodLibrary.recentCustomFoods and recentRecipes
are being populated. These require lastUsedAt to be set — verify
logCustomFood() and logRecipe() are updating lastUsedAt = Date()
before saving. If lastUsedAt is nil, the sort will put items at
the bottom not the top.

**Problem: Recipe serving count logs wrong macros**
Example: recipe makes 6 servings, user logs 2, but macros are for 1 serving.
Fix: In CustomFoodLibrary.logRecipe(), the FoodEntry macros should be:
calories = recipe.caloriesPerServing × servingsLogged
Verify servingsLogged is 2.0 not 1.0 at the call site.
Add a unit test: test_logRecipe_twoServings_doublesPerServingMacros()
