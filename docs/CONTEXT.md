# OllamaDock — Project Context

## What is this?

A native macOS menubar app that shows which Ollama models are currently loaded in GPU memory — the GUI equivalent of `ollama ps`.

## Why

- The official **Ollama.app** menubar icon is too minimal — it doesn't show loaded models
- **Ollamac** is just a chat client, not a monitor
- No lightweight native Mac app currently mirrors `ollama ps` in a GUI

## What it does (v1)

- Live menubar label showing total VRAM in use (`▦ {VRAM}`, or `▦ Zero KB` when idle)
- Popover lists each loaded model with name, VRAM bar (share of system RAM), idle-unload countdown
- One-click unload (⏏) per model, plus "Unload all"
- Auto-refresh every 5 seconds; 1-second tick for smooth countdowns
- Four states: loading, connected with models, connected empty, Ollama unreachable

## Tech stack

- **Swift 5.9 + SwiftUI** (native macOS, `MenuBarExtra` + `@Observable` + `@Bindable`)
- **macOS 14 Sonoma+** (required for `@Observable` and `@Bindable`)
- **Ollama REST API** — polls `GET http://localhost:11434/api/ps`, unloads via `POST /api/generate` with `keep_alive: 0`
- **XcodeGen** for reproducible `.xcodeproj` generation
- **MIT** license

## Ollama API

```
GET http://localhost:11434/api/ps
```

Returns JSON:
```json
{
  "models": [
    {
      "name": "qwen3.6:27b-mlx",
      "model": "qwen3.6:27b-mlx",
      "size": 19000000000,
      "digest": "60b0437bbd02",
      "details": { ... },
      "expires_at": "2026-05-24T11:20:00Z",
      "size_vram": 19000000000
    }
  ]
}
```

## Architecture

See [`README.md`](README.md#architecture) for the full tree. Brief summary:

```
OllamaDockApp (@main)
  └─ MenuBarExtra(label: MenuBarLabel, content: PopoverView)
       └─ ModelMonitor (@MainActor @Observable)
             └─ OllamaClient (Sendable, URLSession-backed)
```

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15
- Ollama running locally on port 11434

## Status

v1 implementation complete on `feat/v1-scaffold` (20 unit tests passing). Pending: manual GUI verification against a live Ollama daemon.

- [x] Project scaffolded (XcodeGen + Xcode project)
- [x] Menubar label + popover
- [x] Ollama API integration (`fetchRunning`, `unload`)
- [x] Model list UI with VRAM bar + countdown
- [x] Unload action (per-model + Unload all)
- [x] Polling + idle countdown
- [ ] Manual end-to-end verification with live Ollama

## Not in v1

Settings UI · configurable host/port/interval · launch at login · notarized DMG release · per-model history graphs
