# Design: Library Panel — Show All Downloaded Models

**Date:** 2026-05-24  
**Branch:** feat/v1-scaffold (to be continued on a new feature branch)  
**Status:** Approved — ready for implementation planning

---

## Goal

Extend the OllamaDock popover to show every downloaded Ollama model, not just the ones currently loaded in VRAM. Unloaded models get a ▶ load button; loaded models keep the existing ⏏ eject button.

---

## Fetch Strategy

`GET /api/tags` is polled on a **10-minute interval**, plus immediately on app start and whenever the user taps Refresh. The library (which models are on disk) changes rarely (only on `ollama pull` / `ollama rm`), so a slow background cadence is sufficient. The 5-second poll loop continues to target only `GET /api/ps` (which models are in VRAM).

`ModelMonitor` runs a dedicated `libraryTask` loop (alongside the existing `pollTask` and `tickTask`) that sleeps 600 seconds between fetches. The Refresh button triggers an immediate out-of-cycle fetch in addition to waking the next scheduled one.

---

## Data Layer

### New type: `LibraryModel`

```swift
struct LibraryModel: Equatable, Identifiable, Decodable {
    let name: String
    let sizeOnDisk: UInt64   // "size" field from /api/tags response

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name
        case sizeOnDisk = "size"
    }
}
```

### New type: `TagsResponse`

```swift
struct TagsResponse: Decodable {
    let models: [LibraryModel]
}
```

### New `OllamaClient` methods

**`fetchLibrary() async throws -> [LibraryModel]`**  
`GET /api/tags` — decodes `TagsResponse`, returns the models array. Throws `OllamaClientError` on non-2xx or transport failure (same pattern as `fetchRunning`).

**`load(modelName: String) async throws`**  
`POST /api/generate` with body `{"model": "<name>", "keep_alive": 300}` and no `prompt` key. This is the official Ollama API idiom for warming a model into VRAM without generating text. Throws on non-2xx.

### Protocol extension

`OllamaClienting` gains two new requirements:
```swift
func fetchLibrary() async throws -> [LibraryModel]
func load(modelName: String) async throws
```

---

## ModelMonitor Changes

### New properties

| Property | Type | Purpose |
|---|---|---|
| `library` | `[LibraryModel]` | All downloaded models from `/api/tags` |
| `loadingModels` | `Set<String>` | Names of models with an in-flight load request |

### New computed property

```swift
var availableModels: [LibraryModel] {
    let loadedNames = Set(models.map(\.name))
    return library.filter { !loadedNames.contains($0.name) }
}
```

### New / changed methods

**`refreshLibrary() async`** (new)  
Calls `client.fetchLibrary()`. On success, updates `library`. On failure, leaves `library` unchanged (silently — the library is a best-effort complement to the loaded list; losing it doesn't break core functionality).

**`start()`** (updated)  
Starts a third background task — `libraryTask` — that calls `refreshLibrary()` immediately, then loops with a 600-second (10-minute) sleep between fetches. Same `[weak self]` / `Task.isCancelled` guard pattern as `pollTask` and `tickTask`.

**`stop()`** (updated)  
Cancels and nils `libraryTask` alongside `pollTask` and `tickTask`.

**`refresh()` in Refresh button** (updated in view, not monitor)  
The monitor's `refresh()` method is unchanged. The Refresh button now calls both `monitor.refresh()` and `monitor.refreshLibrary()` in sequence — the manual call is an out-of-cycle fetch; it does not reset the 10-minute timer.

**`load(modelName: String) async`** (new)  
```
loadingModels.insert(modelName)
try? await client.load(modelName: modelName)   // failure is silent; refresh will reveal state
await refresh()
loadingModels.remove(modelName)
```
Uses `try?` — if Ollama rejects the load (e.g. model not found), the next `refresh()` will show no change in the Loaded section, which is accurate. A future enhancement could surface a load error via `lastLoadError`.

---

## View Layer

### `PopoverView` — updated `content` section

The `connected` branch of the `@ViewBuilder` is replaced with two optional sub-sections:

```
if !monitor.models.isEmpty {
    SectionHeader("Loaded")
    ForEach(monitor.models) { ModelRow(...) }
}
if !monitor.availableModels.isEmpty {
    SectionHeader("Available")
    ForEach(monitor.availableModels) { LibraryRow(...) }
}
if monitor.models.isEmpty && monitor.availableModels.isEmpty {
    // existing "No models loaded" placeholder
}
```

`SectionHeader` is a small inline helper view: left-aligned text in `.caption` / `.secondary` style with a horizontal rule, matching the mockup.

### New view: `LibraryRow`

Mirrors the layout of `ModelRow` but simpler:

```
HStack {
    Text(model.name)           // .body .rounded .medium, truncated middle
    Spacer()
    if monitor.loadingModels.contains(model.name) {
        ProgressView()         // spinner while loading
    } else {
        Button { Task { await monitor.load(model.name) } } label: {
            Image(systemName: "play.fill")
        }
        .buttonStyle(.borderless)
        .help("Load \(model.name)")
    }
}
Text(format(model.sizeOnDisk) + " on disk")   // .caption .secondary
```

Wrapped in the same rounded card background as `ModelRow`.

### Header subtitle (unchanged)

`"X loaded · VRAM"` — the available count is implicit from the Available section. No change needed to the header.

### Refresh button

```swift
Button("Refresh") {
    Task {
        await monitor.refresh()
        await monitor.refreshLibrary()
    }
}
```

---

## Error Handling

| Failure | Behaviour |
|---|---|
| `fetchLibrary()` fails on start | `library` stays empty; Available section is hidden. Core loaded-model monitoring unaffected. |
| `fetchLibrary()` fails on Refresh | Same — silently no-ops. |
| `load()` fails | `loadingModels` entry is removed after `refresh()`. The model does not appear in Loaded. No explicit error shown in v1 (future: `lastLoadError`). |

---

## Testing

New unit tests in `OllamaClientTests`:
- `test_fetchLibrary_decodes_tags_response` — mock fixture `tags_two_models.json`
- `test_fetchLibrary_non200_throws` — mock 500 response
- `test_load_posts_correct_body` — verify POST body contains `model` and `keep_alive: 300`, no `prompt`

New unit tests in `ModelMonitorTests`:
- `test_availableModels_excludes_loaded_names` — library has A,B; loaded has A → available is [B]
- `test_load_adds_and_removes_from_loadingModels` — verify spinner state transitions
- `test_refreshLibrary_updates_library` — mock client returns two models

New fixture file: `OllamaDockTests/Fixtures/tags_two_models.json`

---

## Out of Scope (v1.1+)

- Explicit load-error banner (`lastLoadError` equivalent for load)
- Progress indication during model load (Ollama doesn't expose load progress via REST)
- Pulling new models from the registry
- Sorting / filtering the library list
