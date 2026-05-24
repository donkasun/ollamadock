# OllamaDock — Design Language

This document captures the visual and interaction principles for OllamaDock. We follow Apple's [Human Interface Guidelines for macOS](https://developer.apple.com/design/human-interface-guidelines/macos) and lean on system-provided primitives wherever possible — the goal is for OllamaDock to feel like it shipped with the OS, not like a third-party app trying to look native.

## Principles

1. **System-first.** Use SF Symbols, system fonts, semantic colors, and standard SwiftUI controls. Custom assets are a last resort.
2. **Quiet by default.** The menu bar is shared real estate. We show one tiny glyph + a short string; we never animate, blink, badge, or shout for attention.
3. **One glance, one click.** The whole product is "Is anything loaded? How much? How long?" The popover answers in under a second.
4. **Honesty over decoration.** Loading, empty, and error states are first-class views — not implicit on an empty list.
5. **Keyboard- and accessibility-respectful.** Standard controls inherit Full Keyboard Access, VoiceOver labels, Reduce Motion, Increase Contrast, and Dynamic Type for free. Don't break that.

## Surfaces

### 1. Menu bar label

```
▦  19.5 GB
```

- **Icon:** SF Symbol `cpu` (template image — tints automatically with menu bar foreground color, light/dark, and during menu bar tinting).
- **Text:** Total VRAM across all loaded models, formatted via `ByteCountFormatter` with `[.useGB, .useMB]` and `.memory` style. Reads `Zero KB` when nothing is loaded — deliberately literal rather than a custom `"0 GB"` to match what the OS would render elsewhere.
- **Layout:** `HStack(spacing: 4)`. `.monospacedDigit()` on the text so it doesn't twitch as digits change.
- **Updates:** Reactive via `@Observable` on `ModelMonitor.totalVRAM`. No animation — the menu bar is not a place for transitions.
- **Never:** colored backgrounds, badges, emoji, exclamation marks, "loading…" indicators in the label itself. If state matters, it lives inside the popover.

### 2. Popover

The popover uses `MenuBarExtra(.menuBarExtraStyle: .window)` — a real `NSPopover`-style surface with the system blur material, vibrant shadow, and rounded corners. We do not draw a custom background.

**Dimensions:** Fixed `width: 340`. Height is intrinsic — content drives it. This is the standard width for menu-bar utility popovers (Bartender, Stats, Activity Monitor's menu bar item all land around 320–360pt).

**Vertical rhythm:** `VStack(spacing: 12)`, outer `padding(12)`. The 12pt grid keeps section breaks readable without feeling sparse.

**Section order (top → bottom):**

```
┌──────────────────────────────┐
│  header                      │   "Ollama"  ·  "N loaded · X GB"
├──────────────────────────────┤
│  content (one of 4 states)   │
├──────────────────────────────┤
│  lastUnloadError (if any)    │   red caption, only when relevant
├──────────────────────────────┤
│  footer                      │   Refresh  ·  Unload all  ·  ⌥ Quit
└──────────────────────────────┘
```

### 3. Header

- Left: `Text("Ollama")` in `.headline` — anchors the popover and tells you which daemon you're looking at, in case OllamaDock evolves to support multiple endpoints.
- Right: `Text("N loaded · X GB")` in `.caption` + `.foregroundStyle(.secondary)` — secondary color is `NSColor.secondaryLabelColor`, which adapts to light/dark/accessibility contrast modes automatically.
- Middle dot separator `·` (U+00B7) is the macOS convention for compound metadata (think Finder's "12 items · 4.2 GB").

### 4. Model row

The atomic unit. One per loaded model. Looks like a small card:

```
┌──────────────────────────────────────────┐
│  llama3:8b                            ⏏  │
│  ███████████░░░░░░░░░░░░░░░░░░░░░░░░░    │
│  4.7 GB                            4m 12s │
└──────────────────────────────────────────┘
```

- **Card chrome:** `padding(10)` + `Color.secondary.opacity(0.08)` background + `RoundedRectangle(cornerRadius: 8)`. The 8pt corner is the modern macOS small-element radius (Sonoma's window controls, sheet inputs, and Settings rows all use 8 or 10pt).
- **Name:** `.system(.body, design: .rounded).weight(.medium)`. Rounded SF for personality — Ollama models often have funky names like `qwen3.6:27b-mlx`, and rounded weight handles colons and decimals more gracefully than the default. `.lineLimit(1)` + `.truncationMode(.middle)` so `qwen3.6:27b-mlx-instruct-…-q4_K_M` truncates as `qwen3.6:27b…q4_K_M` and you still see both ends.
- **Eject button:** `Image(systemName: "eject.fill")` in `.buttonStyle(.borderless)`. `.help("Unload \(model.name)")` provides the tooltip on hover and the VoiceOver label. The fill variant matches Apple's pattern for active-state action buttons (vs. outlined for inert/decorative).
- **VRAM bar:** `ProgressView(value: …)` with `.progressViewStyle(.linear)`. We don't customize the bar's appearance — it picks up the system accent color (default macOS blue, but respects user-customized accent and Increase Contrast). The denominator is total system RAM, not "available GPU memory," because Apple Silicon's unified memory has no fixed VRAM ceiling.
- **Metadata footer:** Size on the left, countdown on the right. Both `.caption` + `.secondary`. Countdown uses `.monospacedDigit()` so the seconds tick without horizontal jitter.

### 5. State views (loading / unreachable / empty)

Each state replaces the model list with a centered ~80pt-tall vignette. They share the same shape: optional SF Symbol on top, primary text below in `.subheadline`, secondary hint in `.caption` + `.secondary`.

| State | Icon | Primary | Secondary |
|---|---|---|---|
| Loading | (system `ProgressView`) | "Checking…" | — |
| Unreachable | `exclamationmark.triangle` (`.title2`) | "Ollama isn't running" | "Start Ollama, then press Refresh." |
| Connected, empty | — | "No models loaded" | "Run a model to see it here." |

**Why no custom illustrations:** macOS empty states (Finder, Mail, Notes) use text or single SF Symbols, not illustrations. We follow suit. A menu bar utility that ships with a custom mascot would feel out of place.

### 6. Error caption

When `monitor.lastUnloadError != nil`, a single line of red caption text sits between content and footer:

```swift
Text(error)
    .font(.caption)
    .foregroundStyle(.red)
```

`.foregroundStyle(.red)` resolves to `NSColor.systemRed` — adjusts contrast in Dark Mode and Increase Contrast modes. We do not use a custom hex.

### 7. Footer

```
[ Refresh ]  [ Unload all ]                    [ Quit ]
```

- All three buttons use `.buttonStyle(.bordered)` — the modern macOS pill-shaped buttons, same as Settings panes and macOS 14 alerts.
- **Refresh** is always enabled (you can poll even when unreachable; it triggers the retry).
- **Unload all** is `.disabled(monitor.models.isEmpty)` so it greys out when there's nothing to unload, matching macOS's pattern of always-visible-but-disabled actions (vs. hiding controls, which is a Windows convention).
- **Quit** is right-aligned via a `Spacer()`. Calls `NSApplication.shared.terminate(nil)`.
- No icons on footer buttons. Text is sufficient and reads in any locale.

## Typography

We use system fonts only.

| Use | Style |
|---|---|
| Section heading ("Ollama") | `.headline` |
| Model name | `.system(.body, design: .rounded).weight(.medium)` |
| Body text in state vignettes | `.subheadline` |
| Metadata (count, VRAM size, countdown, hints) | `.caption` + `.foregroundStyle(.secondary)` |
| Errors | `.caption` + `.foregroundStyle(.red)` |
| Anything with numbers that tick | `.monospacedDigit()` |

Dynamic Type works automatically through these styles — if the user bumps font size in System Settings → Accessibility, OllamaDock scales with them.

## Color

We use **only** semantic SwiftUI/AppKit colors:

- `Color.secondary` (text + low-opacity card background)
- `.red` (errors) → `NSColor.systemRed`
- `.accentColor` (`ProgressView` fill) → user's chosen system accent

No hardcoded hex values. No custom asset catalog colors. The popover itself uses `MenuBarExtra(.window)`'s system material, which handles light/dark/vibrancy/wallpaper-tinting automatically.

## Spacing and grid

- **Outer popover padding:** 12pt
- **Section spacing:** 12pt
- **Inside cards (vertical):** 6pt
- **Card inset:** 10pt
- **Card corner radius:** 8pt
- **HStack spacing in label:** 4pt

These map to the macOS 12/8/4 grid family. Stay on the grid unless there's a specific layout reason to deviate.

## Motion

There is no custom animation in v1. SwiftUI's implicit transitions on `@Observable` updates are sufficient — and respecting Reduce Motion is free when we don't add explicit animations.

If a future version adds animation:
- Use `.smooth` or `.easeInOut(duration: 0.2)` — not springs.
- Respect `@Environment(\.accessibilityReduceMotion)`.
- Never animate the menu bar label.

## Accessibility

Native SwiftUI controls give us most of this for free. Things we explicitly do:

- `Button(...).help("Unload \(model.name)")` — both tooltip and VoiceOver label.
- `.monospacedDigit()` on tickers — prevents layout shift that confuses screen readers and people with motion sensitivity.
- Semantic colors — Increase Contrast and Dark Mode just work.
- No keyboard traps. `MenuBarExtra(.window)` is `Esc`-dismissible.

**Known gaps to address post-v1** (tracked in issues):
- Eject button needs `.accessibilityLabel` in addition to `.help` for clarity in some VoiceOver verbosity settings.
- VRAM bar should expose its value via `.accessibilityValue("\(percent) percent of system RAM")`.

## What we explicitly do NOT do

- ❌ Custom window chrome or background
- ❌ Hardcoded colors / hex values
- ❌ Animated menu bar label
- ❌ Custom illustrations or mascots
- ❌ Toast notifications (the inline red caption is sufficient)
- ❌ Modal dialogs (a menu bar utility should never block)
- ❌ Sounds
- ❌ Tracking / telemetry

## References

- [macOS Human Interface Guidelines — The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)
- [HIG — Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [HIG — SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
- [HIG — Color](https://developer.apple.com/design/human-interface-guidelines/color)
- [HIG — Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
