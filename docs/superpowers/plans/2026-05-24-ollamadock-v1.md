# OllamaDock v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menubar app that mirrors `ollama ps` in a GUI — shows currently loaded Ollama models, per-model VRAM (as share of system RAM), idle-unload countdown, and one-click unload.

**Architecture:** Single-target SwiftUI app (LSUIElement, no dock icon, macOS 14+). `MenuBarExtra(.window)` hosts a popover. A `ModelMonitor` `@Observable` runs a 5 s polling `Task` against `OllamaClient`, plus a 1 s tick for smooth countdowns. Views are thin and read from the monitor. Networking and decoding are isolated behind an `OllamaClienting` protocol so the monitor is unit-testable with a mock.

**Tech Stack:** Swift 5.9+, SwiftUI, `MenuBarExtra` API (macOS 13+), `URLSession`, XCTest. XcodeGen for reproducible `.xcodeproj` generation. MIT license. Deployment target macOS 14 (Sonoma) is required by `@Observable` / `@Bindable`.

---

## File Structure

```
OllamaDock/
  project.yml                              # XcodeGen spec (source of truth)
  OllamaDock.xcodeproj/                    # generated; committed
  OllamaDock/
    OllamaDockApp.swift                    # @main App + MenuBarExtra wiring
    Networking/
      OllamaClient.swift                   # protocol + URLSession impl
    Models/
      RunningModel.swift                   # Decodable + computed helpers
      ConnectionState.swift                # enum: .loading/.connected/.unreachable
      PSResponse.swift                     # top-level Decodable wrapper
    Monitor/
      ModelMonitor.swift                   # @Observable polling + actions
    Views/
      PopoverView.swift                    # header + list/empty/error + footer
      ModelRow.swift                       # rich row with VRAM bar + countdown + ⏏
      MenuBarLabel.swift                   # "▦ {totalVRAM}" reactive label
    Resources/
      Info.plist                           # LSUIElement=YES, LSMinimumSystemVersion=14.0
  OllamaDockTests/
    Fixtures/
      ps_running.json
      ps_empty.json
      ps_malformed.json
    MockURLProtocol.swift                  # canned HTTP responses
    OllamaClientTests.swift
    RunningModelTests.swift
    ModelMonitorTests.swift
  README.md
  LICENSE                                  # MIT
  .gitignore
```

**Boundaries:**
- `OllamaClient` knows HTTP only; no UI, no state, no timers.
- `RunningModel` is a pure value type — Decodable + derived formatting.
- `ModelMonitor` orchestrates polling, owns `[RunningModel]` and `ConnectionState`, mediates unload calls.
- Views are stateless except for SwiftUI bindings; never call `OllamaClient` directly.

---

## Task 1: Repo bootstrap

**Files:**
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `README.md`

- [ ] **Step 1: Init git in project root**

```bash
cd /Users/donkasungallage/Documents/Personal/ollamadock
git init
git add CONTEXT.md
```

- [ ] **Step 2: Write `.gitignore`**

```
# macOS
.DS_Store

# Xcode
build/
DerivedData/
*.xcuserstate
xcuserdata/
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/

# Swift Package Manager
.swiftpm/
.build/
Package.resolved

# Brainstorm/working dirs
.superpowers/
```

- [ ] **Step 3: Write MIT `LICENSE`**

```
MIT License

Copyright (c) 2026 OllamaDock contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 4: Write `README.md` skeleton**

```markdown
# OllamaDock

A native macOS menubar app that shows which Ollama models are currently loaded in GPU memory — the GUI equivalent of `ollama ps`.

## Requirements
- macOS 14 (Sonoma) or later
- Xcode 15+
- [Ollama](https://ollama.com) running locally on port 11434

## Build & run
1. Open `OllamaDock.xcodeproj` in Xcode.
2. Select the `OllamaDock` scheme.
3. Press ⌘R.

The app installs into your menu bar; it has no dock icon.

## License
MIT — see `LICENSE`.
```

- [ ] **Step 5: Commit**

```bash
git add .gitignore LICENSE README.md
git commit -m "chore: bootstrap repo (gitignore, MIT license, README skeleton)"
```

---

## Task 2: XcodeGen project spec and generation

**Files:**
- Create: `project.yml`
- Create: `OllamaDock/Resources/Info.plist`
- Create: `OllamaDock/OllamaDockApp.swift` (placeholder)
- Generate: `OllamaDock.xcodeproj/`

- [ ] **Step 1: Install XcodeGen if missing**

```bash
which xcodegen || brew install xcodegen
```

Expected: prints a path, or installs successfully.

- [ ] **Step 2: Write `project.yml`**

```yaml
name: OllamaDock
options:
  bundleIdPrefix: dev.ollamadock
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    PRODUCT_NAME: OllamaDock
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    ENABLE_HARDENED_RUNTIME: YES
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: "-"
targets:
  OllamaDock:
    type: application
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - path: OllamaDock
    info:
      path: OllamaDock/Resources/Info.plist
      properties:
        LSUIElement: true
        LSMinimumSystemVersion: "14.0"
        CFBundleDisplayName: OllamaDock
        CFBundleShortVersionString: "$(MARKETING_VERSION)"
        CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"
        NSHumanReadableCopyright: "© 2026 OllamaDock contributors"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.ollamadock.OllamaDock
        GENERATE_INFOPLIST_FILE: NO
        INFOPLIST_FILE: OllamaDock/Resources/Info.plist
  OllamaDockTests:
    type: bundle.unit-test
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - path: OllamaDockTests
    dependencies:
      - target: OllamaDock
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.ollamadock.OllamaDockTests
        GENERATE_INFOPLIST_FILE: YES
```

- [ ] **Step 3: Create minimal Info.plist**

Create `OllamaDock/Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 4: Create placeholder app entrypoint**

Create `OllamaDock/OllamaDockApp.swift`:

```swift
import SwiftUI

@main
struct OllamaDockApp: App {
    var body: some Scene {
        MenuBarExtra("OllamaDock", systemImage: "cpu") {
            Text("Hello, OllamaDock")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 5: Generate the Xcode project**

```bash
cd /Users/donkasungallage/Documents/Personal/ollamadock
xcodegen generate
```

Expected: `OllamaDock.xcodeproj` directory created; no errors.

- [ ] **Step 6: Build to verify the scaffold compiles**

```bash
xcodebuild -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' build | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add project.yml OllamaDock OllamaDock.xcodeproj
git commit -m "chore: scaffold Xcode project via XcodeGen (LSUIElement menubar app)"
```

---

## Task 3: `RunningModel` value type + tests

**Files:**
- Create: `OllamaDock/Models/PSResponse.swift`
- Create: `OllamaDock/Models/RunningModel.swift`
- Create: `OllamaDockTests/RunningModelTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OllamaDockTests/RunningModelTests.swift`:

```swift
import XCTest
@testable import OllamaDock

final class RunningModelTests: XCTestCase {
    func test_decodes_api_ps_payload() throws {
        let json = """
        {
          "models": [{
            "name": "qwen3.6:27b-mlx",
            "model": "qwen3.6:27b-mlx",
            "size": 19000000000,
            "digest": "60b0437bbd02",
            "expires_at": "2026-05-24T11:20:00Z",
            "size_vram": 19000000000
          }]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(PSResponse.self, from: json)

        XCTAssertEqual(response.models.count, 1)
        XCTAssertEqual(response.models[0].name, "qwen3.6:27b-mlx")
        XCTAssertEqual(response.models[0].sizeVRAM, 19_000_000_000)
    }

    func test_vramFraction_uses_provided_totalRAM() {
        let model = RunningModel(
            name: "x",
            sizeVRAM: 8_000_000_000,
            expiresAt: Date()
        )
        let fraction = model.vramFraction(ofTotalRAM: 32_000_000_000)
        XCTAssertEqual(fraction, 0.25, accuracy: 0.0001)
    }

    func test_vramFraction_clamps_to_one() {
        let model = RunningModel(name: "x", sizeVRAM: 100, expiresAt: Date())
        XCTAssertEqual(model.vramFraction(ofTotalRAM: 50), 1.0)
    }

    func test_vramFraction_zero_totalRAM_returns_zero() {
        let model = RunningModel(name: "x", sizeVRAM: 100, expiresAt: Date())
        XCTAssertEqual(model.vramFraction(ofTotalRAM: 0), 0.0)
    }

    func test_countdown_in_future_formats_minutes_seconds() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let model = RunningModel(
            name: "x",
            sizeVRAM: 1,
            expiresAt: now.addingTimeInterval(125)
        )
        XCTAssertEqual(model.countdownString(now: now), "2m 5s")
    }

    func test_countdown_under_minute_formats_seconds_only() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let model = RunningModel(
            name: "x",
            sizeVRAM: 1,
            expiresAt: now.addingTimeInterval(42)
        )
        XCTAssertEqual(model.countdownString(now: now), "42s")
    }

    func test_countdown_past_returns_unloading() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let model = RunningModel(
            name: "x",
            sizeVRAM: 1,
            expiresAt: now.addingTimeInterval(-10)
        )
        XCTAssertEqual(model.countdownString(now: now), "unloading…")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' -only-testing:OllamaDockTests/RunningModelTests 2>&1 | tail -30
```

Expected: build failure — `RunningModel` and `PSResponse` undefined.

- [ ] **Step 3: Implement `RunningModel`**

Create `OllamaDock/Models/RunningModel.swift`:

```swift
import Foundation

struct RunningModel: Equatable, Identifiable {
    let name: String
    let sizeVRAM: UInt64
    let expiresAt: Date

    var id: String { name }

    func vramFraction(ofTotalRAM totalRAM: UInt64) -> Double {
        guard totalRAM > 0 else { return 0 }
        let raw = Double(sizeVRAM) / Double(totalRAM)
        return min(max(raw, 0), 1)
    }

    func countdownString(now: Date) -> String {
        let remaining = expiresAt.timeIntervalSince(now)
        if remaining <= 0 { return "unloading…" }
        let total = Int(remaining.rounded(.down))
        let minutes = total / 60
        let seconds = total % 60
        return minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
    }
}

extension RunningModel: Decodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case sizeVRAM = "size_vram"
        case expiresAt = "expires_at"
    }
}
```

- [ ] **Step 4: Implement `PSResponse`**

Create `OllamaDock/Models/PSResponse.swift`:

```swift
import Foundation

struct PSResponse: Decodable {
    let models: [RunningModel]
}
```

- [ ] **Step 5: Regenerate project so new files are picked up**

```bash
xcodegen generate
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild test -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' -only-testing:OllamaDockTests/RunningModelTests 2>&1 | tail -20
```

Expected: `Test Suite 'RunningModelTests' passed`.

- [ ] **Step 7: Commit**

```bash
git add OllamaDock/Models OllamaDockTests/RunningModelTests.swift OllamaDock.xcodeproj
git commit -m "feat(models): add RunningModel/PSResponse with VRAM fraction and countdown"
```

---

## Task 4: `OllamaClient` fetch + tests with `MockURLProtocol`

**Files:**
- Create: `OllamaDock/Networking/OllamaClient.swift`
- Create: `OllamaDockTests/MockURLProtocol.swift`
- Create: `OllamaDockTests/Fixtures/ps_running.json`
- Create: `OllamaDockTests/Fixtures/ps_empty.json`
- Create: `OllamaDockTests/Fixtures/ps_malformed.json`
- Create: `OllamaDockTests/OllamaClientTests.swift`

- [ ] **Step 1: Write fixtures**

Create `OllamaDockTests/Fixtures/ps_running.json`:

```json
{
  "models": [
    {
      "name": "qwen3.6:27b-mlx",
      "model": "qwen3.6:27b-mlx",
      "size": 19000000000,
      "digest": "60b0437bbd02",
      "expires_at": "2026-05-24T11:20:00Z",
      "size_vram": 19000000000
    },
    {
      "name": "llama3:8b",
      "model": "llama3:8b",
      "size": 4700000000,
      "digest": "abc",
      "expires_at": "2026-05-24T11:25:00Z",
      "size_vram": 4700000000
    }
  ]
}
```

Create `OllamaDockTests/Fixtures/ps_empty.json`:

```json
{ "models": [] }
```

Create `OllamaDockTests/Fixtures/ps_malformed.json`:

```json
{ "oops": true }
```

- [ ] **Step 2: Write `MockURLProtocol`**

Create `OllamaDockTests/MockURLProtocol.swift`:

```swift
import Foundation

final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)
    static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

- [ ] **Step 3: Write failing client tests**

Create `OllamaDockTests/OllamaClientTests.swift`:

```swift
import XCTest
@testable import OllamaDock

final class OllamaClientTests: XCTestCase {
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: "json")!
        return try Data(contentsOf: url)
    }

    private func ok(_ data: Data, url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    func test_fetchRunning_decodes_running_models() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/ps")
            XCTAssertEqual(req.httpMethod, "GET")
            let data = try Data(
                contentsOf: Bundle(for: OllamaClientTests.self)
                    .url(forResource: "ps_running", withExtension: "json")!
            )
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OllamaClient(session: session())
        let models = try await client.fetchRunning()
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].name, "qwen3.6:27b-mlx")
        XCTAssertEqual(models[0].sizeVRAM, 19_000_000_000)
    }

    func test_fetchRunning_empty_models_returns_empty_array() async throws {
        MockURLProtocol.handler = { req in
            let data = try Data(
                contentsOf: Bundle(for: OllamaClientTests.self)
                    .url(forResource: "ps_empty", withExtension: "json")!
            )
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OllamaClient(session: session())
        let models = try await client.fetchRunning()
        XCTAssertTrue(models.isEmpty)
    }

    func test_fetchRunning_malformed_throws() async {
        MockURLProtocol.handler = { req in
            let data = try Data(
                contentsOf: Bundle(for: OllamaClientTests.self)
                    .url(forResource: "ps_malformed", withExtension: "json")!
            )
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OllamaClient(session: session())
        do {
            _ = try await client.fetchRunning()
            XCTFail("expected decoding error")
        } catch {
            // expected
        }
    }

    func test_fetchRunning_non200_throws_unreachable() async {
        MockURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = OllamaClient(session: session())
        do {
            _ = try await client.fetchRunning()
            XCTFail("expected error")
        } catch OllamaClientError.badStatus(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}
```

- [ ] **Step 4: Add fixtures to test target resources**

Edit `project.yml` — in the `OllamaDockTests` target, replace the `sources` block so fixtures get bundled:

```yaml
  OllamaDockTests:
    type: bundle.unit-test
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - path: OllamaDockTests
        excludes:
          - "Fixtures/**"
      # List fixtures individually so they land at the test bundle root.
      # `type: folder` preserves the Fixtures/ hierarchy, which breaks the
      # non-recursive Bundle(for:).url(forResource:withExtension:) lookups.
      - path: OllamaDockTests/Fixtures/ps_running.json
        buildPhase: resources
      - path: OllamaDockTests/Fixtures/ps_empty.json
        buildPhase: resources
      - path: OllamaDockTests/Fixtures/ps_malformed.json
        buildPhase: resources
    dependencies:
      - target: OllamaDock
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.ollamadock.OllamaDockTests
        GENERATE_INFOPLIST_FILE: YES
```

Then regenerate:

```bash
xcodegen generate
```

- [ ] **Step 5: Run tests to verify they fail**

```bash
xcodebuild test -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' -only-testing:OllamaDockTests/OllamaClientTests 2>&1 | tail -30
```

Expected: build failure — `OllamaClient`, `OllamaClientError` undefined.

- [ ] **Step 6: Implement `OllamaClient`**

Create `OllamaDock/Networking/OllamaClient.swift`:

```swift
import Foundation

enum OllamaClientError: Error, Equatable {
    case badStatus(Int)
    case transport(String)
}

protocol OllamaClienting: Sendable {
    func fetchRunning() async throws -> [RunningModel]
    func unload(modelName: String) async throws
}

final class OllamaClient: OllamaClienting {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func fetchRunning() async throws -> [RunningModel] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/ps"))
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OllamaClientError.transport("non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OllamaClientError.badStatus(http.statusCode)
        }
        let ps = try decoder.decode(PSResponse.self, from: data)
        return ps.models
    }

    func unload(modelName: String) async throws {
        // Implemented in Task 5.
        fatalError("unload not yet implemented")
    }
}
```

- [ ] **Step 7: Regenerate project, run tests, verify pass**

```bash
xcodegen generate
xcodebuild test -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' -only-testing:OllamaDockTests/OllamaClientTests 2>&1 | tail -20
```

Expected: 4 tests passed.

- [ ] **Step 8: Commit**

```bash
git add OllamaDock/Networking OllamaDockTests project.yml OllamaDock.xcodeproj
git commit -m "feat(networking): OllamaClient.fetchRunning + URLProtocol mock tests"
```

---

## Task 5: `OllamaClient.unload` + test

**Files:**
- Modify: `OllamaDock/Networking/OllamaClient.swift`
- Modify: `OllamaDockTests/OllamaClientTests.swift`

- [ ] **Step 1: Add failing unload test**

Append to `OllamaDockTests/OllamaClientTests.swift` inside the class:

```swift
    func test_unload_posts_keep_alive_zero() async throws {
        var capturedBody: Data?
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/generate")
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
            capturedBody = req.bodyStreamData() ?? req.httpBody
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = OllamaClient(session: session())
        try await client.unload(modelName: "qwen3.6:27b-mlx")

        let json = try XCTUnwrap(capturedBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        XCTAssertEqual(json["model"] as? String, "qwen3.6:27b-mlx")
        XCTAssertEqual(json["keep_alive"] as? Int, 0)
    }
```

And add this helper extension at the bottom of the same file (outside the class):

```swift
private extension URLRequest {
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' -only-testing:OllamaDockTests/OllamaClientTests/test_unload_posts_keep_alive_zero 2>&1 | tail -20
```

Expected: fatal error / failure — `unload` is not implemented.

- [ ] **Step 3: Implement `unload`**

In `OllamaDock/Networking/OllamaClient.swift`, replace the `unload` method:

```swift
    func unload(modelName: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": modelName, "keep_alive": 0]
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

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' -only-testing:OllamaDockTests/OllamaClientTests 2>&1 | tail -20
```

Expected: all 5 OllamaClientTests pass.

- [ ] **Step 5: Commit**

```bash
git add OllamaDock/Networking/OllamaClient.swift OllamaDockTests/OllamaClientTests.swift
git commit -m "feat(networking): OllamaClient.unload posts keep_alive=0"
```

---

## Task 6: `ModelMonitor` polling + tests

**Files:**
- Create: `OllamaDock/Models/ConnectionState.swift`
- Create: `OllamaDock/Monitor/ModelMonitor.swift`
- Create: `OllamaDockTests/ModelMonitorTests.swift`

- [ ] **Step 1: Write `ConnectionState`**

Create `OllamaDock/Models/ConnectionState.swift`:

```swift
import Foundation

enum ConnectionState: Equatable {
    case loading
    case connected
    case unreachable
}
```

- [ ] **Step 2: Write failing monitor tests**

Create `OllamaDockTests/ModelMonitorTests.swift`:

```swift
import XCTest
@testable import OllamaDock

@MainActor
final class ModelMonitorTests: XCTestCase {
    final class StubClient: OllamaClienting, @unchecked Sendable {
        var fetchResult: Result<[RunningModel], Error> = .success([])
        var unloadCalls: [String] = []
        var unloadError: Error?

        func fetchRunning() async throws -> [RunningModel] {
            try fetchResult.get()
        }

        func unload(modelName: String) async throws {
            unloadCalls.append(modelName)
            if let unloadError { throw unloadError }
        }
    }

    func test_refresh_sets_connected_with_models() async {
        let client = StubClient()
        client.fetchResult = .success([
            RunningModel(name: "a", sizeVRAM: 1, expiresAt: Date().addingTimeInterval(60))
        ])
        let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)

        await monitor.refresh()

        XCTAssertEqual(monitor.state, .connected)
        XCTAssertEqual(monitor.models.map(\.name), ["a"])
        XCTAssertEqual(monitor.totalVRAM, 1)
    }

    func test_refresh_sets_unreachable_on_throw() async {
        let client = StubClient()
        client.fetchResult = .failure(URLError(.cannotConnectToHost))
        let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)

        await monitor.refresh()

        XCTAssertEqual(monitor.state, .unreachable)
        XCTAssertTrue(monitor.models.isEmpty)
    }

    func test_unload_calls_client_then_refreshes() async {
        let client = StubClient()
        client.fetchResult = .success([])
        let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)

        await monitor.unload("qwen3.6:27b-mlx")

        XCTAssertEqual(client.unloadCalls, ["qwen3.6:27b-mlx"])
        XCTAssertEqual(monitor.state, .connected)
    }

    func test_unloadAll_calls_unload_for_each_model() async {
        let client = StubClient()
        let models = [
            RunningModel(name: "a", sizeVRAM: 1, expiresAt: Date()),
            RunningModel(name: "b", sizeVRAM: 1, expiresAt: Date())
        ]
        client.fetchResult = .success(models)
        let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)
        await monitor.refresh()

        await monitor.unloadAll()

        XCTAssertEqual(Set(client.unloadCalls), ["a", "b"])
    }

    func test_totalVRAM_sums_all_models() async {
        let client = StubClient()
        client.fetchResult = .success([
            RunningModel(name: "a", sizeVRAM: 3, expiresAt: Date()),
            RunningModel(name: "b", sizeVRAM: 4, expiresAt: Date())
        ])
        let monitor = ModelMonitor(client: client, totalRAM: 16_000_000_000)

        await monitor.refresh()

        XCTAssertEqual(monitor.totalVRAM, 7)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild test -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' -only-testing:OllamaDockTests/ModelMonitorTests 2>&1 | tail -30
```

Expected: build failure — `ModelMonitor` undefined.

- [ ] **Step 4: Implement `ModelMonitor`**

Create `OllamaDock/Monitor/ModelMonitor.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class ModelMonitor {
    private(set) var models: [RunningModel] = []
    private(set) var state: ConnectionState = .loading
    private(set) var totalVRAM: UInt64 = 0
    private(set) var now: Date = Date()

    let totalRAM: UInt64

    private let client: OllamaClienting
    private let pollInterval: TimeInterval
    private let tickInterval: TimeInterval
    private var pollTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?

    init(
        client: OllamaClienting,
        totalRAM: UInt64 = ProcessInfo.processInfo.physicalMemory,
        pollInterval: TimeInterval = 5,
        tickInterval: TimeInterval = 1
    ) {
        self.client = client
        self.totalRAM = totalRAM
        self.pollInterval = pollInterval
        self.tickInterval = tickInterval
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: UInt64((self?.pollInterval ?? 5) * 1_000_000_000))
            }
        }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run { self?.now = Date() }
                try? await Task.sleep(nanoseconds: UInt64((self?.tickInterval ?? 1) * 1_000_000_000))
            }
        }
    }

    func stop() {
        pollTask?.cancel(); pollTask = nil
        tickTask?.cancel(); tickTask = nil
    }

    func refresh() async {
        do {
            let fetched = try await client.fetchRunning()
            models = fetched
            totalVRAM = fetched.reduce(0) { $0 + $1.sizeVRAM }
            state = .connected
        } catch {
            models = []
            totalVRAM = 0
            state = .unreachable
        }
    }

    func unload(_ modelName: String) async {
        try? await client.unload(modelName: modelName)
        await refresh()
    }

    func unloadAll() async {
        let names = models.map(\.name)
        for name in names {
            try? await client.unload(modelName: name)
        }
        await refresh()
    }
}
```

- [ ] **Step 5: Regenerate project, run tests, verify pass**

```bash
xcodegen generate
xcodebuild test -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' -only-testing:OllamaDockTests/ModelMonitorTests 2>&1 | tail -20
```

Expected: 5 ModelMonitorTests pass.

- [ ] **Step 6: Commit**

```bash
git add OllamaDock/Models/ConnectionState.swift OllamaDock/Monitor OllamaDockTests/ModelMonitorTests.swift OllamaDock.xcodeproj
git commit -m "feat(monitor): @Observable ModelMonitor with 5s poll + 1s tick"
```

---

## Task 7: Popover views (`ModelRow`, `PopoverView`, `MenuBarLabel`)

**Files:**
- Create: `OllamaDock/Views/ModelRow.swift`
- Create: `OllamaDock/Views/PopoverView.swift`
- Create: `OllamaDock/Views/MenuBarLabel.swift`

- [ ] **Step 1: Implement `MenuBarLabel`**

Create `OllamaDock/Views/MenuBarLabel.swift`:

```swift
import SwiftUI

struct MenuBarLabel: View {
    let totalVRAM: UInt64

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Text(Self.format(totalVRAM))
                .monospacedDigit()
        }
    }

    static func format(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
```

- [ ] **Step 2: Implement `ModelRow`**

Create `OllamaDock/Views/ModelRow.swift`:

```swift
import SwiftUI

struct ModelRow: View {
    let model: RunningModel
    let totalRAM: UInt64
    let now: Date
    let onUnload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.name)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(action: onUnload) {
                    Image(systemName: "eject.fill")
                }
                .buttonStyle(.borderless)
                .help("Unload \(model.name)")
            }

            ProgressView(value: model.vramFraction(ofTotalRAM: totalRAM))
                .progressViewStyle(.linear)

            HStack {
                Text(MenuBarLabel.format(model.sizeVRAM))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(model.countdownString(now: now))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 3: Implement `PopoverView`**

Create `OllamaDock/Views/PopoverView.swift`:

```swift
import SwiftUI

struct PopoverView: View {
    @Bindable var monitor: ModelMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
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
        case .connected where monitor.models.isEmpty:
            VStack(spacing: 4) {
                Text("No models loaded")
                    .font(.subheadline)
                Text("Run a model to see it here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        case .connected:
            VStack(spacing: 6) {
                ForEach(monitor.models) { model in
                    ModelRow(
                        model: model,
                        totalRAM: monitor.totalRAM,
                        now: monitor.now,
                        onUnload: { Task { await monitor.unload(model.name) } }
                    )
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Refresh") {
                Task { await monitor.refresh() }
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
```

- [ ] **Step 4: Regenerate and build**

```bash
xcodegen generate
xcodebuild -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add OllamaDock/Views OllamaDock.xcodeproj
git commit -m "feat(ui): PopoverView, ModelRow, MenuBarLabel with all four states"
```

---

## Task 8: Wire `MenuBarExtra` to `ModelMonitor`

**Files:**
- Modify: `OllamaDock/OllamaDockApp.swift`

- [ ] **Step 1: Replace `OllamaDockApp.swift` with real wiring**

```swift
import SwiftUI

@main
struct OllamaDockApp: App {
    @State private var monitor = ModelMonitor(client: OllamaClient())

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
                .onAppear { monitor.start() }
        } label: {
            MenuBarLabel(totalVRAM: monitor.totalVRAM)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: Build and run**

```bash
xcodebuild -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual verification**

Launch the built `.app` (open in Xcode, ⌘R). With Ollama running, verify:
- Menu bar shows `▦ 0 GB` initially, then updates after `ollama run llama3:8b` triggers a load.
- Clicking the menubar item opens the popover.
- Loaded model appears with VRAM bar and countdown ticking each second.
- Unload (⏏) removes the model within ~5 s; "Unload all" empties the list.
- Stopping the Ollama service flips the popover to "Ollama isn't running".

Document any deviations in the commit message; do not claim success unless each bullet was observed.

- [ ] **Step 4: Commit**

```bash
git add OllamaDock/OllamaDockApp.swift
git commit -m "feat(app): wire MenuBarExtra to ModelMonitor with reactive label"
```

---

## Task 9: README polish

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace README with full version**

```markdown
# OllamaDock

A native macOS menubar app that shows which Ollama models are currently loaded in GPU memory — the GUI equivalent of `ollama ps`.

## Features
- Always-visible menubar label: `▦ {total VRAM}` (e.g. `▦ 19 GB`, `▦ 0 GB` when idle).
- Popover lists each loaded model with:
  - Name
  - VRAM bar (share of system RAM)
  - Idle-unload countdown (updated every second)
  - One-click unload (⏏)
- Footer actions: Refresh, Unload all, Quit.
- Auto-refresh every 5 seconds.
- No dock icon (LSUIElement).

## Requirements
- macOS 14 (Sonoma) or later
- Xcode 15 or later
- [Ollama](https://ollama.com) running locally on `http://localhost:11434`

## Build & run
```bash
git clone https://github.com/<you>/OllamaDock.git
cd OllamaDock
open OllamaDock.xcodeproj
```
Select the `OllamaDock` scheme and press ⌘R.

## Regenerating the Xcode project
The `.xcodeproj` is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen). Only required if you add or remove files:
```bash
brew install xcodegen
xcodegen generate
```

## Tests
```bash
xcodebuild test -project OllamaDock.xcodeproj -scheme OllamaDock -destination 'platform=macOS'
```

## Not in v1
- Settings UI
- Configurable host / port / poll interval
- Launch at login
- Notarized DMG release

## License
MIT — see `LICENSE`.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: flesh out README with features, build, test, scope"
```

---

## Self-review

**Spec coverage check (against the brainstorm decisions):**
- Menubar label `▦ {VRAM}` always visible, incl. `▦ 0 GB` when idle → Task 7 (`MenuBarLabel`) + Task 8 wiring.
- Rich popover rows with VRAM bar + countdown + ⏏ → Task 7 (`ModelRow`).
- VRAM bar as share of system RAM → Task 3 (`vramFraction(ofTotalRAM:)`) + Task 6 (`totalRAM` from `ProcessInfo`).
- Footer: Refresh / Unload all / Quit → Task 7 (`PopoverView.footer`).
- 5 s polling + 1 s countdown tick → Task 6 (`ModelMonitor.start`).
- Four states (loading / connected+models / connected+empty / unreachable) → Task 7 (`PopoverView.content` switch) + Task 6 (`ConnectionState`).
- Past-`expiresAt` shows "unloading…" → Task 3 test + impl.
- Architecture: App / Client / Model / Monitor / Views → Tasks 2–8.
- Hardcoded `localhost:11434` and 5 s interval, no settings → Task 4 (`OllamaClient` default `baseURL`) + Task 6 defaults.
- Approach 1 (Xcode + `MenuBarExtra(.window)`, LSUIElement) → Tasks 2 + 8.
- MIT license, open-source-friendly repo layout → Task 1.
- Unit tests for client, model, monitor with mock URLProtocol + protocol-based stub → Tasks 3–6.
- Explicit manual verification for the GUI → Task 8 Step 3.

No spec items unaccounted for. No placeholders (`TBD`, vague "add validation", etc.) in the steps. Type/name consistency verified: `OllamaClienting`, `RunningModel`, `ModelMonitor`, `ConnectionState`, `MenuBarLabel.format`, `vramFraction(ofTotalRAM:)`, `countdownString(now:)` are referenced identically wherever they appear.

---

Plan complete and saved to `docs/superpowers/plans/2026-05-24-ollamadock-v1.md`.
