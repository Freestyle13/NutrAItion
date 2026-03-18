# PRODUCT SPEC — AI Nutrition & Fitness App
# The source of truth for what this app is and isn't.
# When in doubt about a product decision, check here first.
# =========================================================

## ELEVATOR PITCH

A nutrition tracker that learns your actual metabolism by watching
how your body responds to what you eat and how hard you train.
Unlike every other app that gives you a static calorie number and
never updates it, this one gets more accurate the longer you use it.

---

## THE PROBLEM WE'RE SOLVING

Every calorie tracking app has the same fatal flaw: they give you
a TDEE estimate on day one based on population averages and never
change it. But everyone's metabolism is different. Apple Watch
calorie burns are off by 20-40%. The "3,500 calories per pound"
rule doesn't hold for every body.

The result: people follow the math, don't get the results the
math predicted, blame themselves, and quit.

Our app doesn't ask you to trust the math. It watches what actually
happens to your body and corrects itself.

---

## TARGET USER (V1)

Primary: Someone who is already somewhat serious about diet and
fitness. Not a complete beginner. They've tried MyFitnessPal or
similar and found the static approach frustrating. They understand
macros. They weigh themselves regularly. They work out consistently
enough to have HealthKit data worth analyzing.

They are NOT: someone who needs to be taught what a calorie is.
Someone who is looking for meal plans or recipes.
Someone with a clinical eating disorder (not our use case to serve).

---

## CORE FEATURES — V1

### 1. Structured Food Logging
- Barcode scanner (precise, confidence: .precise)
- Text search via USDA FoodData Central (precise, confidence: .precise)
- Manual entry when database has no result (confidence: .manual) — never dead-end the user
- AI-assisted prefill on manual entry — Claude estimates macros so form is not blank
- Custom foods saved to personal library for reuse
- Non-negotiable: fast, low-friction, every food is loggable one way or another

### 2. Conversational Food Logging  
- Natural language via Claude AI (estimated, confidence: .estimated)
- For unplanned meals, cheat meals, social eating
- Low-judgment, forgiving interface
- Does NOT replace structured logging — supplements it

### 3. Custom Recipes
- Build multi-ingredient recipes from any food source (USDA, Open Food Facts, custom foods, other recipes)
- Set total servings — scale macros automatically when logging partial servings
- Built for meal prep: log 2 of 6 servings of your weekly chicken rice in 2 taps
- Recently used recipes surface at top of search — minimal friction for repeat meals
- Editing a recipe creates a new version to preserve historical log accuracy

### 5. HealthKit Integration
- Reads activity data as an effort signal (not ground truth calories)
- Reads weight for learning engine input
- Passive — no manual input required from user

### 4. Adaptive TDEE Learning Engine
- Watches weight trend vs predicted trend
- Makes small weekly adjustments to calorie targets
- Shows users why targets changed (transparency builds trust)
- Conservative — never makes dramatic swings

### 5. Dashboard
- Daily macro progress (protein prioritized visually)
- Today's effort level
- Quick-add access
- Glanceable in under 3 seconds

---

## EXPLICITLY NOT IN V1

These are good ideas. They are not V1.

- Workout tracking / exercise logging
- Meal planning or recipe suggestions
- Social features / sharing
- Android version
- Web app
- Notifications beyond engine update alerts
- Water tracking
- Sleep tracking
- DEXA scan integration (V3)
- Backend sync / multi-device (V2)
- Apple Watch app
- Widgets

Saying no to these is how V1 gets finished.

---

## UX PRINCIPLES

**Transparent AI** — when the AI estimates something, say so.
The .estimated confidence badge exists for this reason. Users
should never be surprised that the AI guessed.

**Conservative by default** — the learning engine makes small
nudges, not dramatic swings. Users should feel like the app is
cautious and trustworthy, not erratic.

**Glanceable dashboard** — the home screen should answer "how
am I doing today?" in under 3 seconds without scrolling.

**Low friction logging** — every tap between "I want to log food"
and "food is logged" is a user we'll lose. Keep the logging flow
as short as possible.

**Never blame the user** — if the engine adjusts targets, the
message is "we learned something about your metabolism" not
"you weren't losing weight fast enough."

---

## MACRO PHILOSOPHY (IMPORTANT)

Protein is king. This is non-negotiable product philosophy.

The app sets protein first, always hits the protein floor, and
flexes carbs and fat around it. The dashboard makes protein the
most prominent macro visually. The AI trainer always prioritizes
protein adequacy in its advice.

This is scientifically defensible (protein has the highest
thermic effect, most muscle-preserving during a cut) and it
differentiates us from apps that treat all macros equally.

---

## THE CONFIDENCE SYSTEM (CRITICAL CONCEPT)

Every food entry has a confidence level. This is not just a UI
label — it directly affects the learning engine's calculations.

.precise (barcode, search): engine weights at 1.0x
.estimated (AI chat): engine weights at 0.7x

Why: if a user has a 1,200 calorie cheat meal and logs it via
chat as "a big dinner", the AI might estimate 800 calories.
That 400 calorie gap would corrupt the TDEE calculation if
treated as ground truth. The 0.7x weighting acknowledges the
uncertainty without ignoring the data entirely.

This system is the reason the conversational logger doesn't
"break" the learning engine. It's a core architectural decision.

---

## MONETIZATION (FUTURE — NOT V1)

Subscription model: ~$12.99/month or $79.99/year.

The learning engine is the reason people pay month after month —
it gets more valuable over time, which is the ideal subscription
mechanic. Unlike a static app where you've "seen everything" by
week 2, this one is still improving in month 6.

Free tier possibility: logging works, learning engine disabled.
Paid: full learning engine, AI chat, trends.

Do not think about monetization during V1. Build something you
want to use first.

---

## SUCCESS METRICS FOR V1 (PERSONAL BETA)

Before showing this to anyone else, it should pass these tests:

1. You use it daily for 4+ weeks without it feeling like a chore
2. The macro targets feel accurate to your body after 4 weeks
3. The AI chat correctly estimates at least 80% of meals you describe
4. You have not experienced a single crash
5. The learning engine has made at least one adjustment that felt
   correct (i.e., the new targets feel more right than the old ones)

If all five are true, it's ready for other people.
