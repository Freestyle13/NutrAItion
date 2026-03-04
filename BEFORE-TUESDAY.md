# THINGS TO DO BEFORE TUESDAY
# Everything you can accomplish on Windows while waiting
# for the Mac mini. Ordered by priority.
# =========================================================

## PRIORITY 1 — ACCOUNT SETUP (Do today, ~45 min)

These take time to activate and you don't want to be waiting
for email confirmations when you're in a flow state on Tuesday.

### Anthropic API Account
1. Go to console.anthropic.com
2. Create account with your email
3. Go to Billing → Add $10-20 credit (this lasts a long time)
4. Go to API Keys → Create Key → name it "nutrition-app-dev"
5. COPY THE KEY NOW — you only see it once
6. Paste it somewhere safe (password manager, not a text file)

### Nutritionix API Account
1. Go to developer.nutritionix.com
2. Sign up for free account
3. Create an application (name it anything)
4. Copy your App ID and App Key
5. Save them alongside your Anthropic key

### GitHub Account (if you don't have one)
1. github.com → Sign up (free)
2. Create a new private repository
3. Name suggestion: [your-app-name]-ios
4. Initialize with a README

### GitHub Desktop (Windows)
1. desktop.github.com → Download for Windows
2. Sign in with your GitHub account
3. Clone your new repo to a local folder on Windows

---

## PRIORITY 2 — SWIFT BASICS (~4-5 hours over the weekend)

Go to: hackingwithswift.com/100swiftui

Complete Days 1-15. These cover:
- Day 1-4: Variables, strings, numbers, booleans
- Day 5-8: Conditions, loops, functions
- Day 9-12: Closures, structs, classes
- Day 13-15: Optionals (the most important Swift concept)

You do NOT need to complete the SwiftUI parts (Days 16+) before
Tuesday. The language fundamentals are what matters.

Estimated time: 30-45 min per day = ~6-7 hours total
You have Saturday evening + Sunday = plenty of time.

Why this matters: when Cursor generates Swift and you see
"guard let x = optional else { return }" you'll know what
it means and can catch mistakes. Without this, every line
of generated code is a black box.

---

## PRIORITY 3 — READ THE PLANNING DOCS (~1 hour)

Open the cursor-build-kit folder you downloaded.
Read these files in this order:

1. PRODUCT-SPEC.md — understand what you're building and why
2. README.md — understand how the phase files work  
3. PHASE-1-setup.md — preview Phase 1 so Tuesday isn't your
   first time seeing those prompts

You don't need to read API-REFERENCE.md or DEBUGGING-GUIDE.md
now — those are reference docs you'll use as needed.

---

## PRIORITY 4 — APP NAME (~30 min, maybe fun)

Think about what to call it. Criteria:
- Not already on the App Store (search to verify)
- Easy to spell and say
- Domain available (namecheap.com to check — you don't need
  to buy it yet, just verify it's available)
- Something you'd actually want on your phone

Some directions to explore:
- Metabolic/adaptive angle: Calibrate, Adapt, Baseline, Tuned
- Body/data angle: Bodylog, Macrofit, Biometric
- Learning angle: Evolve, Learn, Dial
- Simple utility names: Fueled, Macro, Stack

Avoid names that are too generic (MyFitnessPal territory) or
too technical. Aim for something that sounds like a product
you'd pay for.

---

## PRIORITY 5 — THINK THROUGH YOUR OWN ONBOARDING (~20 min)

You're the first user. Think through:

- What's your current weight? (you'll enter this on day 1)
- What's your goal right now — cut, bulk, or maintain?
- Do you have an Apple Watch? (affects effort scoring quality)
- How consistently do you weigh yourself currently?
- How do you typically eat — mostly cooked at home, restaurants,
  or a mix? (affects how often you'll use AI chat logging vs barcode)

Answering these for yourself helps you design the onboarding flow
and also helps you test it more authentically when you build it.

---

## NICE TO HAVE — NOT REQUIRED

**Figma (free)** — if you want to sketch the UI before coding it.
Some people find this helps, others prefer to just let SwiftUI
take shape through coding. Skip if you'd rather just build.

**Markdown editor** — the planning files are .md format. They read
fine in any text editor but a Markdown viewer makes them nicer.
VS Code (free) renders Markdown beautifully. You probably already
have it or can install it in 2 minutes.

**Simulator research** — look up what the iOS 17 simulator looks like
and how it handles HealthKit mock data. The DEBUGGING-GUIDE.md file
covers this but a 5-minute YouTube search for "Xcode simulator
HealthKit test data" will give you a visual reference.

---

## WHAT NOT TO DO BEFORE TUESDAY

Don't try to install Xcode on Windows. It doesn't run on Windows
and you'll waste time finding that out the hard way.

Don't try to write Swift code before the Mac mini arrives.
You can't run it, so you can't verify anything you write.

Don't over-plan the UI. The actual SwiftUI code will look
different from whatever you sketch anyway. Build it and iterate.

Don't wait until you feel "ready." You'll feel more ready
after 30 minutes of actually building than after 10 hours
of planning.

---

## TUESDAY GAME PLAN

When the Mac mini arrives:
1. Set it up using MAC-MINI-SETUP.md (~2 hours)
2. Run Phase 1, Prompt 1.1 in Cursor
3. Get the app compiling with data models
4. Call it a win for day 1

First week goal: complete Phase 1 and Phase 2.
That's the foundation. Everything visible and exciting
comes after, but you need this to be solid first.
