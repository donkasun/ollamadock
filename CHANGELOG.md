# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-05-26

### Fixed
- Menu bar status dot now lines up vertically with the VRAM text (it sat slightly too high before).

### Changed
- Rewrote the README in plainer, friendlier language and corrected the first-launch (Gatekeeper) instructions for current macOS.

## [0.2.0] - 2026-05-26

### Added
- Menubar status dot showing model state at a glance (green when a model is loaded, white when idle), alongside the VRAM total.
- Popover status bar with two labeled dots: Ollama daemon up/down and model loaded/none.
- Start Ollama from the popover when the daemon is down, with a link to ollama.com when the app isn't installed.
- Inline expanding confirmation for Stop All, matching the per-model stop confirm.

### Changed
- Stop-a-model and Quit OllamaDock confirmations now expand inline (inside the card and below the footer) instead of using an inline strip or quitting immediately.

## [0.1.0] - 2026-05-25

Initial release.

### Added
- Menubar label showing total VRAM in use (`⊡ {total VRAM}`, `0 GB` when idle).
- Running models list with name, VRAM used, idle-unload countdown, and a stop button with confirmation.
- Available models list with disk size and a one-click load button.
- Stop All to unload every running model at once.
- Manual refresh plus auto-refresh every 10 seconds with a 1-second countdown tick.
- No Dock icon (`LSUIElement`).

[Unreleased]: https://github.com/donkasun/ollamadock/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/donkasun/ollamadock/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/donkasun/ollamadock/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/donkasun/ollamadock/releases/tag/v0.1.0
