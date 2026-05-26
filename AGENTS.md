## Learned User Preferences

- Prefers macOS-native aesthetic; follow `docs/DESIGN.md` for visual and interaction patterns.
- Uses subagent-driven development for multi-step implementation work.
- Intends this repo as a public open-source project shared on GitHub.

## Learned Workspace Facts

- OllamaDock is a native macOS menubar app (Swift/SwiftUI, MenuBarExtra, macOS 14 Sonoma+).
- Public repo: https://github.com/donkasun/ollamadock (MIT license).
- XcodeGen (`project.yml`) is the source of truth for the `.xcodeproj`.
- Ollama integration polls `GET localhost:11434/api/ps`; unloads via POST with `keep_alive: 0`.
- Popover UI has RUNNING (ModelRow) and AVAILABLE (LibraryRow) sections; footer uses borderless icon buttons.
- Model rows show name, idle countdown, and a stop confirm that expands downward inside the card; no per-row VRAM progress bar.
- Menu bar label is a single model-status dot (green loaded / white idle) + VRAM; rendered as a non-template NSImage because MenuBarExtra template-tints SwiftUI content.
- Popover has a status bar (daemon + model dots with labels); daemon can be started via DaemonController (`open -a Ollama`) but quitting it is intentionally not offered. Quit OllamaDock has an inline expanding confirmation.
