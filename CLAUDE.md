# Amperfy (personal fork)

This is `davidmasek/amperfy`, a fork of [BLeeEZ/amperfy](https://github.com/BLeeEZ/amperfy)
(iOS/iPadOS/macOS Swift client for Ampache/Subsonic servers, GPLv3). Used both for
learning iOS dev and for preparing PRs back upstream.

When the user states a lasting rule or preference for this repo, add it to this file, in
the section it applies to, in the same session: not to Claude's memory, which is
untracked and hard to audit. Memory is for short-lived state of work in progress.

## Remotes

- `origin` → your fork, push here. **Default PR target — see hard rule below.**
- `upstream` → `BLeeEZ/amperfy`, pull-only. Never push here.

`master` on `origin` rejects deletion and force-pushes (ruleset `protect-master`, id
`26285628`, no bypass). To force-push or delete it anyway, disable the ruleset, push, then
re-enable it:
```
gh api -X PUT repos/davidmasek/amperfy/rulesets/26285628 -f enforcement=disabled
gh api -X PUT repos/davidmasek/amperfy/rulesets/26285628 -f enforcement=active
```
Inspect it with `gh api repos/davidmasek/amperfy/rulesets/26285628`.

## PRs — hard rule

**Every PR defaults to `origin` (this fork) only.** Never open a PR against `upstream`
(`BLeeEZ/amperfy`) without the user's explicit, per-PR approval given at the time —
a general intention stated earlier in the conversation ("let's aim upstream eventually")
does **not** count as approval for a specific PR. Before running `gh pr create` (or
anything else) with `--repo BLeeEZ/amperfy` or any other upstream target, stop and ask.

In fork issues, PRs and commit messages, refer to an upstream issue or PR as
`` `upstream#564` `` (in backticks), not a link or `BLeeEZ/amperfy#564`: a link posts a
"mentioned this" notice on the upstream item. `/fork-manager` finds the backtick form.

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

Build and test from the `master`-based branch (its PR goes to `origin` for review). Create
the upstream branch afterwards by cherry-picking onto `upstream/master`; that branch can't
build for Mac Catalyst (see "Running the app on the Mac").

Every branch you push gets a fork PR (draft while in progress) whose description says what
the branch is for, with exactly one `status:` label: `status: wip`, `parked`, `fork-only`,
`upstreaming`, `done` or `dropped` (`gh label list --search status` shows what each means).
Add it with `gh pr create ... --label "status: wip"`. A cherry-picked upstream branch's
fork PR targets `upstream-master` (the fork's mirror of `upstream/master`), links the
original branch's PR, and is never merged.

Rebase or merge to update a branch, whichever is simpler. Force-pushing your own branches
is fine; `master` is protected (see "Remotes").

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
The simulator is sandboxed and needs no macOS permissions. Simulators are shared across the
Mac: every session that uses the same `<sim id>` drives the same phone, app install, login and
app data.

1. **Create your own simulator** for the session:
   ```
   xcrun simctl list devices booted
   xcrun simctl create "claude-<task>" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro
   ```
   `create` prints the new `<sim id>`. Use only that device: never one that `list devices booted`
   shows, or one you didn't create, because the user or another session may be using it. Keep
   the iPhone 17 Pro type: the tap coordinates below are its points.
2. **Build** with `xcodebuild build -project Amperfy.xcodeproj -scheme Amperfy -destination 'platform=iOS Simulator,id=<sim id>' -derivedDataPath <scratch>/dd-sim`
3. **Boot, install, launch**:
   ```
   xcrun simctl boot <sim id>
   xcrun simctl install <sim id> <app>
   xcrun simctl launch <sim id> <bundle id>
   ```
   `<app>` is `<scratch>/dd-sim/Build/Products/Debug-iphonesimulator/Amperfy.app`. Read
   `<bundle id>` with `/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' <app>/Info.plist`:
   it is `com.davidmasek.amperfy` on `master`-based branches and
   `de.familie-zimba.amperfy-music` on `upstream/master`-based ones. A build with the other id
   installs as a second app, so launching the old id starts the old build.
4. **Screenshot**, then open the PNG with Read: `xcrun simctl io <sim id> screenshot <scratch>/<name>.png`
5. **Read the screen**: `idb ui describe-all --udid <sim id> --format complete`. Plain `--json`
   fails with "No translation object returned for simulator". The root element's label is the
   app's display name ("Amperfy Local" on `master`-based builds), so don't match on "Amperfy".
6. **Tap by label**: `idb ui tap "<label>" --udid <sim id> --reason "<why>"`. Take a screenshot
   afterwards to confirm. For an element without a label, tap coordinates: points are
   screenshot pixels / 3 on the iPhone 17 Pro. `idb ui text "<string>"` types into the focused
   field. `idb ui swipe` and `key` are untried with this app.
7. **Log in** to the test server (values from `.env.local`: `set -a; . ./.env.local; set +a`),
   on the fresh install's login screen (iPhone 17 Pro points):
   ```
   idb ui tap 200 330 --udid <sim id> --reason "focus server URL field"; idb ui text "$NAVIDROME_URL" --udid <sim id>
   idb ui tap 200 385 --udid <sim id> --reason "focus username field";   idb ui text "$NAVIDROME_USER" --udid <sim id>
   idb ui tap 200 440 --udid <sim id> --reason "focus password field";   idb ui text "$NAVIDROME_PASSWORD" --udid <sim id>
   idb ui tap "Login" --udid <sim id> --reason "submit login"
   ```
   About 10 seconds later, clear the prompts in this order, checking with a screenshot between
   them:
   1. System "Save Password?": not in the accessibility tree (`describe-all` shows only the
      root element). Tap Not Now at `127 547`.
   2. In-app "Synchronization" notice: `idb ui tap "Close"`.
   3. In-app "Notifications" notice: `idb ui tap "Close"`.
   4. System notification permission: `idb ui tap "Don’t Allow"` (curly apostrophe).
8. **Open Settings**: tap the profile icon at `38 83` (no label), then `idb ui tap "Settings"`.
9. **Shut down and delete** the device you created:
   ```
   xcrun simctl terminate <sim id> <bundle id>
   xcrun simctl shutdown <sim id>
   xcrun simctl delete <sim id>
   ```
   Never shut down or delete a device you didn't create.

Screenshots of the filled login form or the account menu show the server host and username:
don't attach them to a PR.

### Playing music in the simulator

Simulator audio comes out of the Mac's speakers and `simctl` has no mute. Ask the user before
the first play of the session, and run `xcrun simctl terminate <sim id> <bundle id>` as soon
as the check is done: a playing app keeps sounding until it is stopped.

Setting `_playerVolume` to 0 in the `settings.user` JSON of the app's preferences plist
silences it, but only if the simulator is shut down while editing (a booted simulator's
`cfprefsd` serves the old value).

1. **Play**: `idb ui tap 100 220` opens the first Random Album on Home, `idb ui tap "Play"`
   starts it, `idb ui tap 150 755` opens the full player. Close the player with
   `idb ui swipe 200 70 200 700 --duration 0.4`.
2. **Read the player**: `idb ui describe-all --udid <sim id> --format complete | grep -oE '"label":"[^"]*"'`
   shows the elapsed/remaining time (`0:04`, `-0:21`) and the audio info label (`MP3 320 kbps`).
   Two reads a few seconds apart show whether it is playing. Pause with `idb ui tap "pause"`.

Other taps that work: `idb ui tap "Resync Library"` (Settings > Account, after
`idb ui swipe 200 600 200 150 --duration 0.4`) opens a confirmation; `idb ui tap "Resync"` hits
the row behind it, so confirm with `idb ui tap 275 537`. Resync clears only the local library.

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

## Test servers (API probes with `curl`)

Probe what a server really returns before changing URL generation in `AmperfyKit/Api`.
Compare `Content-Type`, byte count and `ffprobe -show_entries format=bit_rate -of csv=p=0`
of the saved body. Wait a few seconds between Ampache requests: rapid ones get HTTP 429.

### Subsonic: Navidrome from `.env.local`

```
set -a; . ./.env.local; set +a
Q="u=$NAVIDROME_USER&p=$NAVIDROME_PASSWORD&v=1.13.0&c=probe"   # v matches what Amperfy sends
curl -s "$NAVIDROME_URL/rest/getRandomSongs?$Q&f=json&size=500"            # pick a song id, e.g. suffix flac
curl -s -o out.bin -D h.txt "$NAVIDROME_URL/rest/stream?$Q&id=<song id>&format=mp3&maxBitRate=128"
```

`download` takes only `id` and returns the original file. `format=raw` beats `maxBitRate`.
`stream&maxBitRate=…` without `format` lets the server pick the codec (Navidrome 0.61: Ogg).

### Ampache: official image, local container

1. **Docker**: `open -a Docker`, then wait until `docker info` succeeds.
2. **Test files**, in a scratch dir (3 FLACs of 30 s):
   ```
   for i in 1 2 3; do ffmpeg -y -f lavfi -i "anoisesrc=d=30:c=pink:r=44100:a=0.3" \
     -metadata title="Probe Track $i" -metadata artist="Probe Artist" -metadata album="Probe Album" \
     -c:a flac <scratch>/music/track$i.flac; done
   ```
3. **Run** the pinned image (`ampache/ampache` on Docker Hub, source `github.com/ampache/ampache-docker`).
   `DB_HOST` and `DB_NAME` are required for the automated install. Keep the admin password in a
   scratch file, not in a tracked file:
   ```
   docker run -d --name ampache-probe -p 8081:80 -v <scratch>/music:/media:ro \
     -e MYSQL_PASS=probedb -e DB_PASSWORD=probedb -e AMPACHE_DB_PASSWORD=probedb \
     -e DB_HOST=localhost -e DB_NAME=ampache \
     -e AMPACHE_ADMIN_USER=probe -e AMPACHE_ADMIN_EMAIL=probe@example.com \
     -e AMPACHE_ADMIN_PASSWORD="$(cat <scratch>/adminpw)" ampache/ampache:8.3.0
   ```
   Wait about 60 s for the install to finish.
4. **Catalog**:
   ```
   docker exec ampache-probe php /var/www/bin/cli run:addCatalog probe /media
   docker exec ampache-probe php /var/www/bin/cli run:updateCatalog -a probe
   ```
5. **Enable transcoding**, off by default (without it `format` and `bitrate` are ignored and the
   original file is returned). Lost when the container is removed:
   ```
   docker exec ampache-probe sed -i 's/^;transcode_cmd = "ffmpeg"/transcode_cmd = "ffmpeg"/;s/^;transcode_flac = "allowed"/transcode_flac = "required"/' /var/www/config/ampache.cfg.php
   ```
6. **Handshake**, auth is `sha256(timestamp + sha256(password))`; the response's `auth` is the token:
   ```
   TS=$(date +%s); H=$(printf %s "$(cat <scratch>/adminpw)" | shasum -a 256 | cut -d' ' -f1)
   AUTH=$(printf %s "$TS$H" | shasum -a 256 | cut -d' ' -f1)
   curl -s "http://localhost:8081/server/json.server.php?action=handshake&auth=$AUTH&timestamp=$TS&version=500000&user=probe"
   curl -s -L -o out.bin -D h.txt "http://localhost:8081/server/json.server.php?auth=<token>&version=500000&type=song&id=1&action=stream&format=mp3&bitrate=128000"
   ```
   `stream` answers with a 302 to `play/index.php`; pass `-L`.
7. **Stop**: `docker rm -f ampache-probe`.

Ampache 8.3.0 behaviour, tested with the setup above:
- `bitrate` is in bits per second (`64000`). Values like `64` or `192` are ignored (server default 128 kbps).
- `stream` honours `bitrate`; `download` ignores it (it honours `format`).
- `download` or `stream` without a transcode config returns the original file for any `format`.
- `stream` counts a play (`playcount` in `action=song`), `download` does not. `stats=0` does not prevent it:
  the server drops it from the redirect. Repeated `stream` requests for one song count once.

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

For changes that aren't iPhone-specific. Build from a branch based on `master`: it has the
signing edits ad-hoc signing needs (no CarPlay/Siri entitlements, bundle id
`com.davidmasek.amperfy`). On a branch based on `upstream/master` the build fails with
`"Amperfy" has entitlements that require signing with a development certificate`.

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
