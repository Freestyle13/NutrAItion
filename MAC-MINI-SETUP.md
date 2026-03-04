# MAC MINI SETUP GUIDE
# Everything to do the day your Mac mini arrives.
# Follow in order — takes about 2 hours total.
# =========================================================

## STEP 1 — PHYSICAL SETUP (~10 min)

1. Plug in power, HDMI to monitor, keyboard and mouse via USB or Bluetooth
2. Boot up, complete macOS setup wizard
3. Sign in with your Apple ID (the free one — not the developer account)
4. Skip iCloud sync for everything except Keychain (useful for Safari passwords)
5. Set computer name: System Settings → General → Sharing → Local hostname
   Suggestion: "dev-mini" — you'll type this if you ever SSH into it

---

## STEP 2 — macOS UPDATE (~20 min, mostly waiting)

System Settings → General → Software Update
Install any pending updates. The Mac mini may have shipped with an
older macOS version. You need macOS Sequoia or Sonoma for Xcode 16.
Let it update and restart before doing anything else.

---

## STEP 3 — XCODE (~60 min download, ~10 min setup)

1. Open App Store → search "Xcode" → Install
   This is a ~7GB download. Start it and do other steps while it downloads.

2. Once installed, open Xcode
3. It will prompt to install additional components — accept
4. Xcode → Settings → Accounts → + → Apple ID → sign in with your Apple ID
   (This is the free account — enables running apps on simulator)

5. Accept the Xcode license: open Terminal, run:
   sudo xcodebuild -license accept

6. Install Command Line Tools if prompted (or run: xcode-select --install)

---

## STEP 4 — HOMEBREW & GIT (~5 min)

Homebrew is the package manager for macOS (like apt on Linux).
Open Terminal (Cmd+Space → "Terminal") and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the prompts. At the end it will tell you to run two commands
to add Homebrew to your PATH — do that.

Verify git is installed: git --version
Configure git:
```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

---

## STEP 5 — CURSOR (~5 min)

1. Go to cursor.com → Download for Mac
2. Install the .dmg, move to Applications
3. Open Cursor
4. Sign in (same account as your Windows Cursor if you have one)
5. Install the Swift extension: Cmd+Shift+X → search "Swift" → install
   the one by "Swift Server Work Group" (official Apple extension)

---

## STEP 6 — GITHUB SETUP (~5 min)

If you haven't already created the repo on GitHub, do that now
at github.com → New Repository → Private → no template.

Then in Terminal on the Mac mini:
```bash
# Clone your repo (replace with your actual repo URL)
git clone https://github.com/yourusername/your-app-name.git

# Navigate into it
cd your-app-name
```

If the repo is empty that's fine — you'll create the Xcode project inside it.

---

## STEP 7 — CREATE XCODE PROJECT (~10 min)

1. Open Xcode → Create New Project
2. iOS → App → Next
3. Settings:
   - Product Name: [your app name]
   - Team: select your personal Apple ID (free)
   - Organization Identifier: com.yourname (e.g., com.johndoe)
   - Bundle Identifier: auto-filled from above
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData
   - Include Tests: YES (check this!)
4. Save location: inside your cloned GitHub repo folder
5. Xcode opens the project

---

## STEP 8 — ADD HEALTHKIT CAPABILITY (~2 min)

This is required before writing any HealthKit code:

1. In Xcode project navigator, click the blue project file at the top
2. Select your app target
3. Click "Signing & Capabilities" tab
4. Click "+ Capability"
5. Search for "HealthKit" → double click to add
6. Check "Clinical Health Records" OFF (don't need it)
7. You'll see HealthKit now appears in the capabilities list

---

## STEP 9 — DROP IN YOUR PLANNING FILES (~2 min)

1. Copy the cursor-build-kit folder contents into your project root
2. In Cursor: File → Open Folder → select your project folder
3. Cursor will find .cursorrules automatically

Verify Cursor sees it: click any Swift file in Cursor, open chat,
ask "what are the architecture rules for this project?" — it should
reference the confidence system and other rules from .cursorrules.

---

## STEP 10 — FIRST BUILD TEST (~2 min)

In Xcode:
1. Select a simulator: top bar dropdown → iPhone 16 (or any iPhone 17+)
2. Hit Run (▶ button) or Cmd+R
3. The simulator should open and show the default "Hello World" SwiftUI app
4. If it compiles and shows the simulator — your environment works ✅

If it fails: likely a signing issue. Go to Signing & Capabilities →
make sure your Apple ID is selected under Team → check "Automatically
manage signing" is on.

---

## STEP 11 — SET UP REMOTE ACCESS FROM WINDOWS (~10 min)

So you can see the simulator from your Windows laptop:

**On Mac mini:**
System Settings → General → Sharing → turn on "Screen Sharing"
Note the address shown: "vnc://[address]"

**On Windows:**
Download "Jump Desktop" (paid, ~$30, worth it) or use the free
"RealVNC Viewer" for basic access.
Connect to the Mac mini's IP address.

Alternative: if they're on the same network, you can often just
use the Mac mini's hostname: dev-mini.local

Now you can see the iOS simulator on your Windows screen while
keeping Cursor open on Windows for writing code.

---

## YOU'RE READY TO BUILD

Your environment is set up. Open PHASE-1-setup.md in Cursor
and run the first prompt.

Total time investment to get here: ~2 hours
Time to have a compilable app structure: another 2-3 hours

Good luck.
