# PHASE 3 — Nutrition Logging (Barcode + Search)
# Open Food Facts (barcode) + USDA FoodData Central (search)
# Replaces Nutritionix which discontinued free/personal access.
# Complete Phase 2 before starting this.
# =========================================================

# APIs USED IN THIS PHASE

## Open Food Facts — Barcode Lookup
- Base URL: https://world.openfoodfacts.org/api/v2
- Auth: NONE — completely free, no account, no API key needed
- Barcode endpoint: GET /product/{upc}.json
- Returns: product name, brand, nutriments object with macros per 100g
- Coverage: 4+ million products worldwide, crowd-sourced
- Limitation: macro data may be missing on some entries — always handle gracefully

## USDA FoodData Central — Text Search
- Base URL: https://api.nal.usda.gov/fdc/v1
- Auth: free API key from api.nal.usda.gov (add to Keychain as "usda_api_key")
- Search endpoint: GET /foods/search?query={q}&pageSize=20&api_key={key}
- Detail endpoint: GET /food/{fdcId}?api_key={key}
- Returns: verified nutritional data, branded + generic foods, restaurant items
- Limitation: serving size data can be inconsistent — normalize carefully

=========================================================
## PROMPT 3.1 — FoodResult Model & Service Layer
=========================================================

---
Create the food database service layer.
Place in Services/Nutrition/

**Services/Nutrition/FoodResult.swift**
A unified Swift struct that normalizes food data from BOTH
Open Food Facts AND USDA into one consistent format:

struct FoodResult {
  var id: String               // OFF barcode OR USDA fdcId as string
  var source: FoodSource       // enum: .openFoodFacts, .usda, .ai
  var foodName: String
  var brandName: String?
  var servingQty: Double       // default 100 if not specified
  var servingUnit: String      // default "g" if not specified
  var caloriesPer100g: Double? // stored for recalculation at custom serving sizes
  var calories: Double         // per serving
  var protein: Double          // per serving grams
  var carbs: Double            // per serving grams
  var fat: Double              // per serving grams
  var imageURL: URL?
  var hasMissingMacros: Bool   // true if Claude had to fill gaps

  func scaled(to grams: Double) -> FoodResult  // recalculate per custom serving
}

FoodDatabaseError enum:
  .notFound        // barcode not in OFF database
  .missingMacros   // product found but macro data incomplete (not thrown — handled gracefully)
  .networkError(String)
  .unauthorized    // USDA key invalid

FoodSource enum: .openFoodFacts, .usda, .ai, .custom

**Services/Nutrition/OpenFoodFactsService.swift**
@Observable class for barcode lookups.

func lookupBarcode(_ upc: String) async throws -> FoodResult?

Implementation:
  1. GET https://world.openfoodfacts.org/api/v2/product/{upc}.json
  2. Check response.status == 1 (found) — return nil if 0 (not found)
  3. Parse product.nutriments:
     energy-kcal_100g → calories per 100g  (NOT energy_100g which is kJ)
     proteins_100g    → protein per 100g
     carbohydrates_100g → carbs per 100g
     fat_100g         → fat per 100g
  4. Parse serving_size field if present (e.g. "30g") for default serving
     If absent, default to 100g serving
  5. If any macro field is nil/missing: set hasMissingMacros = true
     Return the partial result — do NOT throw. Caller will use Claude to fill gaps.
  6. Return nil for 404 or status 0 — not an error, just not found

CRITICAL: Open Food Facts nutrition data is per 100g.
Always convert to per-serving: value = (per100g / 100) * servingGrams

**Services/Nutrition/USDAService.swift**
@Observable class for text search.

func searchFood(_ query: String) async throws -> [FoodResult]
func getFoodDetail(fdcId: Int) async throws -> FoodResult

searchFood implementation:
  1. Load USDA key from KeychainManager using Keys.usdaApiKey
  2. GET /foods/search?query={query}&pageSize=20
     &dataType=Branded,Survey(FNDDS)&api_key={key}
  3. Map response.foods[] to [FoodResult]
  4. Find nutrients by nutrientId within each food's foodNutrients array:
     1008 = Energy (kcal) → calories
     1003 = Protein (g)   → protein
     1005 = Carbohydrate  → carbs
     1004 = Total Fat (g) → fat
  5. Use foodMeasures[0] for serving size if available
     Otherwise default to 100g
  6. Filter out results where calories == 0 (bad data guard)

getFoodDetail: same nutrient parsing, single food by fdcId.
Used when user taps a search result to get full serving size options.

**Services/Nutrition/FoodDatabaseService.swift**
Facade @Observable class combining both services + Claude fallback.

var recentSearches: [String]  // last 5 queries, UserDefaults

func searchFood(_ query: String) async throws -> [FoodResult]
  → Calls USDAService.searchFood()

func lookupBarcode(_ upc: String) async -> FoodResult?
  → Calls OpenFoodFactsService.lookupBarcode()
  → If result.hasMissingMacros: calls ClaudeAPIService.estimateMacros(for: result)
  → Returns complete result (with .ai source on filled fields) or nil

func estimateMacros(for partial: FoodResult) async -> FoodResult
  → Passes product name + partial data to Claude
  → Claude fills missing macro fields
  → Sets hasMissingMacros = false, marks filled fields with .ai source
  → Resulting FoodEntry confidence: .estimated (Claude filled gaps)

Add Keys.usdaApiKey = "usda_api_key" to KeychainManager Keys enum.

For Java context: This facade pattern is identical to Java — USDAService
and OpenFoodFactsService are injected dependencies, FoodDatabaseService
orchestrates them. The @Observable wrapper is like Spring's @Service
with reactive property change notifications built in.
---

=========================================================
## PROMPT 3.2 — Barcode Scanner View
=========================================================

---
Create the barcode scanner.
Place in Views/FoodLog/BarcodeScannerView.swift

Use DataScannerViewController (iOS 16+) wrapped in UIViewControllerRepresentable.

The view is dumb — it only detects barcodes and reports them via callback.
All API calls happen in the caller (BarcodeResultHandler).

Scan targets: .ean8, .ean13, .upce, .code128
Config: qualityLevel = .accurate, isHighlightingEnabled = true

UI: full-screen camera, dark corner vignette overlay, bright center
scan rectangle, X cancel button top right.

Simulator fallback (#if targetEnvironment(simulator)):
Show a TextField + "Look Up" button so UPCs can be typed manually.
Test UPC: 0049000028911 (Coca-Cola 12oz can)

onBarcodeDetected(_ upc: String) callback — called once per scan,
then scanning pauses until the result is handled.
---

=========================================================
## PROMPT 3.3 — Barcode Result Handler
=========================================================

---
Create the post-scan flow handler.
Place in Views/FoodLog/BarcodeResultHandler.swift

@Observable class BarcodeResultHandler:

enum ScanState {
  case idle
  case loading
  case found(FoodResult)           // complete macros
  case foundPartial(FoodResult)    // Claude filled some gaps
  case notFound                    // not in OFF database
  case error(String)
}

var state: ScanState = .idle

func handleBarcode(_ upc: String) async:
  1. state = .loading
  2. result = await FoodDatabaseService.lookupBarcode(upc)
  3. if let result, !result.hasMissingMacros → state = .found(result)
  4. if let result, result.hasMissingMacros → state = .foundPartial(result)
  5. if nil → state = .notFound
  6. on throw → state = .error(message)

In the parent view, observe state and react:
  .found / .foundPartial  → present ServingSizePickerView as sheet
    .foundPartial shows a banner: "Some values were AI-estimated — adjust if needed"
    FoodEntry created with .estimated confidence (not .precise)
  .notFound → present ActionSheet:
    "Search by name" → open FoodSearchView
    "Enter manually" → open ManualFoodEntryView
    NEVER show a dead-end error with no action
  .error → show toast + offer manual entry fallback
---

=========================================================
## PROMPT 3.4 — Food Search Views
=========================================================

---
Create food search UI powered by USDA.
Place in Views/FoodLog/

**Views/FoodLog/FoodSearchView.swift**
Accepts mode: SearchMode (.logging or .ingredientPicker)

Search bar with 0.4s debounce → calls FoodDatabaseService.searchFood()

Results when query is non-empty — three sections:
  1. "My Recipes" — CustomFoodLibrary.searchRecipes(query)
  2. "My Foods" — CustomFoodLibrary.searchCustomFoods(query)
  3. "Food Database" — USDA results

Results when query is empty — Recently Used:
  Last 5 custom foods + last 3 recipes (sorted by lastUsedAt)
  This makes meal prep re-logging extremely fast

Always at bottom of any state:
  "+ Add food manually" → ManualFoodEntryView
  "+ Build a recipe" → RecipeBuilderView

Loading: ProgressView while USDA call in-flight
Empty results: "No results — add it manually" button
Error: "Couldn't reach food database" + manual entry button

When user taps a USDA result:
  Call USDAService.getFoodDetail(fdcId:) to load full serving options
  Show ProgressView during this call
  Then present ServingSizePickerView

**Views/FoodLog/FoodResultRow.swift**
Row showing: food name (bold), brand (gray), source badge (USDA/Custom/Recipe), calories right-aligned.

**Views/FoodLog/ServingSizePickerView.swift**
Bottom sheet:
  Food name title
  Macro breakdown (updates live as serving changes)
  Serving quantity stepper (0.5 increments)
  Serving unit selector (from USDA foodMeasures, or "g"/"oz"/"piece" fallback)
  Meal type picker
  "Log This Food" or "Add to Recipe" button depending on mode

.logging mode → create FoodEntry, save to SwiftData, dismiss
.ingredientPicker mode → call onIngredientSelected(RecipeIngredientDraft), dismiss
---

=========================================================
## PROMPT 3.5 — Food Log View & Basic Dashboard
=========================================================

---
Create the food log and dashboard views.
Place in Views/FoodLog/ and Views/Dashboard/

**Views/FoodLog/FoodLogView.swift**
Main log screen:
  Today's date header
  MacroSummaryBar: logged vs target for cal/protein/carbs/fat
  List grouped by MealType (.breakfast, .lunch, .dinner, .snack)
  Each row: name, subtle .estimated badge if applicable, macros
  Swipe left to delete
  FAB (+) → ActionSheet:
    "Scan Barcode"
    "Search Foods"
    "Tell AI" (Phase 4 — show as disabled/coming soon for now)
    "My Recipes"

**Views/Dashboard/MacroRingView.swift**
Circular arc progress ring.
Params: current, target, color, label.
Protein ring 15% larger than carb/fat rings.

**Views/Dashboard/EffortBadgeView.swift**
Pill badge: rest=gray, low=blue, moderate=green, high=orange, veryHigh=red

**Views/Dashboard/DashboardView.swift**
Glanceable home — answers "how am I doing?" in under 3 seconds:
  Greeting + date
  Large calorie ring (remaining calories most prominent)
  Row of 3 smaller rings: Protein, Carbs, Fat
  EffortBadge
  Weight from HealthKit if available
  Quick-add button (same 4 options)
  Last 3 food entries + "See All"
---

=========================================================
## AFTER PHASE 3

Checkpoints:
✅ OFF barcode lookup works — test UPC 0049000028911 (Coca-Cola)
✅ USDA text search returns results — test "chicken breast"
✅ Missing OFF macros → Claude fills them, FoodEntry = .estimated
✅ Barcode not found → ActionSheet with options, no dead end
✅ Empty search → Recently Used section appears
✅ Food log groups entries by meal correctly
✅ Dashboard macro rings update after logging
✅ No crashes on nil/partial API responses

Getting your free USDA key (takes 2 minutes):
  1. Go to https://api.nal.usda.gov/api-guide
  2. Click "Get an API Key" → enter email → key arrives instantly
  3. Temporarily add to KeychainManager in AppEntry for testing:
     KeychainManager.save(key: Keys.usdaApiKey, value: "YOUR_KEY_HERE")
  4. Remove this line before committing — add via Settings screen later

Next: Phase 3.5 — Manual Food Entry & Custom Recipes

=========================================================
# PHASE 3.5 — Manual Food Entry & Custom Recipes
# Build immediately after Phase 3.
# These are V1 features, not optional extras.
# =========================================================

=========================================================
## PROMPT 3.5A — Custom Food Model & Library
=========================================================

---
Create the data models and service for user-created custom foods.
Place models in Models/, service in Services/Nutrition/

**Models/CustomFood.swift**
SwiftData @Model:
  id: UUID
  name: String
  brand: String?
  caloriesPerServing: Double
  proteinPerServing: Double
  carbsPerServing: Double
  fatPerServing: Double
  servingSize: Double
  servingUnit: String
  createdAt: Date
  lastUsedAt: Date?
  useCount: Int
  source: CustomFoodSource enum (.userCreated, .aiAssisted)

**Models/RecipeIngredient.swift**
SwiftData @Model — macro SNAPSHOT, not a live reference:
  id: UUID
  name: String
  quantity: Double
  unit: String
  calories: Double   ← snapshot value at recipe-save time
  protein: Double    ← snapshot
  carbs: Double      ← snapshot
  fat: Double        ← snapshot
  sourceType: String (display only — "usda" / "openFoodFacts" / "custom" / "recipe")

**Models/CustomRecipe.swift**
SwiftData @Model:
  id: UUID
  name: String
  notes: String?
  ingredients: [RecipeIngredient] (cascade delete)
  totalServings: Double
  createdAt: Date
  lastUsedAt: Date?
  useCount: Int
  isArchived: Bool (soft delete — NEVER hard delete logged recipes)

Computed properties:
  totalCalories, totalProtein, totalCarbs, totalFat
  caloriesPerServing, proteinPerServing, carbsPerServing, fatPerServing
  macroSummary: String → "320 cal · 38g P · 28g C · 6g F per serving"

**Services/Nutrition/CustomFoodLibrary.swift**
@Observable class:
  recentCustomFoods: [CustomFood]  (last 10 by lastUsedAt)
  recentRecipes: [CustomRecipe]    (last 5 by lastUsedAt)

  func saveCustomFood(_ food: CustomFood, context: ModelContext)
  func saveRecipe(_ recipe: CustomRecipe, context: ModelContext)
  func logCustomFood(_ food: CustomFood, servings: Double, mealType: MealType, context: ModelContext) -> FoodEntry
    → confidence = .manual, increments useCount, updates lastUsedAt
  func logRecipe(_ recipe: CustomRecipe, servings: Double, mealType: MealType, context: ModelContext) -> FoodEntry
    → ONE FoodEntry for the whole recipe (not per ingredient)
    → confidence = .recipe
    → macros = perServing × servingsLogged
  func searchCustomFoods(query: String) -> [CustomFood]
  func searchRecipes(query: String) -> [CustomRecipe]  (excludes isArchived)
  func unifiedSearch(query: String, databaseResults: [FoodResult]) -> UnifiedSearchResults
    → merges recipes + custom foods + database results in priority order
---

=========================================================
## PROMPT 3.5B — Manual Food Entry View
=========================================================

---
Create the manual food entry flow.
Place in Views/FoodLibrary/ManualFoodEntryView.swift

Accepts optional prefillSuggestion: FoodResult? from AI or failed lookup.

Form fields:
  Food Name* (required)
  Brand/Source (optional — "My Kitchen", restaurant name)
  Serving Size: [number] [unit picker: g/oz/ml/cup/tbsp/tsp/piece/serving]
  Calories* (required)
  Protein (g)*
  Carbs (g)*
  Fat (g)*

Macro sanity check (live):
  Calculate: (protein×4) + (carbs×4) + (fat×9)
  If differs from entered calories by >10%:
  Show yellow warning: "Macros add up to X cal — double check your numbers"
  Do NOT block submission — just warn

AI prefill banner:
  If prefillSuggestion != nil: show subtle banner
  "AI estimated these values — adjust if needed"
  If user edits ANY field: confidence = .manual
  If user logs without editing: confidence = .estimated

Save to Library toggle (default ON):
  ON → saves as CustomFood for future reuse
  OFF → one-time log only

Meal type picker

"Log Food" button → FoodEntry saved, CustomFood saved if toggle ON

Confidence rules:
  User typed from scratch → .manual
  AI prefilled, user edited → .manual
  AI prefilled, user logged unchanged → .estimated
---

=========================================================
## PROMPT 3.5C — AI Macro Estimation for Manual Entry
=========================================================

---
Add estimateFoodNutrition to ClaudeAPIService.swift for manual entry prefill.
Also used by FoodDatabaseService when OFF returns missing macros.

func estimateFoodNutrition(foodDescription: String) async -> FoodResult?

System prompt:
"""
Estimate nutrition for this food and return ONLY valid JSON, no other text:
{
  "food_name": "cleaned food name",
  "serving_qty": 1,
  "serving_unit": "serving",
  "nf_calories": 0,
  "nf_protein": 0,
  "nf_total_carbohydrate": 0,
  "nf_total_fat": 0,
  "confidence": "low|medium|high"
}
Use typical average values. If too vague to estimate, return {"items": null}.
Round all values to nearest whole number.
"""

Timeout: 3 seconds. If Claude doesn't respond in time, return nil silently.
Never throw to caller — return nil on any error.
On nil: ManualFoodEntryView opens with blank form.
On result: ManualFoodEntryView pre-fills and shows AI banner.

Also add estimateMacros(for partial: FoodResult) async -> FoodResult:
Used when OFF returns a product but macros are missing.
Passes product name + available data to Claude to fill gaps.
Returns the FoodResult with hasMissingMacros = false.
---

=========================================================
## PROMPT 3.5D — Recipe Builder
=========================================================

---
Create recipe building flow.
Place in Views/FoodLibrary/

**Views/FoodLibrary/RecipeBuilderView.swift**
Full-screen view for creating/editing recipes.

Local state (not SwiftData while building):
  recipeName: String
  notes: String
  ingredients: [RecipeIngredientDraft]  ← local struct, not @Model
  totalServings: Double (default 4)

RecipeIngredientDraft struct:
  name, quantity, unit: String/Double
  calories, protein, carbs, fat: Double
  sourceType: String

Header: recipe name TextField (large), notes TextField (small), servings stepper

Ingredients list:
  Each row: name, quantity, calories
  Swipe to delete
  Drag handle to reorder (.onMove)
  "Add Ingredient" button → opens FoodSearchView(.ingredientPicker mode)
    When ingredient selected via callback → append to ingredients array

Footer (sticky):
  Total macro summary: "Total: X cal · Xg P · Xg C · Xg F"
  Per serving: "Per serving: X cal · Xg P · Xg C · Xg F"
  Both update live as ingredients change
  "Save Recipe" button (validates: name not empty, 1+ ingredients)

On save:
  Convert [RecipeIngredientDraft] → [RecipeIngredient] SwiftData models
  Each RecipeIngredient captures macro SNAPSHOT at this moment
  Create CustomRecipe, call CustomFoodLibrary.saveRecipe()
  Navigate to RecipeDetailView

Edit mode:
  Pre-populate from existing CustomRecipe
  On save → create NEW CustomRecipe (new UUID, new createdAt)
  Set old recipe.isArchived = true
  NEVER mutate existing recipe — this protects historical log accuracy

**Views/FoodLibrary/RecipeDetailView.swift**
Read-only recipe view:
  Recipe name (large)
  Macro summary card: per serving + total
  Servings stepper (default 1, adjusts displayed macros live)
  "Log This Recipe" → CustomFoodLibrary.logRecipe(servings: selected)
  Ingredients list (read-only)
  Edit button → RecipeBuilderView(editMode: recipe)
  Archive button (confirm dialog) → recipe.isArchived = true

**Views/FoodLibrary/CustomRecipeListView.swift**
Browse all non-archived recipes:
  Sorted by lastUsedAt desc
  Search bar (filters by name)
  Each row: name, macroSummary, last used date
  Tap → RecipeDetailView
  Swipe left → Archive (3-second undo snackbar)
  "New Recipe" button → RecipeBuilderView (blank)
  Empty state: "No recipes yet — build your first meal prep" + button
---

=========================================================
## PROMPT 3.5E — Wire Into Existing Flow
=========================================================

---
Update existing views to integrate custom foods, recipes, and manual entry.

Updates to FoodSearchView (from Prompt 3.4):
  Already has the three-section structure — verify CustomFoodLibrary
  is being queried alongside USDA results.
  Verify Recently Used appears when query is empty.
  Verify "+ Add food manually" and "+ Build a recipe" always visible.

Updates to FoodLogView FAB (from Prompt 3.5):
  Ensure "My Recipes" option opens CustomRecipeListView as a sheet.

Updates to DashboardView quick-add:
  Same 4 options as FoodLogView FAB.

Add CustomFoodLibrary to AppState as an @Observable property
so it's accessible throughout the app via @EnvironmentObject.
---

=========================================================
## AFTER PHASE 3.5

Checkpoints:
✅ Barcode 404 → ActionSheet with options (not dead end)
✅ Empty search → Recently Used section
✅ Manual entry form AI prefills when possible
✅ Custom foods save to library and appear in future searches
✅ Recipe builder works with ingredient search
✅ Recipe shows correct per-serving macros
✅ Logging recipe creates ONE FoodEntry with .recipe confidence
✅ Editing recipe creates new version (old archived, not deleted)

Meal prep test:
  1. Build "Chicken Rice Meal Prep" with 4 ingredients, 6 servings
  2. Save recipe
  3. Open search (empty query) → recipe appears in Recently Used
  4. Log 2 servings → verify 1 FoodEntry with correct macros (2/6 of total)
  5. Edit recipe → verify old recipe isArchived=true in SwiftData

Next: Phase 4 — AI Conversational Logger
