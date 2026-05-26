# OllamaDock

A native macOS menubar app that shows which Ollama models are loaded in GPU memory — the GUI equivalent of `ollama ps`.

| Dark | Light |
|---|---|
| <img src="assets/popover-dark.png" width="380" alt="OllamaDock popover in dark mode showing a running model card with countdown and an available model"> | <img src="assets/popover-light.png" width="380" alt="OllamaDock popover in light mode showing a running model card with countdown and an available model"> |

## Why

The official Ollama menubar icon doesn't show which models are loaded. [Ollamac](https://github.com/kevinhermawan/Ollamac) is a chat client, not a monitor. OllamaDock fills that gap: a lightweight, always-visible status widget with one-click load/unload.

## Features

- **Menubar label** — a status dot (green when a model is loaded, white when idle) + `{total VRAM}` (e.g. `5.87 GB`), `0 GB` when idle
- **Status bar** — two labeled dots in the popover: Ollama daemon up/down and model loaded/none
- **Running models** — each shown as a blue card with name, VRAM used, idle-unload countdown, and a stop button (confirmation expands inside the card)
- **Available models** — all downloaded-but-unloaded models listed with disk size and a ▶ load button
- **Start Ollama** — when the daemon is down, launch it from the popover (or a link to ollama.com if it isn't installed)
- **Stop All** — unloads every running model in one click
- **Refresh** — re-polls on demand
- Auto-refresh every 10 seconds; 1-second tick for smooth countdowns
- No Dock icon (`LSUIElement`)

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15 or later
- [Ollama](https://ollama.com) running locally on `http://localhost:11434`

## Install

1. Download `OllamaDock-vX.Y.Z.zip` from the [latest release](https://github.com/donkasun/ollamadock/releases/latest).
2. Unzip and move `OllamaDock.app` to `/Applications`.
3. Launch it. OllamaDock appears in the menu bar (no Dock icon).

> **First launch:** the app is not notarized, so macOS Gatekeeper will block it
> with "OllamaDock can't be opened." Right-click the app → **Open** → **Open** to
> run it once; macOS remembers the choice afterward. (Notarization is planned for
> a later release.)

## Build & run

```bash
git clone https://github.com/donkasun/ollamadock.git
cd ollamadock
open OllamaDock.xcodeproj
```

Select the `OllamaDock` scheme and press ⌘R. The app lives in the menu bar with no Dock icon.

### Regenerating the Xcode project

`OllamaDock.xcodeproj` is generated from [`project.yml`](project.yml) via [XcodeGen](https://github.com/yonaskolb/XcodeGen). Only needed when adding or removing source files:

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

27 unit tests across `RunningModel`, `OllamaClient`, and `ModelMonitor`.

## Architecture

```
OllamaDockApp           // @main App, owns the ModelMonitor
  └── MenuBarExtra
        ├── label:   MenuBarLabel(daemonUp:modelRunning:totalVRAM:)   // status dot + VRAM
        └── content: PopoverView(monitor:)
                       ├── header    (count · total VRAM)
                       ├── statusBar (daemon dot · model dot, with labels)
                       ├── content (switch on ConnectionState)
                       │     ├── .loading         → "Checking…"
                       │     ├── .unreachable      → "Start Ollama" / install link
                       │     ├── .protocolError    → "Ollama responded unexpectedly"
                       │     ├── .connected empty  → "No models loaded"
                       │     └── .connected        → Running + Available sections
                       ├── error  (red caption on unload failure)
                       ├── footer (↺ Refresh · Stop All · ⏻ Quit)
                       └── quitConfirmation (expands when ⏻ armed)

ModelMonitor (@MainActor @Observable)
  ├── Polls OllamaClient every 10 s (running models)
  ├── Fetches library on start + manual Refresh
  ├── Ticks `now` every 1 s for smooth countdowns
  ├── startDaemon() via DaemonController (open -a Ollama)
  └── Exposes models / availableModels / library / loadingModels / state /
        totalVRAM / daemonUp / modelRunning

OllamaClient (Sendable)
  ├── GET  /api/ps          → [RunningModel]
  ├── GET  /api/tags        → [LibraryModel]
  ├── POST /api/generate    → unload  (keep_alive: 0)
  └── POST /api/generate    → load    (keep_alive: 300)

DaemonController (DaemonControlling)
  └── start()  → `open -a Ollama`  (throws .appNotFound if not installed)
```

## Ollama API

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/ps` | GET | Running models + VRAM usage |
| `/api/tags` | GET | All downloaded models |
| `/api/generate` | POST `{"model":"…","keep_alive":0}` | Unload a model |
| `/api/generate` | POST `{"model":"…","keep_alive":300}` | Load a model |

## Not in v1

- Settings UI
- Configurable host / port / poll interval
- Launch at login
- Notarized DMG release
- Per-model history / graphs

## Contributing

Bug reports and pull requests are welcome. Keep PRs scoped to a single concern and include tests for any logic changes.

## License

MIT — see [`LICENSE`](LICENSE).
