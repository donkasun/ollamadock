# Library Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show all downloaded Ollama models in the popover (not just loaded ones), with ▶ load / ⏏ eject buttons, grouped into "Loaded" and "Available" sections.

**Architecture:** Add `LibraryModel` + `TagsResponse` data types; extend `OllamaClienting` with `fetchLibrary()` and `load()`; add `library`, `loadingModels`, `availableModels`, `refreshLibrary()`, and `load()` to `ModelMonitor`; change `pollTask` from 5 s to 10 s; call `refreshLibrary()` once on `start()` and on Refresh; add `LibraryRow` view and update `PopoverView` with two sections.

**Tech Stack:** Swift 5.9, SwiftUI, `@Observable`, `@Bindable`, `URLSession`, `ByteCountFormatter`, XCTest + `MockURLProtocol`, XcodeGen

**Spec:** `docs/superpowers/specs/2026-05-24-library-panel-design.md`

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| **Create** | `OllamaDock/Models/LibraryModel.swift` | `LibraryModel` struct + `TagsResponse` |
| **Create** | `OllamaDock/Views/LibraryRow.swift` | Row view for unloaded models |
| **Create** | `OllamaDockTests/Fixtures/tags_two_models.json` | Fixture for `/api/tags` tests |
| **Modify** | `project.yml` | Register new fixture as resource |
| **Modify** | `OllamaDock/Networking/OllamaClient.swift` | Add `fetchLibrary()` + `load()` to protocol and class |
| **Modify** | `OllamaDock/Monitor/ModelMonitor.swift` | Library state, actions, 10 s poll, initial library fetch |
| **Modify** | `OllamaDock/Views/PopoverView.swift` | Two sections, `SectionHeader`, updated Refresh button |
| **Modify** | `OllamaDockTests/OllamaClientTests.swift` | Tests for `fetchLibrary` + `load` |
| **Modify** | `OllamaDockTests/ModelMonitorTests.swift` | Updated `StubClient` + new monitor tests |

---

### Task 1: LibraryModel, TagsResponse, fixture, project registration

**Files:**
- Create: `OllamaDock/Models/LibraryModel.swift`
- Create: `OllamaDockTests/Fixtures/tags_two_models.json`
- Modify: `project.yml`

- [ ] **Step 1: Create the fixture**

`OllamaDockTests/Fixtures/tags_two_models.json`:
```json
{"models":[{"name":"gemma4:e2b-mlx","size":7069822916,"modified_at":"2026-05-24T09:42:12Z","digest":"c4e49a77005e"},{"name":"qwen3.6:27b-mlx","size":19763233079,"modified_at":"2026-05-24T09:39:52Z","digest":"60b0437bbd02"}]}
```

- [ ] **Step 2: Create LibraryModel.swift**

`OllamaDock/Models/LibraryModel.swift`:
```swift
import Foundation

struct LibraryModel: Equatable, Identifiable, Decodable {
    let name: String
    let sizeOnDisk: UInt64

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name
        case sizeOnDisk = "size"
    }
}

struct TagsResponse: Decodable {
    let models: [LibraryModel]
}
```

- [ ] **Step 3: Register the fixture in project.yml**

In `project.yml`, add the new fixture alongside the existing three under `OllamaDockTests.sources`. The block currently ends with:
```yaml
      - path: OllamaDockTests/Fixtures/ps_malformed.json
        buildPhase: resources
```
Append after that line:
```yaml
      - path: OllamaDockTests/Fixtures/tags_two_models.json
        buildPhase: resources
```

- [ ] **Step 4: Regenerate the Xcode project**

```bash
cd /path/to/ollamadock
xcodegen generate
```
Expected: `Generating project OllamaDock` with no errors.

- [ ] **Step 5: Build to verify new types compile**

```bash
xcodebuild -scheme OllamaDock -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add OllamaDock/Models/LibraryModel.swift \
        OllamaDockTests/Fixtures/tags_two_models.json \
        project.yml \
        OllamaDock.xcodeproj/project.pbxproj
git commit -m "feat(models): LibraryModel + TagsResponse + tags fixture"
```

---

### Task 2: Extend OllamaClienting protocol + update StubClient

**Files:**
- Modify: `OllamaDock/Networking/OllamaClient.swift`
- Modify: `OllamaDockTests/ModelMonitorTests.swift`

- [ ] **Step 1: Add the two new requirements to OllamaClienting**

In `OllamaDock/Networking/OllamaClient.swift`, replace:
```swift
protocol OllamaClienting: Sendable {
    func fetchRunning() async throws -> [RunningModel]
    func unload(modelName: String) async throws
}
```
With:
```swift
protocol OllamaClienting: Sendable {
    func fetchRunning() async throws -> [RunningModel]
    func unload(modelName: String) async throws
    func fetchLibrary() async throws -> [LibraryModel]
    func load(modelName: String) async throws
}
```

- [ ] **Step 2: Add stub conformance to StubClient in ModelMonitorTests**

`OllamaDockTests/ModelMonitorTests.swift` — replace the existing `StubClient` class with:
```swift
final class StubClient: OllamaClienting, @unchecked Sendable {
    var fetchResult: Result<[RunningModel], Error> = .success([])
    var unloadCalls: [String] = []
    var unloadError: Error?

    var libraryResult: Result<[LibraryModel], Error> = .success([])
    var loadCalls: [String] = []
    var loadError: Error?

    func fetchRunning() async throws -> [RunningModel] {
        try fetchResult.get()
    }

    func unload(modelName: String) async throws {
        unloadCalls.append(modelName)
        if let unloadError { throw unloadError }
    }

    func fetchLibrary() async throws -> [LibraryModel] {
        try libraryResult.get()
    }

    func load(modelName: String) async throws {
        loadCalls.append(modelName)
        if let loadError { throw loadError }
    }
}
```

- [ ] **Step 3: Build and run existing tests — must still pass**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "Test Suite|passed|failed" | tail -10
```
Expected: `Test Suite 'All tests' passed` — all 20 existing tests green.

- [ ] **Step 4: Commit**

```bash
git add OllamaDock/Networking/OllamaClient.swift \
        OllamaDockTests/ModelMonitorTests.swift
git commit -m "feat(networking): extend OllamaClienting with fetchLibrary + load"
```

---

### Task 3: OllamaClient.fetchLibrary (TDD)

**Files:**
- Modify: `OllamaDockTests/OllamaClientTests.swift`
- Modify: `OllamaDock/Networking/OllamaClient.swift`

- [ ] **Step 1: Write the two failing tests**

Add to `OllamaDockTests/OllamaClientTests.swift` (before the closing `}`):
```swift
func test_fetchLibrary_decodes_tags_response() async throws {
    MockURLProtocol.handler = { req in
        XCTAssertEqual(req.url?.path, "/api/tags")
        XCTAssertEqual(req.httpMethod, "GET")
        let data = try Data(
            contentsOf: Bundle(for: OllamaClientTests.self)
                .url(forResource: "tags_two_models", withExtension: "json")!
        )
        return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
    }
    let client = OllamaClient(session: session())
    let models = try await client.fetchLibrary()
    XCTAssertEqual(models.count, 2)
    XCTAssertEqual(models[0].name, "gemma4:e2b-mlx")
    XCTAssertEqual(models[0].sizeOnDisk, 7_069_822_916)
    XCTAssertEqual(models[1].name, "qwen3.6:27b-mlx")
}

func test_fetchLibrary_non200_throws_badStatus() async {
    MockURLProtocol.handler = { req in
        (HTTPURLResponse(url: req.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
    }
    let client = OllamaClient(session: session())
    do {
        _ = try await client.fetchLibrary()
        XCTFail("expected error")
    } catch OllamaClientError.badStatus(let code) {
        XCTAssertEqual(code, 503)
    } catch {
        XCTFail("unexpected error type: \(error)")
    }
}
```

- [ ] **Step 2: Run — verify tests fail**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "fetchLibrary|error:" | head -10
```
Expected: build error — `value of type 'OllamaClient' has no member 'fetchLibrary'`.

- [ ] **Step 3: Implement fetchLibrary in OllamaClient**

In `OllamaDock/Networking/OllamaClient.swift`, add after the closing `}` of `unload(modelName:)`:
```swift
func fetchLibrary() async throws -> [LibraryModel] {
    var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
    request.httpMethod = "GET"
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw OllamaClientError.transport("non-HTTP response")
    }
    guard (200..<300).contains(http.statusCode) else {
        throw OllamaClientError.badStatus(http.statusCode)
    }
    let tags = try decoder.decode(TagsResponse.self, from: data)
    return tags.models
}
```

- [ ] **Step 4: Run — verify new tests pass**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "fetchLibrary|passed|failed" | head -10
```
Expected: both `test_fetchLibrary_*` cases pass; all 22 tests green.

- [ ] **Step 5: Commit**

```bash
git add OllamaDock/Networking/OllamaClient.swift \
        OllamaDockTests/OllamaClientTests.swift
git commit -m "feat(networking): OllamaClient.fetchLibrary GET /api/tags"
```

---

### Task 4: OllamaClient.load (TDD)

**Files:**
- Modify: `OllamaDockTests/OllamaClientTests.swift`
- Modify: `OllamaDock/Networking/OllamaClient.swift`

- [ ] **Step 1: Write the failing test**

Add to `OllamaDockTests/OllamaClientTests.swift`:
```swift
func test_load_posts_keep_alive_300_no_prompt() async throws {
    var capturedBody: Data?
    MockURLProtocol.handler = { req in
        XCTAssertEqual(req.url?.path, "/api/generate")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
        capturedBody = req.bodyStreamData() ?? req.httpBody
        return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
    }
    let client = OllamaClient(session: session())
    try await client.load(modelName: "gemma4:e2b-mlx")

    let json = try XCTUnwrap(
        capturedBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    )
    XCTAssertEqual(json["model"] as? String, "gemma4:e2b-mlx")
    XCTAssertEqual(json["keep_alive"] as? Int, 300)
    XCTAssertNil(json["prompt"], "prompt key must be absent to avoid generating text")
}
```

- [ ] **Step 2: Run — verify test fails**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "test_load|error:" | head -5
```
Expected: build error — `value of type 'OllamaClient' has no member 'load'`.

- [ ] **Step 3: Implement load in OllamaClient**

Add after `fetchLibrary()` in `OllamaDock/Networking/OllamaClient.swift`:
```swift
func load(modelName: String) async throws {
    var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = ["model": modelName, "keep_alive": 300]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw OllamaClientError.transport("non-HTTP response")
    }
    guard (200..<300).contains(http.statusCode) else {
        throw OllamaClientError.badStatus(http.statusCode)
    }
}
```

- [ ] **Step 4: Run — verify test passes**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "test_load|passed|failed" | head -10
```
Expected: `test_load_posts_keep_alive_300_no_prompt` passes; all 23 tests green.

- [ ] **Step 5: Commit**

```bash
git add OllamaDock/Networking/OllamaClient.swift \
        OllamaDockTests/OllamaClientTests.swift
git commit -m "feat(networking): OllamaClient.load POST keep_alive=300"
```

---

### Task 5: ModelMonitor — library, refreshLibrary, availableModels (TDD)

**Files:**
- Modify: `OllamaDock/Monitor/ModelMonitor.swift`
- Modify: `OllamaDockTests/ModelMonitorTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `OllamaDockTests/ModelMonitorTests.swift`:
```swift
func test_refreshLibrary_populates_library() async {
    let client = StubClient()
    client.libraryResult = .success([
        LibraryModel(name: "gemma4:e2b-mlx", sizeOnDisk: 7_069_822_916),
        LibraryModel(name: "qwen3.6:27b-mlx", sizeOnDisk: 19_763_233_079)
    ])
    let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)

    await monitor.refreshLibrary()

    XCTAssertEqual(monitor.library.count, 2)
    XCTAssertEqual(monitor.library[0].name, "gemma4:e2b-mlx")
    XCTAssertEqual(monitor.library[0].sizeOnDisk, 7_069_822_916)
}

func test_refreshLibrary_failure_leaves_library_unchanged() async {
    let client = StubClient()
    client.libraryResult = .success([
        LibraryModel(name: "gemma4:e2b-mlx", sizeOnDisk: 1)
    ])
    let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)
    await monitor.refreshLibrary()
    XCTAssertEqual(monitor.library.count, 1)

    client.libraryResult = .failure(URLError(.cannotConnectToHost))
    await monitor.refreshLibrary()

    XCTAssertEqual(monitor.library.count, 1, "library unchanged on fetch failure")
}

func test_availableModels_excludes_loaded_names() async {
    let client = StubClient()
    client.fetchResult = .success([
        RunningModel(name: "gemma4:e2b-mlx", sizeVRAM: 1, expiresAt: Date().addingTimeInterval(60))
    ])
    client.libraryResult = .success([
        LibraryModel(name: "gemma4:e2b-mlx", sizeOnDisk: 7_069_822_916),
        LibraryModel(name: "qwen3.6:27b-mlx", sizeOnDisk: 19_763_233_079)
    ])
    let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)
    await monitor.refresh()
    await monitor.refreshLibrary()

    XCTAssertEqual(monitor.availableModels.map(\.name), ["qwen3.6:27b-mlx"])
}

func test_availableModels_is_empty_when_library_not_loaded() async {
    let client = StubClient()
    let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)
    // no refreshLibrary call
    XCTAssertTrue(monitor.availableModels.isEmpty)
}
```

- [ ] **Step 2: Run — verify tests fail**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "refreshLibrary|availableModels|error:" | head -10
```
Expected: build error — `ModelMonitor` has no member `refreshLibrary`.

- [ ] **Step 3: Add library state and refreshLibrary to ModelMonitor**

In `OllamaDock/Monitor/ModelMonitor.swift`, add two new stored properties after `private(set) var lastUnloadError: String?`:
```swift
private(set) var library: [LibraryModel] = []
```

Add a computed property after `let totalRAM: UInt64`:
```swift
var availableModels: [LibraryModel] {
    let loadedNames = Set(models.map(\.name))
    return library.filter { !loadedNames.contains($0.name) }
}
```

Add a new method after `refresh()`:
```swift
func refreshLibrary() async {
    guard let fetched = try? await client.fetchLibrary() else { return }
    library = fetched
}
```

- [ ] **Step 4: Run — verify new tests pass**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "refreshLibrary|availableModels|passed|failed" | tail -10
```
Expected: all 4 new tests pass; all 27 tests green.

- [ ] **Step 5: Commit**

```bash
git add OllamaDock/Monitor/ModelMonitor.swift \
        OllamaDockTests/ModelMonitorTests.swift
git commit -m "feat(monitor): library, availableModels, refreshLibrary"
```

---

### Task 6: ModelMonitor — load action + loadingModels (TDD)

**Files:**
- Modify: `OllamaDock/Monitor/ModelMonitor.swift`
- Modify: `OllamaDockTests/ModelMonitorTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `OllamaDockTests/ModelMonitorTests.swift`:
```swift
func test_load_calls_client_and_refreshes() async {
    let client = StubClient()
    client.fetchResult = .success([
        RunningModel(name: "gemma4:e2b-mlx", sizeVRAM: 1, expiresAt: Date().addingTimeInterval(300))
    ])
    let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)

    await monitor.load("gemma4:e2b-mlx")

    XCTAssertEqual(client.loadCalls, ["gemma4:e2b-mlx"])
    XCTAssertEqual(monitor.models.map(\.name), ["gemma4:e2b-mlx"],
                   "refresh after load should show model in loaded list")
}

func test_load_clears_loadingModels_after_completion() async {
    let client = StubClient()
    client.fetchResult = .success([])
    let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)

    await monitor.load("qwen3.6:27b-mlx")

    XCTAssertTrue(monitor.loadingModels.isEmpty,
                  "loadingModels must be empty after load completes")
}

func test_load_failure_still_clears_loadingModels() async {
    let client = StubClient()
    client.fetchResult = .success([])
    client.loadError = URLError(.timedOut)
    let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)

    await monitor.load("qwen3.6:27b-mlx")

    XCTAssertTrue(monitor.loadingModels.isEmpty,
                  "loadingModels must be empty even when load() throws")
}
```

- [ ] **Step 2: Run — verify tests fail**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "test_load_|error:" | head -10
```
Expected: build error — `ModelMonitor` has no member `load`.

- [ ] **Step 3: Add loadingModels property and load() to ModelMonitor**

Add after `private(set) var library: [LibraryModel] = []`:
```swift
private(set) var loadingModels: Set<String> = []
```

Add after `refreshLibrary()`:
```swift
func load(_ modelName: String) async {
    loadingModels.insert(modelName)
    try? await client.load(modelName: modelName)
    await refresh()
    loadingModels.remove(modelName)
}
```

- [ ] **Step 4: Run — verify new tests pass**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "test_load_|passed|failed" | tail -10
```
Expected: all 3 new tests pass; all 30 tests green.

- [ ] **Step 5: Commit**

```bash
git add OllamaDock/Monitor/ModelMonitor.swift \
        OllamaDockTests/ModelMonitorTests.swift
git commit -m "feat(monitor): load action with loadingModels spinner state"
```

---

### Task 7: Poll interval 5 s → 10 s + initial refreshLibrary on start()

**Files:**
- Modify: `OllamaDock/Monitor/ModelMonitor.swift`

- [ ] **Step 1: Change the default poll interval**

In `OllamaDock/Monitor/ModelMonitor.swift`, in the `init` signature, change:
```swift
    pollInterval: TimeInterval = 5,
```
To:
```swift
    pollInterval: TimeInterval = 10,
```

- [ ] **Step 2: Call refreshLibrary() once in start()**

In `start()`, after the two task assignments (`pollTask = Task {...}` and `tickTask = Task {...}`), add:
```swift
        Task { [weak self] in
            await self?.refreshLibrary()
        }
```

The full updated `start()` should look like:
```swift
func start() {
    guard pollTask == nil else { return }
    pollTask = Task { [weak self] in
        while !Task.isCancelled {
            guard let self else { return }
            await self.refresh()
            try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
        }
    }
    tickTask = Task { [weak self] in
        while !Task.isCancelled {
            guard let self else { return }
            self.now = Date()
            try? await Task.sleep(nanoseconds: UInt64(self.tickInterval * 1_000_000_000))
        }
    }
    Task { [weak self] in
        await self?.refreshLibrary()
    }
}
```

- [ ] **Step 3: Run all tests to confirm nothing broke**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "Test Suite 'All tests'|passed|failed"
```
Expected: `Test Suite 'All tests' passed` — 30 tests green.

- [ ] **Step 4: Commit**

```bash
git add OllamaDock/Monitor/ModelMonitor.swift
git commit -m "feat(monitor): 10s poll interval, refreshLibrary on start"
```

---

### Task 8: LibraryRow view

**Files:**
- Create: `OllamaDock/Views/LibraryRow.swift`

- [ ] **Step 1: Create LibraryRow.swift**

`OllamaDock/Views/LibraryRow.swift`:
```swift
import SwiftUI

struct LibraryRow: View {
    let model: LibraryModel
    let isLoading: Bool
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.name)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Button(action: onLoad) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Load \(model.name)")
                }
            }
            Text(MenuBarLabel.format(model.sizeOnDisk) + " on disk")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 2: Regenerate the Xcode project**

```bash
xcodegen generate
```
Expected: `Generating project OllamaDock` with no errors.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme OllamaDock -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add OllamaDock/Views/LibraryRow.swift \
        OllamaDock.xcodeproj/project.pbxproj
git commit -m "feat(ui): LibraryRow with play button and spinner state"
```

---

### Task 9: PopoverView — two sections, SectionHeader, updated Refresh button

**Files:**
- Modify: `OllamaDock/Views/PopoverView.swift`

- [ ] **Step 1: Replace the entire content of PopoverView.swift**

`OllamaDock/Views/PopoverView.swift`:
```swift
import SwiftUI

struct PopoverView: View {
    @Bindable var monitor: ModelMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            if let error = monitor.lastUnloadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            footer
        }
        .padding(12)
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            Text("Ollama")
                .font(.headline)
            Spacer()
            Text("\(monitor.models.count) loaded · \(MenuBarLabel.format(monitor.totalVRAM))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch monitor.state {
        case .loading:
            HStack { ProgressView(); Text("Checking…") }
                .frame(maxWidth: .infinity, minHeight: 80)

        case .unreachable:
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                Text("Ollama isn't running")
                    .font(.subheadline)
                Text("Start Ollama, then press Refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)

        case .connected:
            if monitor.models.isEmpty && monitor.availableModels.isEmpty {
                VStack(spacing: 4) {
                    Text("No models loaded")
                        .font(.subheadline)
                    Text("Run a model to see it here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(spacing: 6) {
                    if !monitor.models.isEmpty {
                        SectionHeader("Loaded")
                        ForEach(monitor.models) { model in
                            ModelRow(
                                model: model,
                                totalRAM: monitor.totalRAM,
                                now: monitor.now,
                                onUnload: { Task { await monitor.unload(model.name) } }
                            )
                        }
                    }
                    if !monitor.availableModels.isEmpty {
                        SectionHeader("Available")
                        ForEach(monitor.availableModels) { model in
                            LibraryRow(
                                model: model,
                                isLoading: monitor.loadingModels.contains(model.name),
                                onLoad: { Task { await monitor.load(model.name) } }
                            )
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Refresh") {
                Task {
                    await monitor.refresh()
                    await monitor.refreshLibrary()
                }
            }
            Button("Unload all") {
                Task { await monitor.unloadAll() }
            }
            .disabled(monitor.models.isEmpty)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .buttonStyle(.bordered)
    }
}

private struct SectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.secondary.opacity(0.35))
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -scheme OllamaDock -configuration Debug build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run all tests**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "Test Suite 'All tests'|passed|failed"
```
Expected: `Test Suite 'All tests' passed` — 30 tests green.

- [ ] **Step 4: Commit**

```bash
git add OllamaDock/Views/PopoverView.swift
git commit -m "feat(ui): two-section popover (Loaded / Available) with SectionHeader"
```

---

### Task 10: Final verification

**Files:** none

- [ ] **Step 1: Full clean build**

```bash
xcodebuild -scheme OllamaDock -configuration Debug clean build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Full test run with counts**

```bash
xcodebuild -scheme OllamaDock -destination 'platform=macOS' test 2>&1 \
  | grep -E "Test Suite|Test Case.*passed|failed"
```
Expected: 30 test cases, 0 failures across `ModelMonitorTests`, `OllamaClientTests`, `RunningModelTests`.

- [ ] **Step 3: Launch the app and spot-check**

```bash
pkill -x OllamaDock 2>/dev/null; sleep 0.5
open "$(xcodebuild -scheme OllamaDock -configuration Debug \
  -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/OllamaDock.app"
```

Verify in the running app:
- Menubar icon appears
- Opening the popover shows both "Loaded" and "Available" sections (if Ollama is running with `ollama list` showing models)
- Tapping ▶ on an Available model shows a spinner, then moves it to Loaded
- Tapping Refresh updates both sections

- [ ] **Step 4: Summary commit if any fixups were needed**

```bash
git add -A
git commit -m "fix: library panel final fixups"
# Only if there were fixups. Skip if Task 9 commit was clean.
```
