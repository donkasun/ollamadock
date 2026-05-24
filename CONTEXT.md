# OllamaDock — Project Context

## What is this?

A native macOS menubar app that shows which Ollama models are currently loaded in GPU memory — the GUI equivalent of `ollama ps`.

## Why

- The official **Ollama.app** menubar icon is too minimal — it doesn't show loaded models
- **Ollamac** is just a chat client, not a monitor
- No lightweight native Mac app currently mirrors `ollama ps` in a GUI

## What it should do

- Live menubar icon/popover showing currently loaded models
- VRAM usage per model
- Countdown timer until each model unloads (idle timeout)
- One-click unload button per model
- Auto-refresh every ~5 seconds

## Tech stack

- **Swift + SwiftUI** (native macOS)
- **MenuBarExtra** API (macOS 13+) — makes menubar apps trivial
- **Ollama REST API** — poll `GET http://localhost:11434/api/ps` for running models

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

## Complexity estimate

| Feature | Effort |
|---|---|
| Menubar icon + popover | ~1 hour |
| Poll Ollama API + show models | ~1–2 hours |
| VRAM usage bar | ~1 hour |
| Unload model button | ~1 hour |
| Auto-refresh + idle countdown | ~1 hour |

**Total for solid v1: ~1 day**

## Core skeleton

```swift
@main
struct OllamaDockApp: App {
    var body: some Scene {
        MenuBarExtra("Ollama", systemImage: "cpu") {
            OllamaStatusView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

## Requirements

- macOS 13+ (Ventura or later)
- Xcode
- Ollama running locally on port 11434

## Status

- [ ] Project scaffolded
- [ ] Menubar icon + popover
- [ ] Ollama API integration
- [ ] Model list UI
- [ ] VRAM + countdown display
- [ ] Unload model action
