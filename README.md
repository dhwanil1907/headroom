# Headroom

A macOS menu bar app that shows how much usage you have left on Claude and Cursor.

The menu bar item shows your highest usage percentage across providers. Click it to see a
per-provider breakdown, plus lifetime Claude Code token totals.

## Requirements

- macOS 14+
- Swift 5.9+ toolchain (Xcode or Command Line Tools)

## Build and run

```sh
./build_app.sh        # builds build/Headroom.app (release, ad-hoc signed)
open build/Headroom.app
```

For development:

```sh
swift run Headroom
swift test
```

## Sign-in

Headroom reads usage from the Claude (`claude.ai`) and Cursor (`cursor.com`) web APIs using your
browser session cookie. Sign in through the in-app login window, or paste a session value in
Settings.

Credentials are stored in the macOS Keychain (service `com.headroom.credentials`) and read once per
launch.

## Claude Code tokens

Lifetime token counts are read locally from `~/.claude/stats-cache.json` and use the same counting
as Claude Code's `/stats` screen.

## Layout

| Path | Purpose |
|------|---------|
| `Sources/Headroom` | SwiftUI menu bar app (`MenuBarExtra`), settings, login window |
| `Sources/HeadroomCore` | Providers, models, Keychain credentials, token stats |
| `Tests/HeadroomCoreTests` | Provider tests |
| `Support` | `Info.plist` and app icon generator |

## Adding a provider

Implement `UsageProvider` in `HeadroomCore` and add it to `ProviderRegistry.live`.
`MockProvider` is a reference for the minimal shape.
