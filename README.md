# AI Nutrition App — Cursor Build Kit
=====================================================

Everything you need to build the V1 iOS nutrition app using Cursor.

## HOW TO USE THESE FILES

**Step 1 — Drop .cursorrules into your Xcode project root**
Cursor automatically reads this file and applies the rules to every
AI interaction in the project. It tells Cursor the architecture, 
coding conventions, and critical constraints for this specific app.
This is the most important file.

**Step 2 — Work through the PHASE files in order**
Each phase file contains copy-paste prompts for Cursor.
Run one prompt at a time. Verify it compiles and works before 
moving to the next prompt.

| File | Content |
|------|---------|
| PHASE-1-setup.md | Xcode project, data models, HealthKit, Keychain |
| PHASE-2-engine.md | Effort scorer, weight smoother, macro calculator + tests |
| PHASE-3-nutrition.md | Open Food Facts (barcode) + USDA (search), food log UI, manual entry, custom recipes |
| PHASE-4-5-ai-engine.md | Claude API, chat logger, adaptive TDEE engine |
| PHASE-6-polish.md | Trends view, onboarding, settings, TestFlight |
| PHASE-7-design.md | Final visual polish (design system, app icon, launch screen) |

**Step 3 — Use CURSOR-QUICK-REFERENCE.md when stuck**
Copy-paste prompts for common situations: Xcode errors, empty HealthKit 
data, malformed API responses, debugging the learning engine.

## ESTIMATED TIME

| Phase | Time | What You Get |
|-------|------|-------------|
| 1 | ~8 hrs | Compilable project, data models, HealthKit connected |
| 2 | ~6 hrs | All engine logic written and tested |
| 3 | ~8 hrs | Working food logger — Open Food Facts barcode + USDA text search |
| 3.5 | ~8 hrs | Manual entry, AI prefill, custom recipes, meal prep logging |
| 3.6 | ~3 hrs | **Existing code only** — refactor Nutritionix → OFF + USDA |
| 4-5 | ~12 hrs | AI chat logger + adaptive learning engine |
| 6 | ~8 hrs | Polished app ready for TestFlight |
| **Total** | **~50 hrs** | **V1 on TestFlight** |

Phase 7 (`PHASE-7-design.md`) completes final UI polish (design system + app icon/launch screen) after Phase 6.

At a pace of ~6-8 hrs/weekend: **6-7 weekends** to a working beta.

## THE GOLDEN RULE

**One prompt at a time. Verify before moving on.**

The temptation is to run all prompts at once or skip ahead.
Don't. Each phase builds on the last. A bug introduced in Phase 1
that isn't caught until Phase 5 is much harder to fix.

After each prompt:
1. Build in Xcode (Cmd+B) — fix any compile errors before continuing
2. Run the simulator briefly to check nothing crashes
3. For Engine/ classes: run tests (Cmd+U)

## WORKFLOW REMINDER

Write code → Cursor (Windows or Mac)
Build & test → Xcode on Mac mini
Version control → GitHub (commit after each working prompt)

```
# After each completed prompt, commit:
git add .
git commit -m "Phase X: [what you built]"
git push
```

Good luck. The idea is strong enough to be worth building.
