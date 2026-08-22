# Amperfy (personal fork)

This is `davidmasek/amperfy`, a fork of [BLeeEZ/amperfy](https://github.com/BLeeEZ/amperfy)
(iOS/iPadOS/macOS Swift client for Ampache/Subsonic servers, GPLv3). Used both for
learning iOS dev and for preparing PRs back upstream.

## Remotes

- `origin` → your fork, push here.
- `upstream` → `BLeeEZ/amperfy`, pull-only, PRs target this.

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

## Simulator automation (not set up yet)

Claude can build, run `AmperfyKitTests`, and launch the app in the iOS Simulator to check
it doesn't crash on boot — but there's no way to script taps/navigation yet: no
`idb`/Appium is installed, and `osascript`/System Events UI scripting is blocked because
Terminal doesn't have macOS Accessibility permission in this environment. So Claude can
confirm "it builds and launches," not "this specific screen renders correctly" — that
still needs a manual check in the Simulator for now. Worth revisiting properly later
(install `idb`, or grant Accessibility access) if this comes up often.

## Before opening a PR

- Run `AmperfyKitTests` (also applies SwiftFormat/Google style automatically).
- Or format manually: `./BuildTools/applyFormat.sh`.
