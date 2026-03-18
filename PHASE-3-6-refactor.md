# PHASE 3.6 — REFACTOR: Nutritionix → Open Food Facts + USDA
# Run this ONLY if you already built Phase 3 using Nutritionix.
# If you're starting fresh, skip this file entirely —
# Phase 3 already uses the correct APIs.
# =========================================================

# WHY THIS EXISTS

Nutritionix discontinued free/personal API access. This phase
refactors the NutritionixService you already built into two
replacement services: OpenFoodFactsService (barcode) and
USDAService (text search). The rest of the app stays the same.

Estimated time: 2-3 hours

=========================================================
## PROMPT 3.6A — Audit What Needs Changing
=========================================================

---
Before making any changes, audit the existing codebase.
List every file that imports or references NutritionixService.

Search the project for:
- "NutritionixService"
- "nutritionix"
- "trackapi.nutritionix.com"
- "x-app-id" header
- "x-app-key" header
- "Keys.nutritionixAppId"
- "Keys.nutritionixAppKey"

List every file found and which references need to change.
Do not make any changes yet — just report what you find.
---

=========================================================
## PROMPT 3.6B — Create OpenFoodFactsService
=========================================================

---
Create Services/Nutrition/OpenFoodFactsService.swift as a NEW file.
Do not delete NutritionixService yet — we'll do that last.

@Observable class OpenFoodFactsService:

func lookupBarcode(_ upc: String) async throws -> FoodResult?

Implementation:
  1. GET https://world.openfoodfacts.org/api/v2/product/{upc}.json
     No auth headers needed — this API is completely open
  2. Check response.status == 1 (found). Return nil if 0.
  3. Parse from product.nutriments:
     energy-kcal_100g → caloriesPer100g  (NOT energy_100g which is kJ)
     proteins_100g    → protein per 100g
     carbohydrates_100g → carbs per 100g
     fat_100g         → fat per 100g
  4. Parse product.serving_size if present (e.g. "30 g" or "1 cup (240ml)")
     Extract the gram value — regex for number before "g"
     If no serving size, default to 100g serving
  5. Convert per-100g to per-serving:
     calories = (caloriesPer100g / 100) * servingGrams
  6. If macros missing: set hasMissingMacros = true, return partial result
  7. Fill in: product.product_name, product.brands, product.image_url

Update FoodResult.swift to add:
  var hasMissingMacros: Bool = false
  var source: FoodSource = .usda  (add .openFoodFacts and .ai cases)

Write a unit test in EngineTests/ that mocks an OFF response
and verifies the per-100g → per-serving conversion is correct.
---

=========================================================
## PROMPT 3.6C — Create USDAService
=========================================================

---
Create Services/Nutrition/USDAService.swift as a NEW file.

@Observable class USDAService:

func searchFood(_ query: String) async throws -> [FoodResult]
func getFoodDetail(fdcId: Int) async throws -> FoodResult

searchFood:
  1. Load key: KeychainManager.load(key: Keys.usdaApiKey) ?? ""
  2. GET https://api.nal.usda.gov/fdc/v1/foods/search
     ?query={encoded query}
     &pageSize=20
     &dataType=Branded,Survey(FNDDS)
     &api_key={key}
  3. For each food in response.foods[]:
     Find nutrients by nutrientId in food.foodNutrients[]:
       1008 → calories (kcal)
       1003 → protein (g)
       1005 → carbohydrates (g)
       1004 → total fat (g)
     Get servingSize from food.servingSize (Double)
     Get servingSizeUnit from food.servingSizeUnit (String)
     If no serving data: default 100g
  4. Filter: remove any result where calories == 0
  5. Set source = .usda on all results

getFoodDetail:
  GET /fdc/v1/food/{fdcId}?api_key={key}
  Same nutrient parsing.
  Also extract food.foodMeasures[] for serving size options:
  Each measure has: disseminationText (label), gramWeight
  Return these as [(label: String, grams: Double)] on FoodResult
  for the ServingSizePickerView to display.

Add to KeychainManager Keys enum:
  static let usdaApiKey = "usda_api_key"

Handle errors:
  401 → .unauthorized (bad API key)
  429 → .rateLimited
  Other → .networkError
---

=========================================================
## PROMPT 3.6D — Create FoodDatabaseService Facade
=========================================================

---
Create Services/Nutrition/FoodDatabaseService.swift
This replaces NutritionixService as the single entry point
for all food data operations.

@Observable class FoodDatabaseService:
  private let offService = OpenFoodFactsService()
  private let usdaService = USDAService()

  func searchFood(_ query: String) async throws -> [FoodResult]
    → delegates to usdaService.searchFood(query)

  func lookupBarcode(_ upc: String) async -> FoodResult?
    → result = try? await offService.lookupBarcode(upc)
    → if result?.hasMissingMacros == true:
        return await fillMissingMacros(result!)
    → return result (may be nil = not found)

  private func fillMissingMacros(_ partial: FoodResult) async -> FoodResult
    → calls ClaudeAPIService.estimateFoodNutrition(partial.foodName)
    → merges Claude's estimates into missing fields
    → sets hasMissingMacros = false
    → FoodEntry using this result will have .estimated confidence

Inject FoodDatabaseService into AppState as a property.
Remove any direct references to NutritionixService from AppState.
---

=========================================================
## PROMPT 3.6E — Update All Call Sites
=========================================================

---
Update every file that currently calls NutritionixService
to use FoodDatabaseService instead.

For each file found in the audit (Prompt 3.6A):

1. Replace: let nutritionixService = NutritionixService()
   With: access FoodDatabaseService from @EnvironmentObject appState

2. Replace: nutritionixService.searchFood(query)
   With: appState.foodDatabaseService.searchFood(query)

3. Replace: nutritionixService.lookupBarcode(upc)
   With: appState.foodDatabaseService.lookupBarcode(upc)

4. Replace: nutritionixService.lookupNaturalLanguage(text)
   With: clauService.estimateFoodNutrition(text)
   (Claude handles natural language food estimation now)

5. Update error handling:
   Replace NutritionixError cases with FoodDatabaseError cases
   The case names are similar — .notFound, .networkError, .unauthorized

6. Update BarcodeResultHandler if it exists:
   Replace NutritionixService call with FoodDatabaseService.lookupBarcode()
   The ScanState enum and flow logic stays the same

After each file is updated, build to verify no compile errors
before moving to the next file.
---

=========================================================
## PROMPT 3.6F — Remove Nutritionix & Clean Up
=========================================================

---
Once all call sites are updated and the project compiles cleanly:

1. Delete Services/Nutrition/NutritionixService.swift
2. Remove from KeychainManager Keys enum:
   - Keys.nutritionixAppId
   - Keys.nutritionixAppKey
3. Remove any Nutritionix-related entries from Settings screen
4. Add USDA API key entry to Settings screen:
   Label: "USDA Food Database Key (free — api.nal.usda.gov)"
   Same masked text field pattern as other API keys
   Saves to KeychainManager using Keys.usdaApiKey
5. Update any comments or strings mentioning "Nutritionix"

Final build check:
  - grep -r "nutritionix\|Nutritionix" . --include="*.swift"
  - Should return zero results
  - Build with Cmd+B — zero errors, zero warnings about missing types

Commit:
  git add .
  git commit -m "Refactor: replace Nutritionix with Open Food Facts + USDA"
  git push
---

=========================================================
## AFTER PHASE 3.6

Checkpoints:
✅ NutritionixService.swift deleted
✅ No remaining references to Nutritionix in Swift files
✅ Barcode lookup works via Open Food Facts (test: 0049000028911)
✅ Text search works via USDA (test: "chicken breast")
✅ Missing OFF macros → Claude fills them
✅ Settings screen has USDA key field (no Nutritionix fields)
✅ All existing Phase 3 features still working
✅ Committed and pushed

Note on testing:
Open Food Facts covers most major US grocery brands.
If a barcode returns nil, it genuinely isn't in their database —
the manual entry fallback is working as designed.
USDA covers virtually all common foods for text search.
Between the two, you should rarely need manual entry for common foods.
