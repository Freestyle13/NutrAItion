# PHASE 7 — Visual Design Polish & App Icon
# Run this after Phase 6 (TestFlight prep) is complete.
# The app should be fully functional before touching design.
# =========================================================

# DESIGN SYSTEM REFERENCE

All colors, spacing, and component patterns for NutrAltion.
Apply these consistently across every view in the app.

## Color Tokens

```swift
// Add to a file: Utilities/DesignSystem.swift

extension Color {
    // Backgrounds
    static let appBackground   = Color(hex: "#14142A")  // main screen bg
    static let cardBackground  = Color(hex: "#252545")  // all cards + entries
    static let deepBackground  = Color(hex: "#1A1A32")  // tab bar, sheets
    static let ringTrack       = Color(hex: "#2E2E58")  // unfilled ring arc

    // Borders
    static let cardBorder      = Color(hex: "#363660")  // card stroke
    static let tabBorder       = Color(hex: "#2E2E52")  // tab bar top edge

    // Text
    static let textPrimary     = Color.white
    static let textMuted       = Color(hex: "#9898C0")  // labels, secondary
    static let textDim         = Color(hex: "#6868A0")  // timestamps, subtext
    static let textGhost       = Color(hex: "#484878")  // inactive tab labels

    // Accent
    static let accentPurple    = Color(hex: "#7B7BE8")  // primary accent, rings

    // Macros — consistent across ALL views
    static let macroProtein    = Color(hex: "#3DDC84")  // green
    static let macroCarbs      = Color(hex: "#FF9500")  // orange
    static let macroFat        = Color(hex: "#FF6B9D")  // pink

    // Effort levels
    static let effortRest      = Color(hex: "#6868A0")
    static let effortLow       = Color(hex: "#4A9EFF")
    static let effortModerate  = Color(hex: "#3DDC84")
    static let effortHigh      = Color(hex: "#FF9500")
    static let effortVeryHigh  = Color(hex: "#FF4444")

    // Confidence badges
    static let badgeAI         = Color(hex: "#FF9500")  // .estimated
    static let badgeRecipe     = Color(hex: "#4A9EFF")  // .recipe

    // Icon tint backgrounds (for food entry icons)
    static let iconBgGreen     = Color(hex: "#1E3828")
    static let iconBgPurple    = Color(hex: "#261E38")
    static let iconBgOrange    = Color(hex: "#38281A")
    static let iconBgBlue      = Color(hex: "#081018")
}

// Hex initializer — add to Utilities/Extensions.swift
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

## Spacing & Shape Tokens

```swift
extension CGFloat {
    static let radiusCard    : CGFloat = 18   // macro cards, entry rows
    static let radiusSmall   : CGFloat = 10   // food entry icon background
    static let radiusBadge   : CGFloat = 4    // AI est. / Recipe badges
    static let radiusPhone   : CGFloat = 44   // not used in app, reference only

    static let cardPaddingH  : CGFloat = 14
    static let cardPaddingV  : CGFloat = 12
    static let screenPadding : CGFloat = 20   // left/right inset on all screens
    static let cardGap       : CGFloat = 10   // gap between macro cards in row
    static let sectionGap    : CGFloat = 20   // between dashboard sections
}
```

## Typography Scale

```swift
extension Font {
    static let screenTitle   = Font.system(size: 24, weight: .bold)
    static let sectionTitle  = Font.system(size: 15, weight: .semibold)
    static let cardValue     = Font.system(size: 13, weight: .semibold)
    static let cardLabel     = Font.system(size: 10, weight: .regular)
    static let entryName     = Font.system(size: 13, weight: .medium)
    static let entryMeta     = Font.system(size: 11, weight: .regular)
    static let macroRingVal  = Font.system(size: 11, weight: .bold)
    static let calRingVal    = Font.system(size: 28, weight: .bold)
    static let calRingLabel  = Font.system(size: 11, weight: .regular)
    static let badgeText     = Font.system(size: 9,  weight: .medium)
    static let greeting      = Font.system(size: 13, weight: .regular)
}
```

=========================================================
## PROMPT 7.1 — Global App Styling
=========================================================

---
Apply the NutrAltion design system globally.
Start with Utilities/DesignSystem.swift.

Create Utilities/DesignSystem.swift containing:
- All Color extensions from the design tokens above
- All CGFloat spacing tokens
- All Font tokens
- The Color(hex:) initializer

Then update App/AppEntry.swift to set the global app background:

In the main WindowGroup, apply:
.preferredColorScheme(.dark)

This locks the app to dark mode — NutrAltion is a dark-only app.
Never show light mode. This also means you can use the hardcoded
hex colors from DesignSystem.swift without worrying about
light/dark mode switching.

Also add a custom UITabBarAppearance in AppEntry to style the tab bar:
- Background color: Color.deepBackground (#1A1A32)
- Border/shadow: top separator in Color.tabBorder (#2E2E52)
- Unselected item: Color.textGhost (#484878)
- Selected item: Color.accentPurple (#7B7BE8)

For Java context: .preferredColorScheme(.dark) is like setting a
global theme in Android — one call at the root, applies everywhere.
---

=========================================================
## PROMPT 7.2 — Dashboard Visual Polish
=========================================================

---
Apply the design system to DashboardView and its components.
Reference the finalized design: dark bg #14142A, cards #252545,
purple accent #7B7BE8, macro colors green/orange/pink.

**MacroRingView updates:**
- Ring track color: use tinted color matching the macro
  Protein track: #1E3830 (dark green tint)
  Carbs track:   #382A18 (dark orange tint)
  Fat track:     #38182E (dark pink tint)
  Calorie track: #2E2E58 (dark purple tint)
- Ring stroke color: macroProtein / macroCarbs / macroFat / accentPurple
- stroke-linecap: .round on all arcs
- Center value: Font.macroRingVal, Color.textPrimary
- Label below: Font.cardLabel, Color.textMuted, ALL CAPS

**DashboardView layout:**
- Screen background: Color.appBackground
- Greeting line: Font.greeting, Color.textMuted
- Name line: Font.screenTitle, Color.textPrimary
- Date line: Font.entryMeta, Color.textDim
- Calorie ring: 180pt diameter, 14pt stroke width
  Center: remaining calories in Font.calRingVal
  Label "REMAINING": Font.calRingLabel, Color.textMuted
  Sub-label "of X cal": Font.entryMeta, Color.textDim
- Macro ring row: 3 equal cards, gap 10pt, card bg Color.cardBackground,
  border 1pt Color.cardBorder, corner radius .radiusCard
- Effort + weight row: same card treatment as macro cards
  Effort dot: 10pt circle in effort level color
  Weight delta: Color.macroProtein (green) if negative (losing weight on cut)

**Recent entries section:**
- Section header: Font.sectionTitle / "See all" in Color.accentPurple
- Each entry: Color.cardBackground, border Color.cardBorder, radius 16pt
- Food icon: 36x36pt, radius .radiusSmall, tinted background
- Entry name: Font.entryName, Color.textPrimary
- Timestamp: Font.entryMeta, Color.textDim
- AI badge: bg #32220A, border #4A3310, text Color.badgeAI, Font.badgeText
- Recipe badge: bg #0D1A2A, border #0A2545, text Color.badgeRecipe, Font.badgeText
- Calories right: Font.cardValue, Color.textPrimary
- Macro string (32p · 36c · 14f): Font.entryMeta, Color.textDim
---

=========================================================
## PROMPT 7.3 — Food Log Visual Polish
=========================================================

---
Apply design system to FoodLogView and the macro summary bar.

**MacroSummaryBar:**
- Container: Color.cardBackground, border Color.cardBorder, radius .radiusCard
  Padding: 14pt vertical, 16pt horizontal
- Four columns: calories (purple), protein (green), carbs (orange), fat (pink)
- Value: Font.cardValue in respective macro color
- Label: Font.cardLabel, Color.textMuted, ALL CAPS
- Sub-label "of Xg": 9pt, Color.textDim
- Below the four columns: two stacked progress bars
  Top bar: full-width calorie bar, Color.accentPurple fill
  Bottom bar: three equal-width bars side by side for P/C/F
  All bars: 6pt height, radius 3pt, track Color.ringTrack

**Meal section headers:**
- Meal title: 11pt, ALL CAPS, letter-spacing 0.08em, Color.textMuted
- Total calories right: 11pt, Color.textDim

**Entry rows:**
- Same card treatment as dashboard recent entries
- Swipe-to-delete: red destructive action, confirm not required
- Long press: show context menu with "Copy to today" option

**FAB (+) button:**
- 52pt circle, Color.accentPurple fill
- White + icon, 22pt, weight .medium
- Position: bottom trailing, 20pt from edges
- On tap: show ActionSheet with options styled in dark sheet appearance
---

=========================================================
## PROMPT 7.4 — Chat Logger Visual Polish
=========================================================

---
Apply design system to ChatLoggerView.

**Message bubbles:**
- User messages: Color.accentPurple background, white text,
  radius 18pt with bottom-right corner flattened to 4pt
- AI messages: Color.cardBackground, Color.textPrimary text,
  border Color.cardBorder, radius 18pt with bottom-left corner 4pt
- Timestamp on long press: Color.textDim, Font.entryMeta

**Input bar:**
- Background: Color.deepBackground
- Top separator: Color.tabBorder
- TextField: Color.cardBackground, radius 22pt, Color.textPrimary
  Placeholder: Color.textDim
- Send button: Color.accentPurple fill circle when text entered,
  Color.cardBorder fill when empty

**Typing indicator (while waiting for AI response):**
- Three dots in Color.textMuted, pulsing animation
- Inside an AI-style bubble

**Food confirmation card (after extraction):**
- Card: Color.cardBackground, border Color.cardBorder, radius .radiusCard
- Title: "I found these items" in Font.sectionTitle, Color.textPrimary
- Each item row: name in Color.textPrimary, macros in Color.textDim
- "Looks Good" button: Color.accentPurple fill, white text, radius 12pt
- "Start Over" button: Color.cardBackground, Color.cardBorder border
---

=========================================================
## PROMPT 7.5 — Trends Visual Polish
=========================================================

---
Apply design system to TrendsView and its chart components.

**Weight chart (Swift Charts):**
- Chart background: Color.appBackground
- Raw weight dots: Color.textGhost, 4pt diameter
- Smoothed average line: Color.accentPurple, 2.5pt stroke
- Predicted trend line: Color.accentPurple, dashed, 1.5pt, opacity 0.5
- X axis labels: Font.entryMeta, Color.textDim
- Y axis labels: Font.entryMeta, Color.textDim
- Grid lines: Color.cardBorder, 0.5pt, dashed
- Selected data point callout: Color.cardBackground card with
  date + weight in Color.textPrimary

**TDEE history:**
- Bar chart: Color.accentPurple fill, Color.cardBorder stroke
- Adjustment delta: Color.macroProtein if positive (TDEE increased),
  Color.macroFat if negative
- Reasoning callout on tap: Color.cardBackground sheet

**Segment picker:**
- Background: Color.cardBackground
- Selected: Color.accentPurple
- Unselected text: Color.textMuted

**Empty state:**
- Illustration: concentric rings in Color.ringTrack (very subtle)
- Message: Color.textMuted, centered
---

=========================================================
## PROMPT 7.6 — App Icon Implementation
=========================================================

---
Implement the NutrAltion app icon in Xcode.

The chosen design is the "N + macros" icon (design 10):
- Background: #14142A (app background color)
- Inner rounded rect: #252545 with #7B7BE8 border, 2.5pt stroke
- Large N: #7B7BE8, bold, centered
- Three macro bars below the N:
  Left bar: #3DDC84 (protein green)
  Middle bar: #FF9500 (carbs orange)
  Right bar: #FF6B9D (fat pink)

**Step 1 — Create the icon as SVG:**

Create a file at /tmp/nutrAltion-icon.svg with this content:

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#14142A"/>
  <rect x="112" y="112" width="800" height="800" rx="180"
    fill="#252545" stroke="#7B7BE8" stroke-width="24"/>
  <text x="512" y="580"
    font-family="-apple-system, SF Pro Display, Helvetica Neue, sans-serif"
    font-size="420" font-weight="700"
    fill="#7B7BE8" text-anchor="middle">N</text>
  <rect x="210" y="750" width="175" height="46" rx="23" fill="#3DDC84"/>
  <rect x="425" y="750" width="175" height="46" rx="23" fill="#FF9500"/>
  <rect x="640" y="750" width="175" height="46" rx="23" fill="#FF6B9D"/>
</svg>

**Step 2 — Convert to PNG at required sizes:**
Run in Terminal on Mac mini:

Open the SVG in a browser → take a screenshot at full size → use
Preview.app to export as PNG, or use the command line:

If you have Homebrew's librsvg installed:
  rsvg-convert -w 1024 -h 1024 nutrAltion-icon.svg -o nutrAltion-icon-1024.png

Otherwise use Preview: open SVG → Export As PNG at 1024×1024.

**Step 3 — Add to Xcode:**
1. In Xcode, open Assets.xcassets
2. Click AppIcon
3. Drag your 1024×1024 PNG into the "App Store" (1024pt 1x) slot
4. Xcode will auto-fill all required sizes from the single image
   IF you have the "Single Size" option selected in the AppIcon settings
   (Inspector panel → Devices → check "iPhone" → Scales → "Single Size")
5. Build and run — the icon appears on the simulator home screen

**Alternative — generate all sizes with a script:**
If you want explicit sizes for older device support, run in Terminal:

for size in 20 29 40 58 60 76 80 87 120 152 167 180 1024; do
  rsvg-convert -w $size -h $size nutrAltion-icon.svg -o icon-${size}.png
done

Then drag each PNG into the corresponding AppIcon slot in Xcode.

Note: The text rendering in rsvg-convert may differ slightly from
browser rendering for the N letterform. Preview both and use whichever
looks crisper at small sizes.
---

=========================================================
## PROMPT 7.7 — Launch Screen
=========================================================

---
Create a simple launch screen that matches the app's design.

In Xcode:
1. Select your target → Info tab → Launch Screen
   Xcode 15+ uses LaunchScreen.storyboard by default

Open LaunchScreen.storyboard and configure:
- Background color: #14142A (set as a named color in Assets.xcassets,
  call it "AppBackground")
- Center: the app icon image (the N + macros design, 120x120pt)
- Below icon: app name "NutrAltion" in a light purple (#9898C0),
  SF Pro Display, 17pt, weight regular

This gives a clean, branded launch screen that transitions naturally
into the app without a jarring white flash.

Alternatively, use the SwiftUI launch screen approach:
Add to Info.plist:
  UILaunchScreen:
    UIColorName: "AppBackground"
    UIImageName: "AppIcon"  (uses your app icon automatically)

This is simpler and requires no storyboard editing.
---

=========================================================
## PROMPT 7.8 — Micro-interactions & Animation Polish
=========================================================

---
Add subtle animations that make the app feel premium.

Apply these animations across the app:

**Ring fill animation (dashboard + macro cards):**
When the dashboard loads OR when a new food entry is logged,
animate the ring arcs from 0 to their current value.
Use withAnimation(.easeOut(duration: 0.8)) on the ring's
strokeDashoffset value via a @State animationProgress variable.

In SwiftUI:
.onAppear {
  withAnimation(.easeOut(duration: 0.8)) {
    animationProgress = actualProgress
  }
}

**Entry logging confirmation:**
When a FoodEntry is saved, briefly scale the macro bars in the
summary bar with a spring animation:
.scaleEffect(justLogged ? 1.04 : 1.0)
.animation(.spring(response: 0.3, dampingFraction: 0.6), value: justLogged)

**Tab switching:**
SwiftUI's TabView handles this natively — no changes needed.

**Sheet presentation:**
All sheets (food search, manual entry, recipe builder) use
.presentationDetents([.large]) for full-screen feel
and .presentationDragIndicator(.visible) for the grab handle.

**Button press states:**
All primary buttons (.accentPurple fill) should have:
.scaleEffect(isPressed ? 0.97 : 1.0)
.animation(.easeOut(duration: 0.1), value: isPressed)

DO NOT add animations to:
- List rows (already handled by SwiftUI)
- Navigation transitions (system handles these)
- Loading states (ProgressView is sufficient)

Keep animations subtle. The goal is responsiveness, not theatrics.
---

=========================================================
## AFTER PHASE 7

Final visual checklist before sharing with anyone:
✅ App is locked to dark mode (.preferredColorScheme(.dark))
✅ All screens use Color.appBackground (#14142A)
✅ All cards use Color.cardBackground (#252545) with cardBorder
✅ Macro colors are consistent: green=protein, orange=carbs, pink=fat
✅ Purple accent used consistently for primary actions and active states
✅ App icon appears correctly on simulator home screen
✅ Launch screen matches app colors (no white flash)
✅ Ring fill animates on dashboard load
✅ AI est. and Recipe badges visible on relevant food entries
✅ Tab bar styled correctly (deep bg, purple active state)
✅ No default blue tint remaining anywhere in the app

Visual QA — run through every screen and check:
- Does it look like the mockup?
- Is there any default SwiftUI blue anywhere? (Replace with accentPurple)
- Are there any white or light backgrounds? (Replace with appBackground)
- Do all cards have the border? (1pt cardBorder)
- Is text readable everywhere? (Check textMuted and textDim against card bg)

Commit:
  git add .
  git commit -m "Phase 7: Design polish, app icon, launch screen"
  git push

You're done. Ship it.
