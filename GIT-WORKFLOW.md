# GIT WORKFLOW & PROJECT HYGIENE
# How to keep the codebase clean and recoverable.
# Especially important when vibe coding with AI.
# =========================================================

## WHY THIS MATTERS MORE WITH AI CODING

When you're writing code yourself, you have context for every
change. When Cursor writes it, a single prompt can touch 10
files at once. Without good Git habits, one bad prompt can
put you in a state you can't get back from.

The rule: commit working code frequently. A commit takes 30
seconds and can save you hours.

---

## INITIAL REPO SETUP

Create a .gitignore in the project root before your first commit.
This prevents Xcode junk and secrets from being committed.

Copy this exactly:

```
# Xcode
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
DerivedData/
*.moved-aside
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
xcuserdata/

# Build
build/
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager  
.build/
.swiftpm/

# macOS
.DS_Store
*.swp
*~.nib

# API Keys — NEVER commit these
*.env
.env.local
Secrets.swift
APIKeys.swift

# CocoaPods (if you ever add it)
Pods/
```

---

## COMMIT RHYTHM

**After each Cursor prompt that compiles successfully:**
```
git add .
git commit -m "Phase X: [what was built]"
```

**Examples of good commit messages:**
- "Phase 1: Add SwiftData models (FoodEntry, DayLog, UserProfile)"
- "Phase 2: EffortScoreCalculator with unit tests — all passing"
- "Phase 3: Nutritionix text search working"
- "Phase 4: Claude food extraction — handles markdown fence stripping"
- "Fix: TDEE engine null safety on missing smoothedWeight"

**Never commit:**
- Code that doesn't compile
- API keys or credentials
- Code you haven't at least glanced at

---

## BRANCH STRATEGY (SIMPLE VERSION)

For a solo developer, one branch is fine to start.
When experimenting with something risky, create a branch:

```
git checkout -b experiment/learning-engine-v2
# try your changes
# if it works: git checkout main && git merge experiment/learning-engine-v2
# if it doesn't: git checkout main (experiment branch just gets abandoned)
```

Use branches for:
- Rewriting a major component
- Trying a different architecture approach
- Anything where "this might completely break everything"

---

## RECOVERY COMMANDS

**"Cursor just made a mess of a file and I want to undo it"**
```
git checkout -- [filename]
```
Restores file to last committed state. Instant.

**"The last 2 prompts were a disaster, take me back"**
```
git log --oneline   ← find the commit hash you want to go back to
git reset --hard [commit-hash]
```
Warning: this deletes uncommitted changes permanently.

**"I want to see what changed in the last prompt"**
```
git diff
```
Shows all uncommitted changes. Useful for reviewing before committing.

**"I want to see the history"**
```
git log --oneline
```

---

## SECRETS MANAGEMENT

**The one rule: never put API keys in source code.**

All keys go in Keychain via KeychainManager. During development,
enter them through the Settings screen or temporarily via a
launch argument (but remove before committing).

Double-check before every commit:
```
git diff --cached | grep -i "api_key\|apikey\|secret\|password"
```
If this returns anything, stop and fix it.

If you accidentally commit a key:
1. Immediately rotate the key (generate a new one in the console)
2. The old key is compromised — treat it as such
3. git history can be scrubbed but it's annoying — better to not commit keys at all

---

## FOLDER STRUCTURE IN XCODE vs FILESYSTEM

Xcode has two concepts of "groups":
- Xcode groups (virtual folders — just organizational, no real folder)
- Folder references (real filesystem folders)

When Cursor creates new files, it creates them on the filesystem.
You need to drag them into Xcode's project navigator to add them
to the build target.

Shortcut: Xcode → File → Add Files to [Project] → select the
new files Cursor created → make sure "Add to targets" checkbox is checked.

If you skip this step: the file exists on disk but Xcode doesn't
know about it → "Cannot find type X in scope" errors.

---

## WEEKLY HYGIENE CHECKLIST

Do this once a week while you're actively building:

☐ Run all tests (Cmd+U) — fix any failures before continuing
☐ Build with no warnings (yellow triangles) — fix them
☐ Check no API keys in source: git diff --cached | grep -i key
☐ Commit everything that's working
☐ Push to GitHub (backup)
☐ Review what phase you're on and what's next

---

## GITHUB SETUP COMMANDS

First time setup on Mac mini (run in Terminal):

```bash
# Install Xcode command line tools (needed for git)
xcode-select --install

# Configure git identity
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# Clone your repo
git clone https://github.com/yourusername/your-app-name.git
cd your-app-name

# Or if starting fresh in an existing Xcode project:
git init
git remote add origin https://github.com/yourusername/your-app-name.git
git branch -M main
git push -u origin main
```

After this, GitHub Desktop on Windows can also see the same repo —
push from Mac mini, pull from Windows to review code.
