# PHASE 3 — Nutrition Logging (Barcode + Search)
# Nutritionix API + barcode scanner + food log UI
# Complete Phase 2 before starting this.
# =========================================================

=========================================================
## PROMPT 3.1 — Nutritionix Service
=========================================================

---
Create the Nutritionix API integration.
Place in Services/Nutrition/

**Services/Nutrition/FoodResult.swift**
A Swift struct (Codable) representing a food item returned from Nutritionix:
- nixItemId: String?
- foodName: String
- brandName: String?
- servingQty: Double
- servingUnit: String
- servingWeightGrams: Double?
- calories: Double
- protein: Double
- totalCarbohydrate: Double (rename to carbs in local property)
- totalFat: Double (rename to fat in local property)
- thumbnail: URL? (optional food image)

Add a convenience init that creates a FoodEntry from a FoodResult with
specified servingMultiplier, mealType, and confidence level.

**Services/Nutrition/NutritionixService.swift**
An @Observable class with methods:

- func searchFood(query: String) async throws -> [FoodResult]
  Calls GET /v2/search/instant?query={query}&self=false&branded=true&common=true
  Maps response to [FoodResult]

- func lookupBarcode(upc: String) async throws -> FoodResult?
  Calls GET /v2/search/item?upc={upc}
  Returns nil if not found (404) — caller MUST offer manual entry fallback, throws for other errors

- func getNutritionDetails(for item: FoodResult) async throws -> FoodResult
  Calls POST /v2/natural/nutrients for detailed breakdown
  Only needed if initial search result is missing macro data

Auth: read App ID and App Key from KeychainManager using Keys.nutritionixAppId
and Keys.nutritionixAppKey.

Error handling:
- Create a NutritionixError enum: notFound, unauthorized, rateLimited, networkError(String)
- Map HTTP status codes to these cases
- 404 → .notFound  (caller should offer manual entry — not a hard error)
- 401 → .unauthorized
- 429 → .rateLimited
- Other errors → .networkError with description

Use URLSession.shared for all networking (Swift's HttpClient equivalent).
Decode responses with JSONDecoder — set keyDecodingStrategy = .convertFromSnakeCase
so "serving_qty" in JSON maps to "servingQty" in Swift automatically.

For Java context: URLSession is Java's HttpClient. JSONDecoder is ObjectMapper.
keyDecodingStrategy = .convertFromSnakeCase is like @JsonNaming(SnakeCaseStrategy.class).
---

=========================================================
## PROMPT 3.2 — Barcode Scanner
=========================================================

---
Create the barcode scanner view.
Place in Views/FoodLog/BarcodeScannerView.swift

Use DataScannerViewController (iOS 16+) wrapped in UIViewControllerRepresentable
(the SwiftUI bridge for UIKit components — similar to wrapping a 
Java Swing component in a JavaFX node).

**Views/FoodLog/BarcodeScannerView.swift**
A SwiftUI view that:
1. Presents a full-screen camera view using DataScannerViewController
2. Scans for barcode types: .ean8, .ean13, .upce, .code128
3. When a barcode is detected, calls onBarcodeDetected(_ upc: String) callback
4. Shows a scanning overlay: dark corners with a bright center rectangle
5. Has a cancel button (X) in the top right

The DataScannerViewController configuration:
- recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .code128])]
- qualityLevel: .accurate
- isHighlightingEnabled: true (highlights detected barcodes)

NOTE: Barcode scanning requires a REAL DEVICE — it won't work in the simulator.
For simulator testing, create a BarcodeScannerPreview that shows a text field
where you can type a UPC manually. Use #if targetEnvironment(simulator) 
preprocessor directive to switch between real scanner and preview mode.

For Java context: UIViewControllerRepresentable is like implementing 
a SwingNode in JavaFX — it bridges the old UI framework (UIKit/Swing) 
into the new one (SwiftUI/JavaFX).
---

=========================================================
## PROMPT 3.3 — Food Log Views
=========================================================

---
Create the food logging UI views.
Place in Views/FoodLog/

**Views/FoodLog/FoodSearchView.swift**
A sheet/modal view with:
- Search bar at top (TextField bound to @State searchQuery)
- As user types (with 0.3s debounce), calls NutritionixService.searchFood()
- Results list with FoodResultRow for each item
- Tap a result → show ServingSizePicker sheet
- Loading state while searching
- Empty state: "Start typing to search foods"
- Error state: "Couldn't reach food database — check connection"
- Empty results state: show "Not finding it? Add it manually" button
  that opens ManualFoodEntryView — never show just a dead-end empty list
- On any Nutritionix error, also show the manual entry fallback button

**Views/FoodLog/FoodResultRow.swift**
A list row showing:
- Food name (bold)
- Brand name if available (gray, smaller)
- Per-serving calories (right aligned)
- Small thumbnail image if available (async loaded with AsyncImage)

**Views/FoodLog/ServingSizePickerView.swift**
A bottom sheet showing:
- Food name as title
- Macro breakdown: calories, protein, carbs, fat per serving
- Serving quantity stepper (0.5 increments, default 1.0)
- Serving unit label (e.g., "cup", "oz", "piece")
- Meal type picker: Breakfast / Lunch / Dinner / Snack (segmented control)
- "Log This Food" button → creates FoodEntry with .precise confidence, saves to SwiftData
- Macros update in real time as serving quantity changes

**Views/FoodLog/FoodLogView.swift**
The main food log screen showing today's entries:
- Header: today's date
- MacroSummaryBar at top: shows calories/protein/carbs/fat logged vs target
- List of entries grouped by MealType section
- Each entry shows: name, confidence badge (subtle — only visible for .estimated), macros
- Swipe left to delete an entry
- Swipe right to copy to today (if viewing a past day)
- FAB (floating action button) at bottom right with + icon
- Tapping + shows an ActionSheet: "Scan Barcode" or "Search Food" 
  (AI chat logger added in Phase 4)
---

=========================================================
## PROMPT 3.4 — Dashboard View (Basic Version)
=========================================================

---
Create the basic dashboard view (we'll enhance it after Phase 5 with
learning engine data, but get the structure in place now).
Place in Views/Dashboard/

**Views/Dashboard/MacroRingView.swift**
A circular progress ring for a single macro:
- Accepts: current Double, target Double, color: Color, label: String
- Shows percentage filled as an arc
- Center text shows current value (e.g., "142g" or "1,840")
- Label below the ring (e.g., "Protein", "Calories")
- Protein ring should be slightly larger than carb/fat rings to
  emphasize its priority

**Views/Dashboard/EffortBadgeView.swift**
A small pill/badge showing today's effort level:
- Different color per level: gray=rest, blue=low, green=moderate, orange=high, red=veryHigh
- Shows icon + label: "🔥 High" or "😴 Rest"

**Views/Dashboard/DashboardView.swift**
The home screen — should be glanceable in 3 seconds:
- Top: greeting ("Good morning, [name]") + today's date
- Large calorie ring in center (remaining calories, most prominent element)
- Row of 3 smaller rings: Protein, Carbs, Fat
- EffortBadge for today
- Today's weight from HealthKit (if available)
- Quick-add button: opens sheet with "Scan Barcode", "Search Food", "Tell AI" options
- Recent entries: last 3 food log items with a "See All" link

All data comes from @Query (SwiftData live queries) and @EnvironmentObject AppState.
No business logic in the view body.
---

=========================================================
## AFTER PHASE 3

Checkpoint:
✅ Can search for food by text and log it
✅ Barcode scanner compiles (test on real device if available, or simulator text fallback)
✅ Food log shows today's entries grouped by meal
✅ Dashboard shows macro rings updating as food is logged
✅ No API keys in source code
✅ Nutritionix errors handled gracefully (no crashes)

To test Nutritionix: go to developer.nutritionix.com, sign up free,
get your App ID and App Key. Enter them in Settings screen (which we'll
build properly in Phase 6, but temporarily hardcode in KeychainManager
init for testing — REMOVE before any sharing/committing).

Next: Phase 4 — AI Conversational Logger


=========================================================
# PHASE 3.5 — Manual Food Entry & Custom Recipes
# Build this immediately after Phase 3.
# These are V1 features, not optional extras.
# =========================================================

=========================================================
## PROMPT 3.5A — Custom Food Model & Library
=========================================================

---
Create the data models and service for user-created custom foods.
Place models in Models/, service in Services/Nutrition/

**Models/CustomFood.swift**
SwiftData @Model class representing a user-created food:
- id: UUID
- name: String
- brand: String? (optional — "My Kitchen", restaurant name, etc.)
- caloriesPerServing: Double
- proteinPerServing: Double
- carbsPerServing: Double
- fatPerServing: Double
- servingSize: Double (numeric quantity)
- servingUnit: String (e.g., "g", "oz", "cup", "piece")
- createdAt: Date
- lastUsedAt: Date? (update this every time user logs this food — for sorting)
- useCount: Int (increment each log — for "frequently used" sorting)
- source: CustomFoodSource enum:
  .userCreated (typed in manually from scratch)
  .aiAssisted (Claude prefilled it, user confirmed or edited)

**Models/RecipeIngredient.swift**
SwiftData @Model — a SNAPSHOT of one ingredient within a recipe:
- id: UUID
- name: String (snapshot — not a live reference)
- quantity: Double
- unit: String
- calories: Double (snapshot at time recipe was saved)
- protein: Double
- carbs: Double
- fat: Double
- sourceType: String (nutritionix / customFood / recipe — for display only)

**Models/CustomRecipe.swift**
SwiftData @Model:
- id: UUID
- name: String (e.g., "My Chicken Meal Prep", "Post-Workout Shake")
- notes: String? (optional instructions or reminders)
- ingredients: [RecipeIngredient] (snapshots — see rules above)
- totalServings: Double (how many servings the full recipe makes, e.g., 6)
- createdAt: Date
- lastUsedAt: Date?
- useCount: Int
- isArchived: Bool (soft delete — don't hard delete recipes that have been logged)

Computed properties on CustomRecipe:
- var totalCalories: Double (sum of all ingredient calories)
- var totalProtein: Double
- var totalCarbs: Double
- var totalFat: Double
- var caloriesPerServing: Double (totalCalories / totalServings)
- var proteinPerServing: Double
- var carbsPerServing: Double
- var fatPerServing: Double
- var macroSummary: String — e.g., "320 cal · 38g P · 28g C · 6g F per serving"

**Services/Nutrition/CustomFoodLibrary.swift**
An @Observable class managing custom foods and recipes:
- var recentCustomFoods: [CustomFood] (last 10 used, for quick access)
- var recentRecipes: [CustomRecipe] (last 5 used)

Methods:
- func saveCustomFood(_ food: CustomFood, context: ModelContext)
  Sets createdAt, saves to SwiftData
- func saveRecipe(_ recipe: CustomRecipe, context: ModelContext)
- func logCustomFood(_ food: CustomFood, servings: Double, mealType: MealType, context: ModelContext) -> FoodEntry
  Creates FoodEntry with confidence .manual, increments food.useCount, updates lastUsedAt
- func logRecipe(_ recipe: CustomRecipe, servings: Double, mealType: MealType, context: ModelContext) -> FoodEntry
  Creates a single FoodEntry representing the recipe (not individual ingredients)
  Confidence = .recipe. Name = recipe.name. Macros = per-serving macros × servings logged.
- func searchCustomFoods(query: String) -> [CustomFood]
  Simple case-insensitive name search across all saved custom foods
- func searchRecipes(query: String) -> [CustomRecipe]
  Case-insensitive search, excludes archived recipes
---

=========================================================
## PROMPT 3.5B — Manual Food Entry View
=========================================================

---
Create the manual food entry flow.
Place in Views/FoodLibrary/ManualFoodEntryView.swift

This view serves two purposes:
1. Fallback when barcode/search fails
2. Standalone entry from the food library

The view accepts an optional prefillSuggestion: FoodResult? parameter.
When provided (from AI or Nutritionix fallback attempt), the form
pre-populates with those values. When nil, form starts blank.

**Layout:**
- Title: "Add Food Manually" (or "Food Not Found — Add It" if coming from failed lookup)
- If prefilled by AI: show a subtle banner "AI estimated these values — adjust if needed"
  with confidence set to .estimated unless user edits any field (then .manual)
- Form fields:
  Food Name* (required, TextField)
  Brand / Source (optional, TextField — e.g., "Whole Foods", "My Kitchen")
  Serving Size: [number field] [unit picker: g / oz / ml / cup / tbsp / tsp / piece / serving]
  Calories* (required, number field)
  Protein (g)* (required)
  Carbs (g)* (required)  
  Fat (g)* (required)
  
- Live calorie check: show calculated calories from macros (P×4 + C×4 + F×9)
  vs entered calories. If they differ by >10%: show yellow warning
  "Macros add up to X cal — double check your numbers"
  This helps catch typos without being annoying.

- Meal type picker (same as elsewhere)

- "Save to My Foods" toggle (default ON)
  When ON: saves to CustomFoodLibrary for future reuse
  When OFF: logs this one time only, not saved to library

- "Log Food" button → creates FoodEntry, saves CustomFood if toggle on,
  dismisses sheet

- Confidence assigned:
  .manual if user typed the values or edited AI prefill
  .estimated if AI prefilled and user logged without changing anything

For Java context: the live macro calculation is a computed property in
the ViewModel, not in the View. The View observes it via @Observable.
---

=========================================================
## PROMPT 3.5C — AI Prefill for Manual Entry
=========================================================

---
Add AI-assisted prefill to ManualFoodEntryView.

When ManualFoodEntryView is opened after a failed barcode lookup or
empty search, and the user had typed a food name in the search bar,
automatically attempt to prefill the form using Claude.

Add this method to ClaudeAPIService.swift:

func estimateFoodNutrition(foodDescription: String) async -> FoodResult?

System prompt:
"""
Estimate the nutrition for this food item and return ONLY valid JSON, no other text:
{
  "food_name": "cleaned up food name",
  "serving_qty": 1,
  "serving_unit": "serving",
  "nf_calories": 0,
  "nf_protein": 0,
  "nf_total_carbohydrate": 0,
  "nf_total_fat": 0,
  "confidence": "low|medium|high"
}
Use typical/average values for this food. If the food is too vague to estimate
(e.g. just "food"), return null. Round all values to nearest whole number.
"""

In ManualFoodEntryView:
- Show a loading state "Looking up nutrition..." while Claude responds
- If Claude returns a result, prefill the form and show the AI banner
- If Claude returns null or errors, open blank form silently
- The whole prefill attempt should take <2 seconds — if it takes longer,
  open blank form and let prefill arrive asynchronously

This makes manual entry feel smart rather than tedious.
---

=========================================================
## PROMPT 3.5D — Recipe Builder
=========================================================

---
Create the recipe builder flow.
Place in Views/FoodLibrary/

**Views/FoodLibrary/RecipeBuilderView.swift**
Full-screen view for creating or editing a recipe.

State: recipeName, notes, ingredients: [RecipeIngredientDraft], totalServings

RecipeIngredientDraft is a local struct (not SwiftData) used while building:
- name, quantity, unit, calories, protein, carbs, fat, sourceType

Header:
- Recipe name text field (large, prominent)
- Notes field (optional, small)
- Servings stepper: "Makes [X] servings" (default 4)

Ingredients section:
- List of added ingredients showing name, quantity, and calories
- Swipe to delete an ingredient
- Reorder via drag handle (List with .onMove modifier)
- "Add Ingredient" button at bottom of list

"Add Ingredient" opens a sheet that reuses the EXISTING food search
flow — same FoodSearchView from Phase 3, but in "ingredient picker" mode.
When user selects a food and serving size, it adds a RecipeIngredientDraft
to the list instead of logging a FoodEntry. This is controlled by a
mode parameter on FoodSearchView: .logging vs .ingredientPicker

Footer (sticky at bottom):
- Live macro totals for entire recipe: "Total: X cal · Xg P · Xg C · Xg F"
- Per serving totals: "Per serving: X cal · Xg P · Xg C · Xg F"
- These update in real-time as ingredients are added/removed/edited
- "Save Recipe" button — validates name is not empty and at least 1 ingredient

On save:
1. Convert RecipeIngredientDraft list → [RecipeIngredient] SwiftData models (snapshots)
2. Create CustomRecipe with those ingredients
3. Save via CustomFoodLibrary.saveRecipe()
4. Dismiss and navigate to RecipeDetailView

**Views/FoodLibrary/RecipeDetailView.swift**
Read-only view of a saved recipe:
- Recipe name (large)
- Macro summary card: calories/protein/carbs/fat per serving + total
- Servings selector (stepper) — defaults to 1
- "Log This Recipe" button → calls CustomFoodLibrary.logRecipe() with selected servings
- Ingredients list (read-only, shows all with quantities and cals)
- Edit button (top right) → opens RecipeBuilderView in edit mode
- Archive button (destructive, confirm dialog) → sets isArchived = true

Edit mode behavior:
- RecipeBuilderView pre-populates with existing recipe data
- On save: creates a NEW CustomRecipe (does not mutate the existing one)
  The old recipe stays in the database to preserve historical food log accuracy
- The new recipe becomes the "active" version going forward

**Views/FoodLibrary/CustomRecipeListView.swift**
List of all saved recipes (non-archived):
- Sorted by lastUsedAt descending (most recently used first)
- Each row: recipe name, per-serving macro summary, last used date
- Tap → RecipeDetailView
- Swipe left → Archive (with undo option via .snackbar for 3 seconds)
- Search bar at top filtering by name
- "New Recipe" button → RecipeBuilderView (blank)
- Empty state: "No recipes yet — build your first meal prep" + New Recipe button
---

=========================================================
## PROMPT 3.5E — Integrate Into Food Log & Search
=========================================================

---
Wire custom foods, recipes, and manual entry into the existing
food logging flow so everything feels like one unified experience.

**Updates to FoodSearchView:**
The search results should now show THREE sections:
1. "My Recipes" — CustomRecipe results (if any match)
2. "My Foods" — CustomFood results (if any match)  
3. "Foods Database" — Nutritionix results

When search query is empty (user just opened search):
Show "Recently Used" section with last 5 custom foods + last 3 recipes
This makes meal prep logging extremely fast — just open search and
your chicken and rice is right there without typing anything.

At the bottom of any search result (empty or not):
Always show: "+ Add food manually" link → ManualFoodEntryView
             "+ Build a recipe" link → RecipeBuilderView

**Updates to FoodLogView:**
The "+" FAB action sheet now has 4 options:
- Scan Barcode
- Search Foods
- Tell AI (chat logger)
- My Recipes (shortcut directly to CustomRecipeListView)

**Updates to DashboardView quick-add:**
Same 4 options as above.
---

=========================================================
## AFTER PHASE 3.5

Checkpoint:
✅ Barcode 404 → action sheet with options (not dead end)
✅ Empty search → manual entry option always visible
✅ Manual entry form pre-fills from AI when possible
✅ Custom foods save to library and appear in future searches
✅ Can build a recipe from multiple ingredients
✅ Recipe shows correct per-serving macros
✅ Logging a recipe creates a single FoodEntry with .recipe confidence
✅ Recently used foods/recipes appear at top of empty search
✅ Editing a recipe creates a new version (old version preserved)

Test scenario — meal prep workflow:
1. Build "Chicken Rice Meal Prep" recipe with 4 ingredients
2. Set it to make 6 servings
3. Log 2 servings for lunch
4. Verify: 1 FoodEntry created with correct macros (2/6 of total)
5. Open search tomorrow → recipe appears in Recently Used
6. Log again in 2 taps

This workflow is the whole point of the feature.
