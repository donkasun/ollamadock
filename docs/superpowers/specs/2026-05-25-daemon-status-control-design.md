# Daemon Status & Control — Design

**Goal:** Surface Ollama daemon status in the menu bar as stacked status dots, and let the user start or quit the daemon from the popover.

## Motivation

The menu bar label currently shows only total VRAM with a `cpu` glyph. It gives no
indication of whether the Ollama daemon is even running, and the app offers no way to
start or stop the daemon. Users who find the daemon down have to leave the app to fix it.

This adds an at-a-glance status indicator and one-click recovery, without taking on the
footguns of raw process management (PATH hunting, child-process lifecycle, supervisor
respawn). We delegate to the official Ollama.app via `open` and `osascript`.

## Menu bar label

`MenuBarLabel` is extended from `totalVRAM`-only to two boolean status inputs plus VRAM:

- `daemonUp: Bool` — drives the **bottom** dot. Green when the daemon is reachable, grey when down.
- `modelRunning: Bool` — drives the **top** dot. Green when at least one model is loaded, grey when idle.
- `totalVRAM: UInt64` — the VRAM text, shown only when `daemonUp` is true; hidden when the daemon is down.

Layout: two dots stacked vertically (top = model, bottom = daemon), VRAM text to the right.

State mapping, derived in `OllamaDockApp` / passed from `ModelMonitor`:

| `ConnectionState` | `daemonUp` | `modelRunning` | VRAM shown |
|---|---|---|---|
| `.connected` | `true` | `!models.isEmpty` | yes |
| `.unreachable` | `false` | `false` | no |
| `.loading` | `false` | `false` | no |
| `.protocolError` | `true` | `false` | no |

`.protocolError` means the daemon responded but with something we can't read, so the daemon
is considered up while model state is unknown (top dot grey, VRAM hidden).

Dot colors use `Color.green` / `Color.secondary` (grey) so they adapt to light/dark mode.

## DaemonController

A small `Sendable` type behind a protocol, mirroring the injectable `OllamaClient` pattern
so `ModelMonitor` tests can substitute a fake and avoid spawning real processes.

```swift
enum DaemonControlError: Error, Equatable {
    case appNotFound          // open -a Ollama failed to locate the app
    case commandFailed(Int32) // process exited non-zero
}

protocol DaemonControlling: Sendable {
    func start() async throws
    func quit() async throws
}
```

`DaemonController` (the production conformer) runs commands via `Process`:

- `start()` → `/usr/bin/open -a Ollama`. A non-zero exit (app not installed) maps to
  `DaemonControlError.appNotFound`. Any other launch failure maps to `commandFailed`.
- `quit()` → `/usr/bin/osascript -e 'quit app "Ollama"'`. Non-zero exit maps to `commandFailed`.

Process execution runs off the main actor. The controller exposes `async throws` methods;
internally it waits for process termination and inspects `terminationStatus`.

No `ollama serve` spawning, no PATH hunting, no kill-by-PID. The daemon's lifecycle stays
owned by Ollama.app.

## ModelMonitor wiring

`ModelMonitor` gains a `DaemonControlling` dependency (injected, defaulting to a real
`DaemonController`) and two methods plus an error field, following the existing
`lastLoadError` / `lastUnloadError` pattern:

```swift
private(set) var lastDaemonError: String?

func startDaemon() async { ... }
func quitDaemon() async { ... }
```

- `startDaemon()` calls `controller.start()`. On `appNotFound`, sets a distinct sentinel so
  the UI can show the install guide; on other errors, sets a generic failure message; on
  success, clears `lastDaemonError`. Then calls `refresh()` so the dots update promptly.
- `quitDaemon()` calls `controller.quit()`, surfaces failures into `lastDaemonError`, then
  `refresh()`.

`lastDaemonError` is cleared on popover reopen alongside the existing action errors
(extend `clearActionErrors()`).

To let the UI distinguish "not installed" from a generic failure, `startDaemon()` records
which case occurred. The simplest representation: a separate `private(set) var
daemonNotInstalled: Bool` flag set true on `appNotFound`, false otherwise. The popover keys
the install-guide message off that flag.

## Popover UI

Two changes to `PopoverView`:

1. **Daemon down (`.unreachable`):** the existing "Ollama isn't running" content area gains a
   **Start Ollama** button that calls `monitor.startDaemon()`. When `monitor.daemonNotInstalled`
   is true, the area instead shows "Ollama isn't installed" with a hint to get it at
   `ollama.com` (a `Link`). The `.loading` and `.protocolError` states are unchanged.

2. **Daemon up (`.connected`):** the footer gains a **Quit Ollama** control, presented behind
   a confirmation dialog (reuse the existing stop-model confirmation pattern —
   `.confirmationDialog`). Confirming calls `monitor.quitDaemon()`.

`lastDaemonError` renders in the same red-caption error region used for unload/load errors.

## Error handling

- `start()` / `quit()` failures never crash; they surface as `lastDaemonError` text.
- `appNotFound` is treated as a distinct, non-error UX (install guidance), not a red error.
- A daemon action is always followed by a `refresh()` so the menu bar dots and popover content
  reflect reality within one poll, not after the 10 s interval.

## Testing

- **`DaemonController` boundary:** `ModelMonitor` tests inject a fake `DaemonControlling` that
  records calls and can be primed to throw `appNotFound` / `commandFailed`. Assert:
  `startDaemon()` / `quitDaemon()` call through; `appNotFound` sets `daemonNotInstalled = true`;
  other errors set `lastDaemonError`; success clears both; a `refresh()` follows each action.
- **`MenuBarLabel`:** dot color is a pure function of `(daemonUp, modelRunning)` and VRAM
  visibility a pure function of `daemonUp` — assert these directly.
- **State mapping:** verify the `ConnectionState` → `(daemonUp, modelRunning)` table, including
  the `.protocolError` edge case.
- The real `DaemonController` (which spawns `Process`) is not unit-tested against live binaries;
  its logic is thin exit-code mapping. Manual verification covers the live path.

## Out of scope

- Spawning `ollama serve` directly or locating the binary on PATH.
- Killing the daemon by PID / SIGTERM.
- Configurable daemon app name or path.
- Detecting *how* Ollama was installed (Homebrew service, manual, etc.).
