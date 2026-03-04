# PHASE 2 — Effort Score Engine
# Pure logic classes — fully testable, no UI
# Complete Phase 1 before starting this.
# =========================================================

=========================================================
## PROMPT 2.1 — Effort Score Calculator
=========================================================

---
Create the EffortScoreCalculator in Engine/EffortScoreCalculator.swift

This is a pure logic class — no HealthKit calls, no SwiftData, no UI.
All data is passed in as parameters so it's fully unit testable.

The calculator converts raw HealthKit heart rate samples + active calories
into a daily EffortLevel enum.

**Algorithm:**

1. Calculate the user's estimated max heart rate: 220 - age
2. For each HR sample, determine which zone it falls in:
   - Zone 1: <60% HRmax (very light)
   - Zone 2: 60-70% HRmax (light/fat burn)  
   - Zone 3: 70-80% HRmax (aerobic)
   - Zone 4: 80-90% HRmax (threshold)
   - Zone 5: >90% HRmax (max effort)
3. Calculate weighted zone score:
   weightedScore = (z1_minutes × 0.3) + (z2_minutes × 0.5) + 
                   (z3_minutes × 0.7) + (z4_minutes × 0.9) + (z5_minutes × 1.0)
4. Normalize by total active minutes to get 0-100 score
5. Bucket into EffortLevel:
   - 0-15: .rest
   - 16-35: .low
   - 36-60: .moderate  
   - 61-80: .high
   - 81-100: .veryHigh

If no HR samples available (user doesn't wear Apple Watch), fall back to
active calories only:
   - 0-50 cal: .rest
   - 51-200 cal: .low
   - 201-400 cal: .moderate
   - 401-600 cal: .high
   - 601+ cal: .veryHigh

**Calorie adjustment table** (default population values, will be personalized later):
   - .rest: -200 cal from TDEE
   - .low: -100 cal
   - .moderate: 0 cal (baseline day)
   - .high: +150 cal
   - .veryHigh: +300 cal

Create an EffortScoreCalculator struct with:
- func calculate(heartRateSamples: [HKQuantitySample], activeCalories: Double, age: Int) -> EffortLevel
- func calorieAdjustment(for level: EffortLevel, multipliers: [String: Double]?) -> Double
  (uses custom multipliers if provided, otherwise defaults above)
- private func zoneDistribution(samples: [HKQuantitySample], maxHR: Double) -> ZoneDistribution

Also create a ZoneDistribution struct to hold minutes per zone.

For Java context: This is a pure utility class, like a static helper in Java.
Struct in Swift = class with value semantics, passed by copy not reference.
---

=========================================================
## PROMPT 2.2 — Effort Score Unit Tests  
=========================================================

---
Create comprehensive unit tests for EffortScoreCalculator.
Place in EngineTests/EffortScoreCalculatorTests.swift

Use XCTest framework (Swift's equivalent of JUnit).

Write tests for these scenarios:

1. test_calculate_noHRSamples_lowCalories_returnsRest()
   - 0 HR samples, 30 active calories → .rest

2. test_calculate_noHRSamples_highCalories_returnsVeryHigh()
   - 0 HR samples, 700 active calories → .veryHigh

3. test_calculate_allZone4HR_returnsHigh()
   - Create mock HKQuantitySamples all in zone 4 (85% of HRmax for age 30)
   - Should return .high

4. test_calculate_mixedZones_returnsModerate()
   - Equal mix of zone 1 and zone 3 samples
   - Should return .moderate

5. test_calorieAdjustment_rest_returnsNegative200()
   - .rest with nil multipliers → -200.0

6. test_calorieAdjustment_customMultipliers_usesCustomValues()
   - Pass custom multipliers dict, verify custom value is used

Helper: create a private func makeMockHRSample(bpm: Double, date: Date) -> HKQuantitySample
to reduce boilerplate in tests.

For Java context: XCTest is like JUnit. func testXxx() methods are 
automatically discovered and run. XCTAssertEqual is assertEquals().
XCTAssertTrue is assertTrue(). No @Test annotation needed.
---

=========================================================
## PROMPT 2.3 — Weight Smoother
=========================================================

---
Create WeightSmoother in Engine/WeightSmoother.swift

Pure struct, no external dependencies. 

Implements 7-day rolling average smoothing for body weight data.

struct WeightSmoother with:

- func smooth(entries: [(date: Date, weightKg: Double)]) -> [(date: Date, smoothedKg: Double)]
  Takes raw weight entries sorted by date, returns smoothed values.
  For each day, averages all weights within the trailing 7-day window.
  If a day has no weight entry, interpolate linearly between nearest measurements.
  If fewer than 3 data points exist in the window, return the raw value (not enough to smooth).

- func rollingAverage(for date: Date, in entries: [(date: Date, weightKg: Double)], windowDays: Int = 7) -> Double?
  Returns the smoothed weight for a specific date. Returns nil if insufficient data.

- func weightDelta(from startDate: Date, to endDate: Date, in smoothedEntries: [(date: Date, smoothedKg: Double)]) -> Double?
  Returns the change in smoothed weight between two dates. Nil if dates not in range.

Also write unit tests in EngineTests/WeightSmootherTests.swift:
1. test_smooth_sevenConsistentEntries_returnsCorrectAverage()
2. test_smooth_missingDays_interpolatesCorrectly()
3. test_smooth_fewerThanThreePoints_returnsRawValue()
4. test_weightDelta_correctlyCalculatesChange()
---

=========================================================
## PROMPT 2.4 — Macro Target Calculator  
=========================================================

---
Create MacroTargetCalculator in Engine/MacroTargetCalculator.swift

Pure struct — no external dependencies. 
Calculates daily macro targets given user parameters.

**Protein calculation:**
- Without DEXA (leanMassKg is nil): protein = bodyWeightKg × 2.2 × 0.85  (0.85g per lb)
- With DEXA (leanMassKg provided): protein = leanMassKg × 2.2 × 1.0  (1.0g per lb lean mass)
- Protein is always the floor — never reduced to hit calorie target

**Calorie target:**
- .cut: tdee - 400 (moderate deficit, sustainable)
- .bulk: tdee + 300 (lean bulk surplus)
- .maintain: tdee

**Fat calculation:**
- fat grams = (calorieTarget × 0.25) / 9  (25% of calories, 9 cal per gram of fat)

**Carb calculation:**
- proteinCalories = proteinGrams × 4
- fatCalories = fatGrams × 9
- carbCalories = calorieTarget - proteinCalories - fatCalories
- carbGrams = carbCalories / 4  (4 cal per gram of carbs)
- If carbGrams < 50, flag a warning (very low carb — may want to adjust)

struct MacroTargetCalculator with:
- func calculate(tdee: Double, goalType: GoalType, bodyWeightKg: Double, leanMassKg: Double?) -> MacroTargets

Write tests in EngineTests/MacroTargetCalculatorTests.swift:
1. test_calculate_cut_reducesCaloriesBy400()
2. test_calculate_bulk_increasesCaloriesBy300()
3. test_calculate_withDEXA_usesLeanMassForProtein()
4. test_calculate_proteinNeverReducedBelowFloor()
5. test_calculate_macrosSumToTotalCalories()  ← this is a great sanity check test

For Java context: (protein × 4) + (fat × 9) + (carbs × 4) should equal 
total calories — if this test fails, there's a calculation bug.
---

=========================================================
## AFTER PHASE 2

Checkpoint:
✅ All Engine/ classes compile
✅ All unit tests pass (green in Xcode test navigator)
✅ No HealthKit/SwiftData/networking code inside Engine/
✅ EffortScoreCalculator, WeightSmoother, MacroTargetCalculator all tested

Run tests: Cmd+U in Xcode, or from Cursor terminal: 
xcodebuild test -scheme [YourAppName] -destination 'platform=iOS Simulator,name=iPhone 16'

Next: Phase 3 — Nutrition Logging (Barcode + Search)
