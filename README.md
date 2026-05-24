# OllamaDock

A native macOS menubar app that shows which Ollama models are currently loaded in GPU memory — the GUI equivalent of `ollama ps`.

## Features

- Always-visible menubar label: `▦ {total VRAM}` (e.g. `▦ 19 GB`, `▦ 0 GB` when idle).
- Popover lists each loaded model with:
  - Name
  - VRAM bar (share of system RAM)
  - Idle-unload countdown (updated every second)
  - One-click unload (⏏)
- Footer actions: Refresh, Unload all, Quit.
- Auto-refresh every 5 seconds.
- No dock icon (`LSUIElement`).

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15 or later
- [Ollama](https://ollama.com) running locally on `http://localhost:11434`

## Build & run

```bash
git clone https://github.com/donkasun/ollamadock.git
cd ollamadock
open OllamaDock.xcodeproj
```

Select the `OllamaDock` scheme and press ⌘R. The app installs into your menu bar; it has no Dock icon.

## Regenerating the Xcode project

`OllamaDock.xcodeproj` is generated from [`project.yml`](project.yml) via [XcodeGen](https://github.com/yonaskolb/XcodeGen). Only required if you add or remove source files:

```bash
brew install xcodegen
xcodegen generate
```

## Tests

```bash
xcodebuild test \
  -project OllamaDock.xcodeproj \
  -scheme OllamaDock \
  -destination 'platform=macOS'
```

Current suite: 20 unit tests across `RunningModel`, `OllamaClient`, and `ModelMonitor`.

## Architecture

```
OllamaDockApp           // @main App, owns the ModelMonitor
  └── MenuBarExtra
        ├── label:  MenuBarLabel(totalVRAM:)
        └── content: PopoverView(monitor:)
                      ├── header  (count + total VRAM)
                      ├── content (switch on ConnectionState)
                      │     ├── .loading       → "Checking…"
                      │     ├── .unreachable   → "Ollama isn't running"
                      │     ├── .connected (empty) → "No models loaded"
                      │     └── .connected     → ForEach ModelRow
                      ├── error  (red caption, if any)
                      └── footer (Refresh / Unload all / Quit)

ModelMonitor (@MainActor @Observable)
  ├── Polls OllamaClient every 5 s
  ├── Ticks `now` every 1 s for smooth countdowns
  └── Exposes models / state / totalVRAM / now / lastUnloadError

OllamaClient (Sendable)
  ├── GET /api/ps           → [RunningModel]
  └── POST /api/generate    → unload (keep_alive: 0)
```

## Not in v1

- Settings UI
- Configurable host / port / poll interval
- Launch at login
- Notarized DMG release
- Per-model history / graphs

These are deferred to keep v1 small. Issues welcome if you'd like to discuss.

## Contributing

Bug reports and pull requests are welcome. Please keep PRs scoped to a single concern and include tests for any logic changes. The implementation plan lives at [`docs/superpowers/plans/2026-05-24-ollamadock-v1.md`](docs/superpowers/plans/2026-05-24-ollamadock-v1.md).

## License

MIT — see [`LICENSE`](LICENSE).
