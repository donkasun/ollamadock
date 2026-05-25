# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-25

Initial release.

### Added
- Menubar label showing total VRAM in use (`⊡ {total VRAM}`, `0 GB` when idle).
- Running models list with name, VRAM used, idle-unload countdown, and a stop button with confirmation.
- Available models list with disk size and a one-click load button.
- Stop All to unload every running model at once.
- Manual refresh plus auto-refresh every 10 seconds with a 1-second countdown tick.
- No Dock icon (`LSUIElement`).

[Unreleased]: https://github.com/donkasun/ollamadock/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/donkasun/ollamadock/releases/tag/v0.1.0
