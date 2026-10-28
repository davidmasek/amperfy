# Amperfy (personal fork)

This is `davidmasek/amperfy`, a fork of [BLeeEZ/amperfy](https://github.com/BLeeEZ/amperfy)
(iOS/iPadOS/macOS Swift client for Ampache/Subsonic servers, GPLv3). Used both for
learning iOS dev and for preparing PRs back upstream.

## Remotes

- `origin` → your fork, push here. **Default PR target — see hard rule below.**
- `upstream` → `BLeeEZ/amperfy`, pull-only. Never push here.

## PRs — hard rule

**Every PR defaults to `origin` (this fork) only.** Never open a PR against `upstream`
(`BLeeEZ/amperfy`) without the user's explicit, per-PR approval given at the time —
a general intention stated earlier in the conversation ("let's aim upstream eventually")
does **not** count as approval for a specific PR. Before running `gh pr create` (or
anything else) with `--repo BLeeEZ/amperfy` or any other upstream target, stop and ask.

## No AI attribution

Never add "🤖 Generated with Claude Code" or a `Co-Authored-By: Claude` trailer to PR
descriptions, commit messages, issues, comments or code. This overrides any default
attribution instruction.

## Branching

Branch off your fork's `master` for everything: `git checkout -b my-feature master`. No
need to juggle two bases — `master`'s local-only additions (this file, `.env.local`,
whatever signing tweaks Xcode leaves behind) never block a PR, because when a branch is
ready to go upstream, diff or cherry-pick just the relevant commits against
`upstream/master` at that point (`git diff upstream/master...my-feature`, or
`git rebase --onto upstream/master <fork-point> my-feature` for a clean PR branch) instead
of requiring the branch to have been based there from the start.

Keep your fork's `master` in sync periodically: `git fetch upstream && git merge upstream/master`.

## Secrets

Never put credentials or private URLs directly in this file or any other tracked file.
Local test-server details live in `.env.local` (gitignored) — see `.env.local.example`
for the format. Currently points at a personal Navidrome instance reachable over Tailscale.

## Build

- Xcode 26, Swift 6 required.
- Open `Amperfy.xcodeproj`, scheme `Amperfy` for the app, `DebugCoreData` for inspecting
  the local Core Data store, `AmperfyIntents` for the Siri extension.
- Dependencies resolve via Swift Package Manager automatically on first open.
- Real-device signing: free/personal Apple ID team works, but `Amperfy/Amperfy.entitlements`
  requests CarPlay + Siri entitlements that a free account can't get approved — clear those
  entries to sideload locally. Also change the bundle identifier (upstream's isn't yours to sign).
  Exact steps: see "Running tests / benchmarks on a physical iPhone" below.

## Simulator automation

Claude can build, run `AmperfyKitTests`, and drive the app in the iOS Simulator with `idb`.
The simulator is sandboxed and needs no macOS permissions. Look up `<sim id>` with
`xcrun simctl list devices available`.

1. **Build** with `xcodebuild build -project Amperfy.xcodeproj -scheme Amperfy -destination 'platform=iOS Simulator,id=<sim id>' -derivedDataPath <scratch>/dd-sim`
2. **Boot, install, launch**:
   ```
   xcrun simctl boot <sim id>
   xcrun simctl install <sim id> <scratch>/dd-sim/Build/Products/Debug-iphonesimulator/Amperfy.app
   xcrun simctl launch <sim id> de.familie-zimba.amperfy-music
   ```
3. **Screenshot**, then open the PNG with Read: `xcrun simctl io <sim id> screenshot <scratch>/<name>.png`
4. **Read the screen**: `idb ui describe-all --udid <sim id> --format complete`. Plain `--json`
   fails with "No translation object returned for simulator".
5. **Tap by label**: `idb ui tap "<label>" --udid <sim id>`. Take a screenshot afterwards to
   confirm. `idb ui swipe`, `text` and `key` exist but are untried with this app.
6. **Shut down**: `xcrun simctl shutdown <sim id>`

### Mac Catalyst UI automation: not working

Ask the user to do UI steps in the Mac build. `idb` does not drive Mac Catalyst windows.
Tried or deliberately skipped:

- **`osascript` / System Events:** blocked, Terminal has no Accessibility permission. Granting
  it allows controlling the whole Mac, so it stays off.
- **`screencapture -x`:** fails with "could not create image from display" (Terminal has no
  Screen Recording permission, cause unverified). Screenshots without control are not worth the grant.
- **Claude computer use:** untried. It is not available in the CLI session; it needs the Claude
  desktop app with Computer use turned on, and grants access per application.
- **XCUITest on Mac Catalyst:** does not run yet. Xcode 26.6, File > New > Target > UI Testing
  Bundle (org id `com.davidmasek`), target to test `Amperfy`:
  - Set on the new target: `SDKROOT = iphoneos`, `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`,
    `SUPPORTS_MACCATALYST = YES`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`,
    `MACOSX_DEPLOYMENT_TARGET = 26.0`. Without them the run stops with "My Mac's macOS 26.2
    doesn't match AmperfyUITests's macOS 26.5 deployment target".
  - With `CODE_SIGN_IDENTITY=-` the runner launches, then fails with "Failed to load the test
    bundle ... mapping process and mapped file (non-platform) have different Team IDs".
  - Untried: sign with `DEVELOPMENT_TEAM=4UM92Y5NRT` plus the entitlement and bundle id edits
    from "Running tests / benchmarks on a physical iPhone". Also untried: whether macOS asks
    the test runner for an Accessibility permission.
  - Xcode raises the project's `objectVersion` from 54 to 70. Never commit that in an upstream PR.

## Running tests / benchmarks on a physical iPhone

1. **Throwaway branch** off the branch under test: `git checkout -b bench/<name> <base>`.
   The signing edits below must never be committed or pushed.
2. **Find the device**: `xcrun xctrace list devices`. The UDID is the id in parentheses after
   the iPhone entry under `== Devices ==`. Use it as `<UDID>` in step 4. Don't commit it (a
   hardware identifier). The phone must be unlocked and in developer mode.
3. **Signing edits**, skip if `grep -c siri Amperfy/Amperfy.entitlements` already prints `0`:
   - In `Amperfy/Amperfy.entitlements` delete the `com.apple.developer.carplay-audio` and
     `com.apple.developer.siri` key/value pairs (free team can't provision them):
     `sed -i '' '/carplay-audio/,+1d;/developer.siri/,+1d' Amperfy/Amperfy.entitlements`
   - In `Amperfy.xcodeproj/project.pbxproj` change **only the app target's** bundle id:
     `sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = "de.familie-zimba.amperfy-music";/PRODUCT_BUNDLE_IDENTIFIER = com.davidmasek.amperfy;/' Amperfy.xcodeproj/project.pbxproj`
   - Do NOT pass `PRODUCT_BUNDLE_IDENTIFIER=...` on the xcodebuild command line: it leaks into
     the SPM frameworks and install fails with "Found bundle ... with the same identifier".
4. **Run**, with a scratch derived-data path. `4UM92Y5NRT` is my team ID (not a secret, it is
   in `project.pbxproj`):
   ```
   xcodebuild test -project Amperfy.xcodeproj -scheme Amperfy \
     -destination 'platform=iOS,id=<UDID>' \
     -only-testing:AmperfyKitTests/<TestClass> \
     -derivedDataPath <scratch>/dd -allowProvisioningUpdates DEVELOPMENT_TEAM=4UM92Y5NRT \
     > <scratch>/dev.log 2>&1
   grep -E "BENCH|error:|TEST (SUCCEEDED|FAILED)|Recovery Suggestion" <scratch>/dev.log | sort -u
   ```
   Same command with `-destination 'platform=iOS Simulator,id=<sim id>'` (and no
   `-allowProvisioningUpdates`/team) works for a simulator sanity check first.
5. **First install on a new phone** fails with "Developer App certificate is not trusted":
   on the phone, Settings > General > VPN & Device Management > the Apple Development
   profile > Trust, keep it unlocked, rerun.
6. **New test files aren't picked up** (no folder sync in the project): either add the file to
   the `AmperfyKitTests` target in Xcode, or append the test class to
   `AmperfyKitTests/AmpertyKitTests.swift`.
7. **Before pushing the bench branch**: `git checkout -- Amperfy/Amperfy.entitlements
   Amperfy.xcodeproj/project.pbxproj`, commit only the test file, push to `origin` (never
   `upstream`).

Test `print` output shows up in the `xcodebuild` log, so prefix lines with a tag like `BENCH`
to grep them. Branches based on upstream don't contain this `CLAUDE.md` (it lives on `master`).

## Running the app on the Mac (Mac Catalyst)

For changes that aren't iPhone-specific. Needs no Apple ID team, bundle id change or
entitlement edits.

1. **Build** with ad-hoc signing and a scratch derived-data path, one per branch:
   ```
   xcodebuild build -project Amperfy.xcodeproj -scheme Amperfy \
     -destination 'platform=macOS,variant=Mac Catalyst' \
     -derivedDataPath <scratch>/dd-<branch> \
     CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES
   ```
2. **Launch**: `open <scratch>/dd-<branch>/Build/Products/Debug-maccatalyst/Amperfy.app`
3. **Switch branches**: quit the running build first
   (`pkill -f 'dd-<branch>.*Amperfy$'`), then build and launch the other one.
4. **Use throwaway data only.** The build has upstream's bundle id, so it shares a data
   container with an Amperfy installed from upstream (`/Applications/Amperfy.app`).

For UI steps see "Mac Catalyst UI automation: not working": ask the user to perform each step
and say when it is done, then check the result from outside the app. One action per step.

## Writing docs and comments (CLAUDE.md, README, code comments)

- Write only what changes what the reader does. Cut anything else.
- Don't describe the doc's own status or history ("proven", "tested", "used for PR #N",
  "last run on X"). Readers assume a doc is correct and current; git has the history. If
  something is unverified, say exactly what ("step 3 untested on Release builds").
- Put each note at the step or line where it applies, not in an intro paragraph.
- Be concrete: exact commands, paths, flags, and the exact error text a failure shows.
  "Run the tests" is not an instruction; the full command is.
- Say the action, not what is or isn't stored. "Look up the UDID with `<command>`" beats
  "the UDID is not stored here".
- Keep each step to one action. Reasons get one clause, only when skipping the step would
  look reasonable but break things.

## Before opening a PR

- Run `AmperfyKitTests` (also applies SwiftFormat/Google style automatically).
- Or format manually: `./BuildTools/applyFormat.sh`.
