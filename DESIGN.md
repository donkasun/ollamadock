# OllamaDock — Design Language

This document captures the visual and interaction principles for OllamaDock. We follow Apple's [Human Interface Guidelines for macOS](https://developer.apple.com/design/human-interface-guidelines/macos) and lean on system-provided primitives wherever possible — the goal is for OllamaDock to feel like it shipped with the OS, not like a third-party app trying to look native.

## Principles

1. **System-first.** SF Symbols, system fonts, semantic colors, standard SwiftUI controls. Custom assets are a last resort.
2. **Quiet by default.** The menu bar is shared real estate. We show one tiny glyph + a short string; we never animate, blink, badge, or shout for attention.
3. **One glance, one click.** "What's loaded, how much VRAM, can I unload it, can I load another?" — answered without scrolling.
4. **Honesty over decoration.** Loading, empty, and error states are first-class views, not implicit on an empty list.
5. **Confirm destructive actions inline.** Stopping a model takes a click and a confirm — no modal, no toast, no out-of-context dialog.
6. **Keyboard- and accessibility-respectful.** Standard controls inherit Full Keyboard Access, VoiceOver, Reduce Motion, Increase Contrast, and Dynamic Type for free. Don't break that.

## Surfaces

### 1. Menu bar label

```
􀫦  19.5 GB
```

- **Icon:** SF Symbol `cpu` (template image — tints automatically with menu bar foreground color, light/dark, and during menu bar tinting).
- **Text:** Total VRAM across all loaded models, formatted via `ByteCountFormatter` (`[.useGB, .useMB]`, `.memory`). When nothing is loaded we render the literal `0 GB` rather than `ByteCountFormatter`'s default `Zero KB` — short, consistent units, no jarring word-shift between idle and active.
- **Layout:** `HStack(spacing: 4)`. `.monospacedDigit()` on the text so it doesn't twitch as digits change.
- **Updates:** Reactive via `@Observable` on `ModelMonitor.totalVRAM`. No animation — the menu bar is not a place for transitions.
- **Never:** colored backgrounds, badges, emoji, exclamation marks, "loading…" indicators in the label. If state matters, it lives inside the popover.

### 2. Popover

`MenuBarExtra(.window)` — a real `NSPopover`-style surface with the system blur material, vibrant shadow, and rounded corners. We never draw a custom background.

**Dimensions:** Fixed `width: 340`. Height is intrinsic — content drives it. This is the standard width band for menu-bar utility popovers (Bartender, Stats, Activity Monitor's menu bar item all land around 320–360 pt).

**Vertical rhythm:** `VStack(spacing: 12)`, outer `padding(12)`. The 12 pt grid keeps section breaks readable without feeling sparse.

**Section order (top → bottom):**

```
┌──────────────────────────────────────────┐
│  header                                  │   "Ollama"  ·  "N loaded · X GB"
├──────────────────────────────────────────┤
│  LOADED ─────────────────────            │   section header (only if non-empty)
│  ┌────────────────────────────┐          │
│  │ llama3:8b      4m 12s  ◼   │          │   ModelRow
│  └────────────────────────────┘          │
│                                          │
│  AVAILABLE ──────────────────            │   section header (only if non-empty)
│  ┌────────────────────────────┐          │
│  │ qwen3.6:27b-mlx        ▶   │          │   LibraryRow
│  │ 14.2 GB on disk            │          │
│  └────────────────────────────┘          │
├──────────────────────────────────────────┤
│  lastUnloadError (only if non-nil)       │   red caption
├──────────────────────────────────────────┤
│  ↻      Stop All                  ⏻      │   footer
└──────────────────────────────────────────┘
```

States that replace the two sections entirely: **loading**, **unreachable**, **fully empty** (no loaded *and* no library models).

### 3. Header

- Left: `Text("Ollama")` in `.headline` — anchors the popover and identifies which daemon you're looking at, in case OllamaDock evolves to support multiple endpoints.
- Right: `Text("N loaded · X GB")` in `.caption` + `.foregroundStyle(.secondary)`. Secondary color resolves to `NSColor.secondaryLabelColor`, which adapts to light/dark/accessibility contrast modes automatically.
- The middle-dot separator `·` (U+00B7) is the macOS convention for compound metadata (think Finder's "12 items · 4.2 GB").

### 4. Section headers — "LOADED" / "AVAILABLE"

Settings-style sectioning:

- Uppercase caption text in `.foregroundStyle(.secondary)` (`.textCase(.uppercase)` so source stays mixed case for localizers).
- Followed by a 0.5 pt `Rectangle` rule at `Color.secondary.opacity(0.35)` — the same hairline weight used in `Form` and `List` section dividers in macOS 14.
- Only rendered when their section has at least one row, so the popover doesn't get top-heavy when only one side is populated.

### 5. ModelRow — the "Loaded" row

The rule for a loaded model is: **you already know its size from the header; you mainly want to know how long it'll stick around and whether you can free it now.** So the row is a single-line `HStack`:

```
┌──────────────────────────────────────────┐
│  llama3:8b              4m 12s     ◼     │
└──────────────────────────────────────────┘
```

- **Card chrome:** `padding(10)` + `Color.secondary.opacity(0.08)` background + `RoundedRectangle(cornerRadius: 8)`. 8 pt is the modern macOS small-element radius (Sonoma's window controls, sheet inputs, and Settings rows all use 8 or 10 pt).
- **Name:** `.system(.body, design: .rounded).weight(.medium)`. Rounded SF for personality — Ollama model names have colons, decimals, and tags (`qwen3.6:27b-mlx-instruct-q4_K_M`), and rounded weight handles those gracefully. `.lineLimit(1)` + `.truncationMode(.middle)` so long tags truncate as `qwen3.6…q4_K_M` and you still see both ends.
- **Countdown:** `.caption` + `.monospacedDigit()` + `.foregroundStyle(.secondary)`. Format: `4m 12s`, `42s`, or `unloading…` once the deadline passes. Monospaced digits prevent horizontal jitter as the timer ticks.
- **Stop button:** `Image(systemName: "stop.fill")`, `.buttonStyle(.borderless)`, `.help("Stop \(model.name)")`. `stop.fill` is the Activity Monitor / QuickTime convention for halting a running process — clearer than `eject` for "kill this model right now."

**Inline destructive confirmation.** Tapping ◼ flips the right side into a two-button confirm strip (`@State var confirming`):

```
┌──────────────────────────────────────────┐
│  llama3:8b              Stop?  Cancel    │
└──────────────────────────────────────────┘
```

- "Stop?" in `.foregroundStyle(.red)` — the affirmative is the destructive choice, so it gets the warning color. Tap commits the unload and resets state.
- "Cancel" returns the row to its resting form.
- Both buttons are `.borderless` `.caption` so the row height doesn't jump.
- This is the [Finder-empty-trash](https://developer.apple.com/design/human-interface-guidelines/alerts) pattern but inline: no modal, no toast, no out-of-context dialog. Reversibility is one click away until you press the red button.

**Why no VRAM bar per row.** The earlier draft showed a linear `ProgressView` of `sizeVRAM / totalRAM` under each row. We pulled it because:
- The header already shows aggregate VRAM in use.
- For most users, every loaded model occupies a similar fraction of unified memory, so the bars all look the same — high noise, low signal.
- Compact single-line rows mean more models fit before the popover starts scrolling.

### 6. LibraryRow — the "Available" row

Models that are pulled but not currently loaded. Two lines because the size on disk is genuinely useful here (it's how much RAM the load will consume):

```
┌──────────────────────────────────────────┐
│  qwen3.6:27b-mlx                ▶        │
│  14.2 GB on disk                         │
└──────────────────────────────────────────┘
```

- Same card chrome as `ModelRow` (`padding(10)`, secondary 8% background, 8 pt radius).
- Name styled identically to `ModelRow` so loaded and unloaded models read as siblings.
- Size: `"\(ByteFormatter.format(model.sizeOnDisk)) on disk"` in `.caption` + `.secondary`. The literal " on disk" suffix disambiguates from VRAM size shown elsewhere.
- **Load button:** `Image(systemName: "play.fill")`. Affirmative-action symbol — same conceptual axis as the stop button. `.help("Load \(model.name)")`.
- **While loading:** replace the play button with a small spinner (`ProgressView().scaleEffect(0.7)` in a 16×16 frame) so the user can see the request is in flight. The button doesn't reappear until the model lands in the Loaded section on the next poll.

### 7. State views — loading / unreachable / empty

When neither section has rows, the content area collapses to a centered ~80 pt vignette. They share the same shape: optional SF Symbol on top, primary text below in `.subheadline`, secondary hint in `.caption` + `.secondary`.

| State | Icon | Primary | Secondary |
|---|---|---|---|
| Loading | (system `ProgressView`) | "Checking…" | — |
| Unreachable | `exclamationmark.triangle` (`.title2`) | "Ollama isn't running" | "Start Ollama, then press Refresh." |
| Connected, fully empty | — | "No models loaded" | "Run a model to see it here." |

The "fully empty" branch fires only when `monitor.models.isEmpty && monitor.availableModels.isEmpty`. If you have library models pulled but none loaded, you see the Available section, not the empty state — because there's something useful you can do (press ▶ to load one).

**Why no custom illustrations:** macOS empty states (Finder, Mail, Notes) use text or single SF Symbols, never illustrations. We follow suit.

### 8. Error caption

When `monitor.lastUnloadError != nil`, a single line of red caption text sits between content and footer:

```swift
Text(error)
    .font(.caption)
    .foregroundStyle(.red)
```

`.foregroundStyle(.red)` resolves to `NSColor.systemRed` — adjusts contrast in Dark Mode and Increase Contrast modes. No custom hex.

### 9. Footer

```
[ ↻ ]   [ Stop All ]                          [ ⏻ ]
```

- **All three buttons** use `.buttonStyle(.bordered)` — the modern macOS pill-shaped buttons, same as Settings panes and macOS 14 alerts.
- **Refresh (↻):** icon-only `arrow.clockwise` with `.help("Refresh")`. Always enabled — pressing it while unreachable forces an immediate retry. Refresh triggers both `monitor.refresh()` (loaded models) and `monitor.refreshLibrary()` (available models) so one tap synchronises the whole popover.
- **Stop All:** text label, not icon. Destructive batch action deserves an explicit verb. `.disabled(monitor.models.isEmpty)` so it greys out when there's nothing loaded.
- **Quit (⏻):** icon-only `power` symbol, right-aligned via `Spacer()`, with `.help("Quit")`. Calls `NSApplication.shared.terminate(nil)`.

**Why icons for Refresh and Quit, text for Stop All.** Refresh and Quit are universal — every menu-bar utility has them, and the symbols are unambiguous. Stop All is destructive and project-specific; spelling it out reduces the risk of an accidental tap.

## Typography

System fonts only.

| Use | Style |
|---|---|
| Section heading ("Ollama") | `.headline` |
| Model name (Loaded + Available) | `.system(.body, design: .rounded).weight(.medium)` |
| Body text in state vignettes | `.subheadline` |
| Section dividers ("LOADED" / "AVAILABLE") | `.caption` + `.secondary` + `.textCase(.uppercase)` |
| Metadata (count, size on disk, countdown, hints) | `.caption` + `.foregroundStyle(.secondary)` |
| Destructive confirm ("Stop?") | `.caption` + `.foregroundStyle(.red)` |
| Errors | `.caption` + `.foregroundStyle(.red)` |
| Anything with numbers that tick | `.monospacedDigit()` |

Dynamic Type works automatically through these styles — if the user bumps font size in System Settings → Accessibility, OllamaDock scales with them.

## Color

We use **only** semantic SwiftUI/AppKit colors:

- `Color.secondary` — text, hairline rules (`0.35` opacity), card backgrounds (`0.08` opacity)
- `.red` (destructive confirm, errors) → `NSColor.systemRed`
- `.accentColor` → user's chosen system accent (currently used by spinner only)

No hardcoded hex values. No custom asset catalog colors. The popover itself uses `MenuBarExtra(.window)`'s system material, which handles light/dark/vibrancy/wallpaper-tinting automatically.

## Spacing and grid

- **Outer popover padding:** 12 pt
- **Section spacing:** 12 pt
- **Inside cards (vertical):** 6 pt
- **Card inset:** 10 pt
- **Card corner radius:** 8 pt
- **Section header spacing:** 6 pt
- **HStack spacing in menu bar label:** 4 pt
- **Confirm strip spacing:** 6 pt

These map to the macOS 12 / 8 / 4 grid family. Stay on the grid unless there's a specific layout reason to deviate.

## Iconography

| Symbol | Used for | Why |
|---|---|---|
| `cpu` | Menu bar glyph | Matches the "what's using my compute" frame |
| `stop.fill` | Stop a loaded model | Activity Monitor / QuickTime convention for halting |
| `play.fill` | Load an available model | Symmetric affirmative of stop |
| `arrow.clockwise` | Refresh | Universal refresh glyph |
| `power` | Quit | Standard quit-app symbol in menu-bar utilities |
| `exclamationmark.triangle` | Unreachable state | HIG-recommended warning glyph (non-blocking) |

All `Image(systemName: …)` — no custom assets ship in the bundle.

## Motion

There is no custom animation in v1. SwiftUI's implicit transitions on `@Observable` updates are sufficient — and respecting Reduce Motion is free when we don't add explicit animations.

Two places where animation could land later:
- The Stop confirm strip could fade/slide in (`.transition(.opacity)`).
- A loaded model appearing in the list could fade in.

Rules for any future animation:
- Use `.smooth` or `.easeInOut(duration: 0.2)` — not springs.
- Respect `@Environment(\.accessibilityReduceMotion)`.
- Never animate the menu bar label.

## Accessibility

Native SwiftUI controls give us most of this for free. Things we explicitly do:

- `.help("…")` on every icon-only button (Refresh, Quit, Stop, Load, in-progress spinners). `.help` populates both the macOS tooltip and the VoiceOver label.
- `.monospacedDigit()` on tickers — prevents layout shift that confuses screen readers and people with motion sensitivity.
- **Two-step destructive confirm** — destructive actions are reversible until commit, which matters for anyone using switch control or other slower input methods.
- Semantic colors — Increase Contrast and Dark Mode just work.
- No keyboard traps. `MenuBarExtra(.window)` is `Esc`-dismissible.

**Known gaps to address post-v1** (tracked in issues):
- Add `.accessibilityLabel` alongside `.help` on icon buttons for VoiceOver verbosity settings where tooltips are skipped.
- Library row's loading spinner needs an `.accessibilityLabel("Loading \(model.name)")`.

## What we explicitly do NOT do

- ❌ Custom window chrome or background
- ❌ Hardcoded colors / hex values
- ❌ Animated menu bar label
- ❌ Custom illustrations or mascots
- ❌ Toast notifications (the inline red caption is sufficient)
- ❌ Modal dialogs (a menu bar utility should never block — confirmations live inline)
- ❌ Per-row VRAM progress bars (high noise, low signal — see ModelRow rationale)
- ❌ Sounds
- ❌ Tracking / telemetry

## References

- [macOS Human Interface Guidelines — The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)
- [HIG — Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [HIG — SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
- [HIG — Color](https://developer.apple.com/design/human-interface-guidelines/color)
- [HIG — Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [HIG — Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) (for the inline-confirm pattern philosophy)
