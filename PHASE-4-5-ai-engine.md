# PHASE 4 — AI Conversational Logger
# Claude API integration + chat UI
# Complete Phase 3 before starting this.
# =========================================================

=========================================================
## PROMPT 4.1 — Claude API Service
=========================================================

---
Create the Anthropic Claude API integration.
Place in Services/AI/

**Services/AI/ChatMessage.swift**
A Swift struct (Codable) representing a chat message:
- id: UUID
- role: MessageRole enum (.user, .assistant)
- content: String
- timestamp: Date
- extractedFoodItems: [ExtractedFoodItem]? (populated after AI parses food)

Also create ExtractedFoodItem struct:
- name: String
- estimatedCalories: Double
- estimatedProtein: Double
- estimatedCarbs: Double
- estimatedFat: Double
- confidence: String (from Claude, e.g., "medium" — we convert to .estimated)
- portionDescription: String (e.g., "2 slices", "1 cup")

**Services/AI/FoodExtractionParser.swift**
A struct that parses Claude's JSON response into [ExtractedFoodItem].
The JSON Claude returns looks like:
{
  "items": [
    {
      "name": "Domino's pepperoni pizza",
      "estimated_calories": 285,
      "estimated_protein": 12,
      "estimated_carbs": 36,
      "estimated_fat": 10,
      "confidence": "medium",
      "portion_description": "1 slice"
    }
  ]
}

Methods:
- func parse(jsonString: String) throws -> [ExtractedFoodItem]
  Strip any markdown fences (```json ... ```) before parsing.
  Throw a descriptive error if JSON is malformed.

- func toFoodEntries(_ items: [ExtractedFoodItem], mealType: MealType) -> [FoodEntry]
  Convert extracted items to FoodEntry objects with .estimated confidence.

**Services/AI/ClaudeAPIService.swift**
An @Observable class:

Properties:
- isLoading: Bool
- errorMessage: String?

Two public methods:

1. func extractFood(from message: String, context: DayContext) async -> [ExtractedFoodItem]
   
   System prompt for food extraction:
   """
   You are a nutrition assistant. Extract all food items from the user's message.
   Return ONLY a valid JSON object with this exact structure, no other text:
   {
     "items": [
       {
         "name": "food name",
         "estimated_calories": 0,
         "estimated_protein": 0,
         "estimated_carbs": 0,
         "estimated_fat": 0,
         "confidence": "low|medium|high",
         "portion_description": "portion size description"
       }
     ]
   }
   If no food items are mentioned, return {"items": []}.
   Use average restaurant/home cooking portions if size is not specified.
   """
   
   Returns empty array on any error (never throws to the caller).

2. func chat(message: String, history: [ChatMessage], context: DayContext) async -> String
   
   System prompt for general chat includes DayContext:
   """
   You are a personalized nutrition coach. Here is the user's current data:
   - Daily calorie target: \(context.calorieTarget) cal
   - Remaining today: \(context.remainingCalories) cal  
   - Protein target: \(context.proteinTarget)g (logged: \(context.proteinLogged)g)
   - Goal: \(context.goalType)
   - Today's effort level: \(context.effortLevel)
   Answer nutrition questions based on this context. Be concise and practical.
   """

Also create a DayContext struct to pass current day data into both methods.

Use URLSession for the API call. Endpoint: POST https://api.anthropic.com/v1/messages
Headers: Content-Type: application/json, x-api-key: [from Keychain], anthropic-version: 2023-06-01
Model: claude-sonnet-4-6
max_tokens: 1000 for food extraction, 2000 for chat.
---

=========================================================
## PROMPT 4.2 — Chat Logger UI
=========================================================

---
Create the conversational food logger and AI trainer chat interface.
Place in Views/Chat/

**Views/Chat/FoodConfirmationCard.swift**
A card view shown after Claude extracts food items, asking user to confirm:
- Title: "I found these items — does this look right?"
- List of extracted items with name, portion, and estimated macros
- Each item has an edit button (tap to adjust calories/macros manually)
- Meal type picker
- Two buttons: "Looks Good — Log It" and "Start Over"
- Subtle .estimated confidence badge to be transparent about AI estimation

**Views/Chat/MessageBubbleView.swift**
A single chat message bubble:
- User messages: right-aligned, filled background (brand color)
- Assistant messages: left-aligned, light gray background
- Timestamp shown on long press
- If message has extractedFoodItems, show FoodConfirmationCard inline below the bubble

**Views/Chat/ChatLoggerView.swift**
The main chat view:
- ScrollView of MessageBubbleView items, auto-scrolls to bottom on new message
- Sticky input bar at bottom: TextField + Send button
- Typing indicator (animated dots) while waiting for Claude response
- Two-mode behavior:
  Mode 1 (Food Logging): If message seems to contain food (heuristic: check for 
  food keywords OR just always try extraction first), call extractFood() and show
  FoodConfirmationCard. 
  Mode 2 (General Chat): If extraction returns empty items, fall back to chat() 
  for a conversational response.
- Empty state: "Tell me what you ate, or ask me anything about your nutrition."
- Suggested quick prompts shown when empty:
  "I just had..." / "How am I doing today?" / "What should I eat for dinner?"

The view needs access to:
- @EnvironmentObject appState (for DayContext)
- @Environment(\.modelContext) for saving FoodEntries to SwiftData
- ClaudeAPIService instance

For Java context: The async/await pattern here is like CompletableFuture chaining.
When send is tapped, you call await clauService.extractFood(), then update
@State with the result, which triggers SwiftUI to re-render. No manual
notifyDataSetChanged() equivalent needed.
---

=========================================================
## CHECKPOINT — TESTFLIGHT BETA

After Phase 4, you have a working app worth testing on yourself.
Before Phase 5 (the learning engine), dogfood it for 1-2 weeks.

Things to verify with real usage:
- Does food extraction work accurately for your typical meals?
- Is the barcode scanner fast enough on real device?
- Does the dashboard update correctly after logging?
- Any crashes? Check Xcode → Window → Devices and Simulators → View Logs

To install on your own iPhone (free Apple Developer account works):
1. Connect iPhone to Mac mini via USB
2. In Xcode: select your iPhone as the run destination
3. Hit Run — Xcode will ask you to trust the developer on the phone
4. The app installs directly. No TestFlight needed for personal testing.

=========================================================



# PHASE 5 — Adaptive Learning Engine
# The core differentiator — builds the TDEE model over time
# Complete Phase 4 and 1-2 weeks of real usage before starting this.
# =========================================================

=========================================================
## PROMPT 5.1 — Adaptive TDEE Engine
=========================================================

---
Create the AdaptiveTDEEEngine in Engine/AdaptiveTDEEEngine.swift

This is the most important class in the app. It is a pure struct —
all data passed in as parameters, no external calls.

Create a TDEEAdjustment struct to represent the engine's output:
- recommendedTDEE: Double (new estimate to save)
- previousTDEE: Double
- delta: Double (change in calories)
- confidence: EngineConfidence enum (.insufficient, .low, .medium, .high)
- reasoning: String (human-readable explanation for the trends view)
- dataPointsUsed: Int
- weeksCovered: Int

Create AdaptiveTDEEEngine struct with:

**Primary method:**
func analyze(
    dayLogs: [DayLog],           // All available day logs
    currentTDEE: Double,         // Current TDEE estimate to adjust from
    effortMultipliers: [String: Double]  // Current per-bucket multipliers
) -> TDEEAdjustment

**Algorithm implementation:**

Step 1 — Data validation
- Filter to days with smoothedWeight not nil
- Filter to days with at least one food entry
- If fewer than 28 days of valid data → return .insufficient confidence, no change
- If valid data coverage < 70% → return .low confidence, small adjustment only

Step 2 — Select trailing window
- Use the most recent 14 days (2 weeks) with valid data
- This is the analysis window

Step 3 — Calculate average daily intake
- Sum all FoodEntry calories in the window
- Weight .precise entries at 1.0, .estimated entries at 0.7
- Divide by number of days to get weightedAverageIntake

Step 4 — Calculate average effort adjustment
- For each day, get effortLevel → look up calorie adjustment using multipliers
- Average across the window

Step 5 — Calculate predicted weight change
- expectedDailyBalance = weightedAverageIntake - (currentTDEE + avgEffortAdj)
- expectedTotalWeightChangeKg = (expectedDailyBalance × windowDays) / 7700

Step 6 — Calculate actual weight change
- actualWeightChangeKg = smoothedWeight at window end - smoothedWeight at window start
- If change > 3kg in 14 days → flag as likely data anomaly, skip adjustment

Step 7 — Calculate error signal
- errorKg = actualWeightChangeKg - expectedTotalWeightChangeKg
- Convert to calories: errorCal = errorKg × 7700 / windowDays

Step 8 — Compute TDEE adjustment
- rawAdjustment = errorCal × 0.15  (learning rate — conservative)
- clampedAdjustment = max(-100, min(100, rawAdjustment))  (hard cap)
- newTDEE = currentTDEE + clampedAdjustment

Step 9 — Determine confidence
- .high: 28+ days, >85% coverage, weight change <1.5kg in 14 days
- .medium: 14-28 days, 70-85% coverage
- .low: 14-28 days, <70% coverage (apply only 50% of adjustment)
- .insufficient: <14 days (no adjustment)

Step 10 — Generate reasoning string
- E.g., "Your weight dropped 0.8kg but we predicted 1.1kg. Your actual 
  maintenance appears to be about 85 calories higher than estimated."

Write unit tests in EngineTests/AdaptiveTDEEEngineTests.swift:
1. test_analyze_insufficientData_returnsNoChange()
2. test_analyze_weightLossSlowerThanExpected_increasesTDEE()
3. test_analyze_weightLossMatchesPrediction_minimalAdjustment()
4. test_analyze_anomalousWeightChange_skipsAdjustment()
5. test_analyze_adjustmentCappedAt100Calories()
6. test_analyze_estimatedEntriesWeightedCorrectly()
---

=========================================================
## PROMPT 5.2 — Engine Integration & Weekly Trigger
=========================================================

---
Integrate the learning engine into the app and set up the weekly run trigger.

**App/EngineCoordinator.swift**
An @Observable class that orchestrates the engine run:

- Triggered on app foreground (use ScenePhase in AppEntry)
- Checks if 7+ days have passed since last engine run (store lastRunDate in UserDefaults)
- If due, fetches all DayLog data from SwiftData
- Calls AdaptiveTDEEEngine.analyze()
- If result has confidence > .insufficient:
  - Updates UserProfile.tdeeEstimate in SwiftData
  - Saves adjustment to a new TDEEAdjustmentHistory @Model entry
  - Recalculates MacroTargets via MacroTargetCalculator
  - Sends a local notification: "Your macro targets were updated based on your progress"
- Logs result regardless for the trends view

Also update AppState to hold the EngineCoordinator and trigger it on scene activation.

**Models/TDEEAdjustmentHistory.swift** (new SwiftData model)
- id: UUID
- date: Date
- previousTDEE: Double
- newTDEE: Double
- delta: Double
- confidence: String (stored as string for Codable compatibility)
- reasoning: String

This history is what populates the Trends view so users can see the engine
working over time — critical for building trust in the system.
---

=========================================================
## PROMPT 5.3 — DayLog Population
=========================================================

---
Create a service that populates DayLog records daily by pulling from HealthKit.
Place in Services/HealthKit/DayLogSynchronizer.swift

This runs once per day (check lastSyncDate in UserDefaults).

For each day in the last 30 days that doesn't have a DayLog:
1. Fetch active calories from HealthKit for that date
2. Fetch heart rate samples for that date
3. Compute EffortLevel using EffortScoreCalculator
4. Fetch weight entry from HealthKit for that date
5. Create or update DayLog with effortLevel and rawWeight
6. Run WeightSmoother over the full weight history to update smoothedWeight
   on all DayLogs

Call DayLogSynchronizer from EngineCoordinator before running the engine
so the engine always has up-to-date DayLog data.

Also update DayLog population when the user logs food:
When a FoodEntry is saved, find or create the DayLog for that date and
add the entry to its entries relationship.
---

=========================================================
## AFTER PHASE 5

Checkpoint:
✅ Engine runs automatically after 7+ days of data
✅ TDEE estimate visible in Settings screen
✅ Macro targets update after engine runs
✅ TDEEAdjustmentHistory records are being saved
✅ All engine tests still passing

This is the hardest phase. If the numbers feel wrong after 2-4 weeks,
debug by checking:
- Are DayLogs being populated with correct effortLevel?
- Are FoodEntry relationships correctly attached to DayLogs?
- Is smoothedWeight being computed and stored?
- Print the TDEEAdjustment reasoning string to see what the engine thinks

Next: Phase 6 — Trends View, Onboarding, Settings & TestFlight
