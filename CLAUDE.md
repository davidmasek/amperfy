# Amperfy (personal fork)

This is `davidmasek/amperfy`, a fork of [BLeeEZ/amperfy](https://github.com/BLeeEZ/amperfy)
(iOS/iPadOS/macOS Swift client for Ampache/Subsonic servers, GPLv3). Used both for
learning iOS dev and for preparing PRs back upstream.

## Remotes

- `origin` → your fork, push here.
- `upstream` → `BLeeEZ/amperfy`, pull-only, PRs target this.

## Branching rule — keeps local-only files out of upstream PRs

This file, `.env.local`, and anything else that's useful locally but not part of the
project only live on your fork's `master`. **Any branch meant to become an upstream PR
must be based on `upstream/master`, not on your local `master`:**

```
git fetch upstream
git checkout -b my-feature upstream/master
```

That way the feature branch's file tree never contains this file or any other local-only
addition, so a PR diff against `upstream/master` is always exactly the intended change —
regardless of what accumulates on your own `master`.

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

## Before opening a PR

- Run `AmperfyKitTests` (also applies SwiftFormat/Google style automatically).
- Or format manually: `./BuildTools/applyFormat.sh`.
