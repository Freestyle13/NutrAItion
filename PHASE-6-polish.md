# PHASE 6 — Trends, Onboarding, Settings & TestFlight
# Final polish before shipping to beta users
# Complete Phase 5 before starting this.
# =========================================================

=========================================================
## PROMPT 6.1 — Trends View
=========================================================

---
Create the Trends view showing weight history and engine activity.
Place in Views/Trends/

**Views/Trends/WeightChartView.swift**
A line chart using Swift Charts framework showing:
- X axis: dates (last 30 days)
- Y axis: weight in lbs (convert from kg using × 2.2046)
- Two series:
  1. Raw daily weigh-ins: small circle marks, light gray, semi-transparent
  2. 7-day smoothed average: solid line, brand color, more prominent
- Optional: a "predicted trend" dashed line based on current TDEE and goal
  (shows what the engine expects if the user stays on track)
- Tap a data point to see the date and exact weight in a tooltip

**Views/Trends/TDEEHistoryView.swift**
A simple chart or list showing how the TDEE estimate has changed over time:
- Bar chart or step line chart showing tdeeEstimate per week
- Each bar/point tappable to show the TDEEAdjustmentHistory.reasoning string
- Helps users understand why the engine changed their targets

**Views/Trends/TrendsView.swift**
The full trends screen:
- Segment picker at top: "Weight" / "TDEE" / "Macros"
- Weight segment: WeightChartView + summary stats (total change, weekly avg change)
- TDEE segment: TDEEHistoryView + current estimate + weeks of data used
- Macros segment: Stacked bar chart of daily macro breakdown for last 7 days
- Empty state if <7 days of data: "Keep logging — your trends will appear here"

For Java context: Swift Charts is like JFreeChart but declarative.
You describe what the chart should look like, not how to draw it.
Chart { ForEach(data) { point in LineMark(x: .value("Date", point.date), y: .value("Weight", point.weight)) } }
---

=========================================================
## PROMPT 6.2 — Onboarding Flow
=========================================================

---
Create the onboarding flow for new users.
Place in Views/Onboarding/

Design goal: under 5 screens, get to the dashboard fast.
Collect only what's needed to set up the initial TDEE estimate.

**Screen 1 — Welcome (OnboardingWelcomeView.swift)**
- App name and tagline
- Brief value prop: "Learns your metabolism. Gets smarter every week."
- "Get Started" button

**Screen 2 — About You (OnboardingProfileView.swift)**
- Age (number wheel or stepper)
- Biological sex (segmented: Male / Female / Other)
- Current weight (lbs — convert to kg internally)
- Height (ft/in — convert to cm internally)
All required. No skip option.

**Screen 3 — Your Goal (OnboardingGoalView.swift)**  
- Three large cards to tap: 
  🔥 Lose Fat (cut — 400 cal deficit)
  💪 Build Muscle (bulk — 300 cal surplus)
  ⚖️ Maintain (maintain — at TDEE)
- Brief description under each card

**Screen 4 — HealthKit Permissions (OnboardingHealthKitView.swift)**
- Explains what data will be read and why
- "Connect Apple Health" button → triggers HealthKit permission dialog
- "Skip for now" option — app works without HealthKit, just no effort scoring
- Show the 5 data types being requested with plain English explanation

**Screen 5 — All Set (OnboardingCompleteView.swift)**
- Confirmation + initial macro targets computed from Mifflin-St Jeor formula
- Show: "Your starting targets: X cal · Xg protein · Xg carbs · Xg fat"
- "Start Tracking" button → sets UserProfile in SwiftData, navigates to Dashboard

**OnboardingFlow.swift**
Manages the step navigation. On completion:
1. Create UserProfile with entered data
2. Calculate initial TDEE using Mifflin-St Jeor:
   Men: (10 × weightKg) + (6.25 × heightCm) - (5 × age) + 5
   Women: (10 × weightKg) + (6.25 × heightCm) - (5 × age) - 161
   Multiply by 1.4 (moderate activity assumption — engine will correct this)
3. Save to SwiftData
4. Set AppState.isOnboardingComplete = true
---

=========================================================
## PROMPT 6.3 — Settings View
=========================================================

---
Create the Settings screen.
Place in Views/Settings/SettingsView.swift

Sections:

**Profile**
- Edit age, weight, height (tap to edit inline)
- Change goal type (cut/bulk/maintain)
- Changes trigger MacroTargets recalculation

**My Targets (read-only, engine-managed)**
- Current TDEE estimate: X calories
- Daily targets: protein / carbs / fat
- Last updated: [date]
- "How is this calculated?" info button → shows explanation sheet

**API Keys**
- Nutritionix App ID (masked, tap to edit)
- Nutritionix App Key (masked, tap to edit)
- Anthropic API Key (masked, tap to edit)
- Each saves to Keychain on confirm
- Test button for each: makes a simple API call to verify the key works

**Data**
- "Export my data" → generates a CSV of food log history (nice to have)
- "Reset learning engine" → clears TDEEAdjustmentHistory, resets estimate to formula

**About**
- App version
- Link to privacy policy (placeholder URL for now)
---

=========================================================
## PROMPT 6.4 — TestFlight Preparation
=========================================================

---
Prepare the app for TestFlight beta distribution.

Create a pre-launch checklist as comments in AppEntry.swift:
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

Also add all required Info.plist privacy usage descriptions with 
user-friendly explanations (Apple requires these — app will be rejected without them):
- NSHealthShareUsageDescription: "Used to read your activity data and weight to personalize your nutrition targets."
- NSHealthUpdateUsageDescription: "Used to save your weight entries to Apple Health."
- NSCameraUsageDescription: "Used to scan food barcodes for quick logging."

For the App icon, a placeholder SF Symbol based icon is fine for beta.
Use the Asset Catalog in Xcode to add a simple 1024×1024 app icon image.
---

=========================================================
## FINAL CHECKLIST BEFORE FIRST TESTFLIGHT BUILD

Code quality:
✅ All Phase 1-6 prompts implemented
✅ All Engine/ unit tests passing
✅ No force unwraps (!) in production code paths
✅ No TODO/FIXME comments on critical paths
✅ API keys in Keychain, not source

Functionality:
✅ Onboarding completes and creates UserProfile
✅ Can log food via barcode, search, and AI chat
✅ Dashboard updates in real-time after logging
✅ HealthKit syncs weight and activity
✅ App works without HealthKit (graceful degradation)
✅ Chat logger correctly tags entries as .estimated
✅ Settings screen saves API keys to Keychain

Build:
✅ No build warnings (fix all yellow warnings)
✅ App runs on iOS 17 simulator without crashes
✅ Tested on real iPhone if possible

To submit to TestFlight:
1. In Xcode: Product → Archive
2. Distribute App → App Store Connect → Upload
3. In App Store Connect: go to TestFlight tab
4. Add your own email as internal tester
5. Install TestFlight app on iPhone, accept invite

You're done with V1. 🎉
