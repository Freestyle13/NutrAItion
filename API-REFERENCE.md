# API REFERENCE & SYSTEM PROMPTS
# Ready-to-use API configurations and Claude prompts.
# Copy these directly into your service classes.
# =========================================================

## OPEN FOOD FACTS API (Barcode Lookup)

Base URL: https://world.openfoodfacts.org/api/v2
Sign up: NOT REQUIRED — completely free and open, no account needed

### No Auth Headers Needed
This API is fully public. No keys, no registration.

### Endpoints

**Barcode Lookup**
GET /api/v2/product/{upc}.json

Response check: response.status == 1 (found) or 0 (not found)
Key fields:
  product.product_name     → food name
  product.brands           → brand
  product.image_url        → food photo
  product.serving_size     → serving string e.g. "30 g" or "1 cup"
  product.nutriments:
    energy-kcal_100g       → calories per 100g (NOT energy_100g which is kJ!)
    proteins_100g          → protein per 100g
    carbohydrates_100g     → carbs per 100g
    fat_100g               → fat per 100g

IMPORTANT: All macro values are per 100g. Convert to per-serving:
  value = (per100g / 100.0) * servingGrams

Test barcode: 0049000028911 (Coca-Cola 12oz can)

### Handling Missing Macros
OFF is crowd-sourced — macro fields may be nil on some products.
Always check for nil. If missing: return partial result with
hasMissingMacros = true, then call Claude to estimate the gaps.

### Rate Limits
No hard rate limits for reasonable personal/development use.

---

## USDA FOODDATA CENTRAL API (Text Search)

Base URL: https://api.nal.usda.gov/fdc/v1
Sign up: https://api.nal.usda.gov/api-guide (free key, instant email delivery)
Key storage: KeychainManager using Keys.usdaApiKey

### Authentication
Pass as query parameter — no request headers needed:
  ?api_key={your_key}

### Endpoints

**Text Search**
GET /fdc/v1/foods/search?query={q}&pageSize=20&dataType=Branded,Survey(FNDDS)&api_key={key}

Response path: response.foods[]
Per food item:
  fdcId: Int              → unique ID for detail lookup
  description: String     → food name
  brandOwner: String?     → brand name
  servingSize: Double?
  servingSizeUnit: String?
  foodNutrients[]:        → find by nutrientId:
    1008 = Energy (kcal)  → calories
    1003 = Protein (g)    → protein
    1005 = Carbohydrate   → carbs
    1004 = Total Fat (g)  → fat

**Food Detail + Serving Options**
GET /fdc/v1/food/{fdcId}?api_key={key}

Additional field: foodMeasures[] → user-friendly serving options
  disseminationText: String  → e.g. "1 cup", "1 tablespoon"
  gramWeight: Double         → gram equivalent
  Display in ServingSizePickerView for user to choose from

### Rate Limits
3,600 requests/hour on free tier — ample for personal use


---

## ANTHROPIC CLAUDE API

Base URL: https://api.anthropic.com/v1
Sign up: https://console.anthropic.com

### Required Headers
x-api-key: [your key from Keychain]
anthropic-version: 2023-06-01
Content-Type: application/json

### Request Body Structure
{
  "model": "claude-sonnet-4-6",
  "max_tokens": 1000,
  "system": "[system prompt here]",
  "messages": [
    {"role": "user", "content": "[user message]"}
  ]
}

For multi-turn chat, messages array contains the full history:
[
  {"role": "user", "content": "first message"},
  {"role": "assistant", "content": "first response"},
  {"role": "user", "content": "second message"}
]

### Response Path
response.content[0].text → the model's response string


---

## CLAUDE SYSTEM PROMPTS

These are production-ready. Copy them directly into ClaudeAPIService.swift.

---

### FOOD EXTRACTION PROMPT
Use for: converting user's natural language meal description into structured macros
max_tokens: 1000

```
You are a nutrition data extraction assistant. Your only job is to identify 
food items in the user's message and estimate their nutritional content.

Return ONLY a valid JSON object in exactly this format with no other text, 
no markdown formatting, no backticks, and no explanation:

{
  "items": [
    {
      "name": "descriptive food name",
      "estimated_calories": 0,
      "estimated_protein": 0,
      "estimated_carbs": 0,
      "estimated_fat": 0,
      "confidence": "low",
      "portion_description": "describe the portion"
    }
  ]
}

Rules:
- If no food is mentioned, return {"items": []}
- Use realistic average portions if size is not specified
- For restaurant food, use typical restaurant portions
- confidence is "low", "medium", or "high" based on how precisely the food was described
- All nutrient values are in grams except calories
- Round all values to nearest whole number
- Include every food item mentioned, even drinks and condiments
```

---

### NUTRITION COACH CHAT PROMPT  
Use for: answering nutrition questions with personalized context
max_tokens: 2000
Note: inject the [BRACKETED] values from AppState before sending

```
You are a personalized nutrition coach built into a fitness app. 
You have access to the user's current nutrition data and goals.

Current user data:
- Daily calorie target: [CALORIE_TARGET] calories
- Calories logged today: [CALORIES_LOGGED] cal ([CALORIES_REMAINING] remaining)
- Protein target: [PROTEIN_TARGET]g (logged: [PROTEIN_LOGGED]g)
- Carbs target: [CARBS_TARGET]g (logged: [CARBS_LOGGED]g)
- Fat target: [FAT_TARGET]g (logged: [FAT_LOGGED]g)
- Current goal: [GOAL_TYPE] (cut/bulk/maintain)
- Today's activity level: [EFFORT_LEVEL]
- Days tracked so far: [DAYS_TRACKED]

Guidelines for your responses:
- Be concise and practical — users are busy
- Always prioritize protein adequacy in your advice
- Don't be judgmental about food choices
- If asked about the learning engine, explain it simply: "The app watches 
  your weight trend over time and adjusts your targets to match how your 
  body actually responds"
- If the user describes eating something unlogged, gently remind them they 
  can log it via this chat
- Don't recommend extreme deficits or dangerous practices
- Keep responses under 150 words unless a detailed explanation is specifically requested
```

---

### DEXA SCAN PARSING PROMPT (V3 — save for later)
Use for: extracting body composition data from a DEXA scan report image or PDF
max_tokens: 1000

```
You are analyzing a DEXA body composition scan report. Extract the key 
measurements and return them as JSON only, no other text:

{
  "scan_date": "YYYY-MM-DD or null if not found",
  "total_weight_kg": 0,
  "lean_mass_kg": 0,
  "fat_mass_kg": 0,
  "body_fat_percentage": 0,
  "regional_data": {
    "left_arm_lean_kg": 0,
    "right_arm_lean_kg": 0,
    "left_leg_lean_kg": 0,
    "right_leg_lean_kg": 0,
    "trunk_lean_kg": 0
  },
  "bone_mineral_density": 0,
  "confidence": "high if all values found, medium if some missing, low if uncertain"
}

If a value cannot be found in the report, use null.
DEXA reports vary by provider — look for total lean mass, fat mass, and 
regional breakdown regardless of exact label formatting.
```

---

## SWIFT CODE TEMPLATES

### Making an Open Food Facts Barcode Call

```swift
func searchFood(query: String) async throws -> [FoodResult] {
    guard let appId = KeychainManager.load(key: Keys.usdaApiKey),
          let appKey = KeychainManager.load(key: Keys.usdaApiKey) else {
        throw FoodDatabaseError.unauthorized
    }
    
    var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/v2/search/instant")!
    components.queryItems = [
        URLQueryItem(name: "query", value: query),
        URLQueryItem(name: "branded", value: "true"),
        URLQueryItem(name: "common", value: "true"),
        URLQueryItem(name: "detailed", value: "true")
    ]
    
    var request = URLRequest(url: components.url!)
    // No auth headers — pass api_key as query param for USDA,
    // or nothing at all for Open Food Facts
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw FoodDatabaseError.networkError("Invalid response")
    }
    
    switch httpResponse.statusCode {
    case 200: break
    case 401: throw FoodDatabaseError.unauthorized
    case 404: return []
    case 429: throw FoodDatabaseError.rateLimited
    default: throw FoodDatabaseError.networkError("Status \(httpResponse.statusCode)")
    }
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    // decode and return results
}
```

### Making a Claude API Call

```swift
func extractFood(from message: String, context: DayContext) async -> [ExtractedFoodItem] {
    guard let apiKey = KeychainManager.load(key: Keys.anthropicApiKey) else {
        return []
    }
    
    let url = URL(string: "https://api.anthropic.com/v1/messages")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
        "model": "claude-sonnet-4-6",
        "max_tokens": 1000,
        "system": foodExtractionSystemPrompt,
        "messages": [["role": "user", "content": message]]
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    do {
        let (data, _) = try await URLSession.shared.data(for: request)
        // parse response.content[0].text
        // pass to FoodExtractionParser
        return []  // replace with actual parsing
    } catch {
        print("Claude API error: \(error)")
        return []  // never throw to caller — return empty on any error
    }
}
```

---

## SIMULATOR TEST DATA

Add this data to the iOS Simulator's Health app to test without real device:

**Body Weight entries** (to test learning engine):
Add 30+ daily entries with slight variation around a trend.
Example for someone in a slight cut: start at 185 lbs, decrease ~0.3 lbs/week
with day-to-day noise of ±1 lb.

**Heart Rate samples** (to test effort scoring):
Add samples at different BPMs throughout a day:
- Resting: 65-75 bpm for most of the day
- Workout window: 140-165 bpm for 45 min
This should produce .high effort level for that day.

**Active Energy** (to test effort fallback when no HR):
Add 350-450 active calories for a moderate workout day.

To add data: Open Simulator → Health app → Browse → 
tap each category → Add Data
