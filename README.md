# OllamaDock

A native macOS menubar app that shows which Ollama models are currently loaded in GPU memory — the GUI equivalent of `ollama ps`.

## Status

Pre-alpha — v1 is being built. See [`docs/superpowers/plans/2026-05-24-ollamadock-v1.md`](docs/superpowers/plans/2026-05-24-ollamadock-v1.md) for the implementation plan and [`CONTEXT.md`](CONTEXT.md) for product context.

## Planned features

- Always-visible menubar label: `▦ {total VRAM}` (e.g. `▦ 19 GB`, `▦ 0 GB` when idle)
- Popover lists each loaded model with:
  - Name
  - VRAM bar (share of system RAM)
  - Idle-unload countdown (updated every second)
  - One-click unload
- Footer actions: Refresh, Unload all, Quit
- Auto-refresh every 5 seconds
- No dock icon (LSUIElement)

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15 or later
- [Ollama](https://ollama.com) running locally on `http://localhost:11434`

## Build & run

Once the project is scaffolded:

```bash
git clone https://github.com/donkasun/ollamadock.git
cd ollamadock
open OllamaDock.xcodeproj
```

Select the `OllamaDock` scheme and press ⌘R.

## Contributing

This is an early open-source project. Issues and PRs are welcome once v1 lands. Please keep PRs scoped to a single concern.

## License

MIT — see [`LICENSE`](LICENSE).
