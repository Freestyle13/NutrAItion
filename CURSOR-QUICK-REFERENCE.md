# CURSOR QUICK-REFERENCE
# Copy-paste prompts for common situations during development
# =========================================================

## WHEN YOU GET AN XCODE ERROR
---------------------------------
Paste this into Cursor with the error message:

"I got this Xcode build error: [PASTE ERROR HERE]
Here is the relevant file: [PASTE FILE]
Fix the error and explain what caused it in Java terms if possible."


## WHEN HEALTHKIT RETURNS EMPTY DATA
--------------------------------------
"My HealthKit query is returning empty results in the simulator.
Here is my query code: [PASTE CODE]
Diagnose why it might be returning empty and show me how to add
test data to the iOS Simulator's Health app to verify it's working."


## WHEN CLAUDE API RETURNS MALFORMED JSON
-------------------------------------------
"My food extraction is failing because Claude returned this response
instead of clean JSON: [PASTE RESPONSE]
Update the system prompt in ClaudeAPIService to be more explicit,
and make the parser more resilient to handle this case."


## WHEN YOU WANT TO ADD A NEW FEATURE
---------------------------------------
"I want to add [FEATURE DESCRIPTION] to the app.
The relevant existing files are: [LIST FILES]
Following the existing architecture and code style in this project,
implement this feature. Place new files in the correct folders per
the project structure in .cursorrules."


## WHEN THE LEARNING ENGINE NUMBERS FEEL WRONG
------------------------------------------------
"The adaptive TDEE engine is producing unexpected results.
Here is the data going in: [PASTE DAYLOG SUMMARY]
Here is the TDEEAdjustment it returned: [PASTE RESULT]
Walk me through each step of the algorithm with these actual numbers
to identify where the calculation is going wrong."


## WHEN YOU WANT TO WRITE A UNIT TEST
---------------------------------------
"Write a unit test for this function: [PASTE FUNCTION]
Test these scenarios: [LIST EDGE CASES]
Follow the existing test naming convention: test_[function]_[scenario]_[result]
Place in EngineTests/"


## WHEN YOU NEED A SWIFTUI COMPONENT
--------------------------------------
"Create a SwiftUI view for [DESCRIPTION].
It should accept these inputs: [LIST]
It should call these callbacks: [LIST]
Match the visual style of the existing dashboard components.
No business logic in the view body — layout only."


## WHEN YOU'RE CONFUSED ABOUT A SWIFT CONCEPT
------------------------------------------------
"Explain [SWIFT CONCEPT] to me as if I'm a Java developer.
Show me the Swift code and the Java equivalent side by side.
Then show me how it's used in the context of this project."


## WHEN YOU WANT TO DEBUG A SWIFTDATA ISSUE
---------------------------------------------
"My SwiftData @Query isn't updating when I save new records.
Here is my view code: [PASTE]
Here is where I save: [PASTE]
Diagnose the issue — common causes are: wrong ModelContext,
missing @Environment(\.modelContext), or relationship not set up correctly."


## WHEN PREPARING FOR TESTFLIGHT
-----------------------------------
"Do a pre-TestFlight review of this file: [PASTE FILE]
Check for:
- Force unwraps (!) that could crash
- API keys or secrets hardcoded
- Debug print statements that should be removed
- TODO/FIXME comments on critical paths
- User-facing error messages that show raw technical errors"


## DAILY DEVELOPMENT REMINDER
--------------------------------
Start every Cursor session with:

"I'm continuing work on the iOS nutrition tracking app.
Here's what I'm working on today: [TASK]
Relevant files: [LIST FILES]
Current issue or goal: [DESCRIPTION]"

This gives Cursor full context and produces much better results
than jumping straight into a specific question.
