# Daemon Status & Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add stacked two-dot daemon/model status to the menu bar label and let users start or gracefully quit the Ollama daemon from the popover.

**Architecture:** A new `DaemonControlling` protocol (mirroring `OllamaClienting`) wraps `open -a Ollama` and `osascript quit` behind an injectable interface so `ModelMonitor` can delegate without coupling to `Process`. Two computed properties (`daemonUp`, `modelRunning`) on `ModelMonitor` derive from existing state. `MenuBarLabel` is extended to accept those booleans and render stacked `Circle` dots. `PopoverView` gains a "Start Ollama" button in the unreachable state and a confirmed "Quit Ollama" action in the footer.

**Tech Stack:** Swift 5.9, SwiftUI, Foundation (`Process`, `URL`), XCTest, XcodeGen (run `xcodegen generate` after adding new source files)

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `OllamaDock/DaemonControl/DaemonControlling.swift` | Protocol + `DaemonControlError` enum |
| Create | `OllamaDock/DaemonControl/DaemonController.swift` | Production `Process`-based implementation |
| Modify | `OllamaDock/Monitor/ModelMonitor.swift` | Add daemon controller dependency, `daemonUp`/`modelRunning` props, `startDaemon`/`quitDaemon` methods, `lastDaemonError`/`daemonNotInstalled` state |
| Modify | `OllamaDock/Views/MenuBarLabel.swift` | Replace single glyph+text with two status dots + conditional VRAM text |
| Modify | `OllamaDock/OllamaDockApp.swift` | Inject `DaemonController`, pass `daemonUp`/`modelRunning` to label |
| Modify | `OllamaDock/Views/PopoverView.swift` | Start Ollama button in `.unreachable`, Quit Ollama in footer, daemon error display |
| Create | `OllamaDockTests/ModelMonitorDaemonTests.swift` | All new unit tests |

---

### Task 1: DaemonControlling protocol and DaemonControlError

**Files:**
- Create: `OllamaDock/DaemonControl/DaemonControlling.swift`

- [ ] **Step 1: Create the file**

```swift
// OllamaDock/DaemonControl/DaemonControlling.swift
import Foundation

enum DaemonControlError: Error, Equatable {
    /// `open -a Ollama` exited non-zero — the app is not installed.
    case appNotFound
    /// A command exited with an unexpected non-zero status.
    case commandFailed(Int32)
}

protocol DaemonControlling: Sendable {
    /// Launches the Ollama.app via `open -a Ollama`.
    /// Throws `DaemonControlError.appNotFound` when the app isn't installed.
    func start() async throws

    /// Asks the Ollama.app to quit via `osascript`.
    /// Throws `DaemonControlError.commandFailed` on non-zero exit.
    func quit() async throws
}
```

- [ ] **Step 2: Regenerate the Xcode project**

New directory `OllamaDock/DaemonControl/` was added. XcodeGen must rescan sources:

```bash
xcodegen generate
```

Expected: `OllamaDock.xcodeproj` recreated. No errors.

- [ ] **Step 3: Build to confirm the file compiles**

```bash
xcodebuild build \
  -project OllamaDock.xcodeproj \
  -scheme OllamaDock \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add OllamaDock/DaemonControl/DaemonControlling.swift OllamaDock.xcodeproj
git commit -m "feat: add DaemonControlling protocol and DaemonControlError"
```

---

### Task 2: DaemonController production implementation

**Files:**
- Create: `OllamaDock/DaemonControl/DaemonController.swift`

- [ ] **Step 1: Write the implementation**

```swift
// OllamaDock/DaemonControl/DaemonController.swift
import Foundation

/// Runs daemon control commands via Foundation's `Process`.
/// The real Process calls are not unit-tested (they need live binaries).
/// Tests inject a `StubDaemonController` conforming to `DaemonControlling` instead.
final class DaemonController: DaemonControlling {

    func start() async throws {
        let code = try await run("/usr/bin/open", args: ["-a", "Ollama"])
        guard code == 0 else {
            // `open -a <app>` exits 1 when the app is not found.
            throw DaemonControlError.appNotFound
        }
    }

    func quit() async throws {
        let code = try await run(
            "/usr/bin/osascript",
            args: ["-e", #"quit app "Ollama""#]
        )
        guard code == 0 else {
            throw DaemonControlError.commandFailed(code)
        }
    }

    // Runs a command and returns its termination status.
    // Runs off-thread so it doesn't block the main actor.
    private func run(_ executable: String, args: [String]) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: executable)
            proc.arguments = args
            proc.terminationHandler = { p in
                continuation.resume(returning: p.terminationStatus)
            }
            do {
                try proc.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
xcodebuild build \
  -project OllamaDock.xcodeproj \
  -scheme OllamaDock \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add OllamaDock/DaemonControl/DaemonController.swift
git commit -m "feat: add DaemonController (Process-based open/osascript)"
```

---

### Task 3: ModelMonitor — daemon state and control methods

**Files:**
- Modify: `OllamaDock/Monitor/ModelMonitor.swift`
- Create: `OllamaDockTests/ModelMonitorDaemonTests.swift`

- [ ] **Step 1: Write the failing tests first**

Create `OllamaDockTests/ModelMonitorDaemonTests.swift`:

```swift
// OllamaDockTests/ModelMonitorDaemonTests.swift
import XCTest
@testable import OllamaDock

@MainActor
final class ModelMonitorDaemonTests: XCTestCase {

    // MARK: - Stub

    final class StubDaemonController: DaemonControlling, @unchecked Sendable {
        var startCalls = 0
        var quitCalls = 0
        var startError: Error?
        var quitError: Error?

        func start() async throws {
            startCalls += 1
            if let e = startError { throw e }
        }

        func quit() async throws {
            quitCalls += 1
            if let e = quitError { throw e }
        }
    }

    final class StubClient: OllamaClienting, @unchecked Sendable {
        var fetchResult: Result<[RunningModel], Error> = .success([])
        var fetchCount = 0
        func fetchRunning() async throws -> [RunningModel] { fetchCount += 1; return try fetchResult.get() }
        func unload(modelName: String) async throws {}
        func fetchLibrary() async throws -> [LibraryModel] { [] }
        func load(modelName: String) async throws {}
    }

    // MARK: - daemonUp computed property

    func test_daemonUp_connected() async {
        let client = StubClient()
        client.fetchResult = .success([])
        let monitor = ModelMonitor(client: client, daemonController: StubDaemonController())
        await monitor.refresh()             // drives state → .connected
        XCTAssertTrue(monitor.daemonUp)
    }

    func test_daemonUp_unreachable() async {
        let client = StubClient()
        client.fetchResult = .failure(URLError(.cannotConnectToHost))
        let monitor = ModelMonitor(client: client, daemonController: StubDaemonController())
        await monitor.refresh()             // drives state → .unreachable
        XCTAssertFalse(monitor.daemonUp)
    }

    func test_daemonUp_protocolError() async {
        let client = StubClient()
        client.fetchResult = .failure(OllamaClientError.badStatus(503))
        let monitor = ModelMonitor(client: client, daemonController: StubDaemonController())
        await monitor.refresh()             // drives state → .protocolError
        XCTAssertTrue(monitor.daemonUp)
    }

    // MARK: - modelRunning computed property

    func test_modelRunning_withModels() async {
        let client = StubClient()
        client.fetchResult = .success([
            RunningModel(name: "llama3", sizeVRAM: 100, expiresAt: Date().addingTimeInterval(60))
        ])
        let monitor = ModelMonitor(client: client, daemonController: StubDaemonController())
        await monitor.refresh()
        XCTAssertTrue(monitor.modelRunning)
    }

    func test_modelRunning_noModels() async {
        let client = StubClient()
        client.fetchResult = .success([])
        let monitor = ModelMonitor(client: client, daemonController: StubDaemonController())
        await monitor.refresh()
        XCTAssertFalse(monitor.modelRunning)
    }

    // MARK: - startDaemon

    func test_startDaemon_success_callsControllerAndRefreshes() async {
        let client = StubClient()
        let daemon = StubDaemonController()
        let monitor = ModelMonitor(client: client, daemonController: daemon)

        await monitor.startDaemon()

        XCTAssertEqual(daemon.startCalls, 1)
        XCTAssertEqual(client.fetchCount, 1)   // refresh triggered
        XCTAssertNil(monitor.lastDaemonError)
        XCTAssertFalse(monitor.daemonNotInstalled)
    }

    func test_startDaemon_appNotFound_setsDaemonNotInstalled() async {
        let client = StubClient()
        let daemon = StubDaemonController()
        daemon.startError = DaemonControlError.appNotFound
        let monitor = ModelMonitor(client: client, daemonController: daemon)

        await monitor.startDaemon()

        XCTAssertTrue(monitor.daemonNotInstalled)
        XCTAssertNil(monitor.lastDaemonError)  // install guide, not an error message
        XCTAssertEqual(client.fetchCount, 1)   // refresh still runs
    }

    func test_startDaemon_otherError_setsLastDaemonError() async {
        let client = StubClient()
        let daemon = StubDaemonController()
        daemon.startError = DaemonControlError.commandFailed(2)
        let monitor = ModelMonitor(client: client, daemonController: daemon)

        await monitor.startDaemon()

        XCTAssertFalse(monitor.daemonNotInstalled)
        XCTAssertNotNil(monitor.lastDaemonError)
    }

    // MARK: - quitDaemon

    func test_quitDaemon_success_callsControllerAndRefreshes() async {
        let client = StubClient()
        let daemon = StubDaemonController()
        let monitor = ModelMonitor(client: client, daemonController: daemon)

        await monitor.quitDaemon()

        XCTAssertEqual(daemon.quitCalls, 1)
        XCTAssertEqual(client.fetchCount, 1)
        XCTAssertNil(monitor.lastDaemonError)
    }

    func test_quitDaemon_failure_setsLastDaemonError() async {
        let client = StubClient()
        let daemon = StubDaemonController()
        daemon.quitError = DaemonControlError.commandFailed(1)
        let monitor = ModelMonitor(client: client, daemonController: daemon)

        await monitor.quitDaemon()

        XCTAssertNotNil(monitor.lastDaemonError)
    }

    // MARK: - clearActionErrors

    func test_clearActionErrors_clearsDaemonFields() async {
        let client = StubClient()
        let daemon = StubDaemonController()
        daemon.startError = DaemonControlError.commandFailed(2)
        let monitor = ModelMonitor(client: client, daemonController: daemon)
        await monitor.startDaemon()          // sets lastDaemonError

        monitor.clearActionErrors()

        XCTAssertNil(monitor.lastDaemonError)
        XCTAssertFalse(monitor.daemonNotInstalled)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure (types not yet defined)**

```bash
xcodebuild test \
  -project OllamaDock.xcodeproj \
  -scheme OllamaDock \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|Build FAILED"
```

Expected: compiler errors referencing `daemonController`, `daemonUp`, `modelRunning`, `startDaemon`, `quitDaemon`, `lastDaemonError`, `daemonNotInstalled`.

- [ ] **Step 3: Update ModelMonitor to make tests pass**

Replace the full content of `OllamaDock/Monitor/ModelMonitor.swift`:

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
    private(set) var lastUnloadError: String?
    private(set) var lastLoadError: String?
    private(set) var lastDaemonError: String?
    private(set) var daemonNotInstalled: Bool = false
    private(set) var library: [LibraryModel] = []
    private(set) var loadingModels: Set<String> = []

    /// True when the daemon is reachable (connected or answered with a protocol error).
    var daemonUp: Bool {
        switch state {
        case .connected, .protocolError: return true
        case .unreachable, .loading: return false
        }
    }

    /// True when at least one model is loaded in VRAM.
    var modelRunning: Bool { !models.isEmpty }

    var availableModels: [LibraryModel] {
        let loadedNames = Set(models.map(\.name))
        return library.filter { !loadedNames.contains($0.name) }
    }

    private let client: OllamaClienting
    private let daemonController: DaemonControlling
    private let pollInterval: TimeInterval
    private let tickInterval: TimeInterval
    private var pollTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?

    init(
        client: OllamaClienting,
        daemonController: DaemonControlling = DaemonController(),
        pollInterval: TimeInterval = 10,
        tickInterval: TimeInterval = 1
    ) {
        self.client = client
        self.daemonController = daemonController
        self.pollInterval = pollInterval
        self.tickInterval = tickInterval
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
            }
        }
        Task { [weak self] in
            await self?.refreshLibrary()
        }
    }

    func stop() {
        pollTask?.cancel(); pollTask = nil
        stopTicking()
    }

    func startTicking() {
        guard tickTask == nil else { return }
        now = Date()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.now = Date()
                try? await Task.sleep(nanoseconds: UInt64(self.tickInterval * 1_000_000_000))
            }
        }
    }

    func stopTicking() {
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
            state = Self.connectionState(for: error)
        }
    }

    static func connectionState(for error: Error) -> ConnectionState {
        switch error {
        case OllamaClientError.badStatus(let code):
            return .protocolError("Ollama returned HTTP \(code).")
        case is DecodingError:
            return .protocolError("Couldn't read Ollama's response — the API may have changed.")
        default:
            return .unreachable
        }
    }

    func clearActionErrors() {
        lastUnloadError = nil
        lastLoadError = nil
        lastDaemonError = nil
        daemonNotInstalled = false
    }

    func startDaemon() async {
        do {
            try await daemonController.start()
            daemonNotInstalled = false
            lastDaemonError = nil
        } catch DaemonControlError.appNotFound {
            daemonNotInstalled = true
            lastDaemonError = nil
        } catch {
            daemonNotInstalled = false
            lastDaemonError = "Failed to start Ollama: \(error.localizedDescription)"
        }
        await refresh()
    }

    func quitDaemon() async {
        do {
            try await daemonController.quit()
            lastDaemonError = nil
        } catch {
            lastDaemonError = "Failed to quit Ollama: \(error.localizedDescription)"
        }
        await refresh()
    }

    func load(_ modelName: String) async {
        loadingModels.insert(modelName)
        do {
            try await client.load(modelName: modelName)
            lastLoadError = nil
        } catch {
            lastLoadError = "Failed to load \(modelName): \(error.localizedDescription)"
        }
        await refresh()
        loadingModels.remove(modelName)
    }

    func refreshLibrary() async {
        guard let fetched = try? await client.fetchLibrary() else { return }
        library = fetched
    }

    func unload(_ modelName: String) async {
        do {
            try await client.unload(modelName: modelName)
            lastUnloadError = nil
        } catch {
            lastUnloadError = "Failed to unload \(modelName): \(error.localizedDescription)"
        }
        await refresh()
    }

    func unloadAll() async {
        let names = models.map(\.name)
        var failed: [String] = []
        for name in names {
            do {
                try await client.unload(modelName: name)
            } catch {
                failed.append(name)
            }
        }
        lastUnloadError = failed.isEmpty ? nil : "Failed to unload \(failed.count) model(s)"
        await refresh()
    }
}
```

- [ ] **Step 4: Regenerate project and run the tests**

```bash
xcodegen generate
xcodebuild test \
  -project OllamaDock.xcodeproj \
  -scheme OllamaDock \
  -destination 'platform=macOS' \
  2>&1 | grep -E "Test Suite|passed|failed|error:"
```

Expected: All tests pass. The new `ModelMonitorDaemonTests` class should show 12 passing tests.

- [ ] **Step 5: Commit**

```bash
git add OllamaDock/Monitor/ModelMonitor.swift \
        OllamaDockTests/ModelMonitorDaemonTests.swift \
        OllamaDock.xcodeproj
git commit -m "feat: add daemon state and control to ModelMonitor"
```

---

### Task 4: MenuBarLabel — two status dots

**Files:**
- Modify: `OllamaDock/Views/MenuBarLabel.swift`

This is a pure UI change. The logic (dot color = function of two booleans, VRAM visibility = function of `daemonUp`) is fully covered by the `daemonUp`/`modelRunning` tests in Task 3. No new unit tests needed here.

- [ ] **Step 1: Replace MenuBarLabel**

Replace the full content of `OllamaDock/Views/MenuBarLabel.swift`:

```swift
import SwiftUI

struct MenuBarLabel: View {
    let daemonUp: Bool
    let modelRunning: Bool
    let totalVRAM: UInt64

    var body: some View {
        HStack(spacing: 4) {
            // Top dot = model loaded; bottom dot = daemon up.
            VStack(spacing: 2) {
                Circle()
                    .fill(modelRunning ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(daemonUp ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
            }
            if daemonUp {
                Text(ByteFormatter.format(totalVRAM))
                    .monospacedDigit()
            }
        }
    }
}
```

- [ ] **Step 2: Build to confirm it compiles (OllamaDockApp.swift will error — that's expected)**

```bash
xcodebuild build \
  -project OllamaDock.xcodeproj \
  -scheme OllamaDock \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "error:|BUILD"
```

Expected: One error — `OllamaDockApp.swift` calling `MenuBarLabel(totalVRAM:)` with the old signature. That's fixed in Task 5. (`BUILD FAILED` is expected here.)

- [ ] **Step 3: Commit the label change (build fix comes next task)**

```bash
git add OllamaDock/Views/MenuBarLabel.swift
git commit -m "feat: two-dot status indicator in MenuBarLabel"
```

---

### Task 5: OllamaDockApp — wire up new label params and inject DaemonController

**Files:**
- Modify: `OllamaDock/OllamaDockApp.swift`

- [ ] **Step 1: Update OllamaDockApp.swift**

Replace the full content of `OllamaDock/OllamaDockApp.swift`:

```swift
import SwiftUI

@main
struct OllamaDockApp: App {
    @State private var monitor: ModelMonitor

    init() {
        let monitor = ModelMonitor(
            client: OllamaClient(),
            daemonController: DaemonController()
        )
        monitor.start()
        _monitor = State(wrappedValue: monitor)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            MenuBarLabel(
                daemonUp: monitor.daemonUp,
                modelRunning: monitor.modelRunning,
                totalVRAM: monitor.totalVRAM
            )
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: Build and run full test suite**

```bash
xcodebuild test \
  -project OllamaDock.xcodeproj \
  -scheme OllamaDock \
  -destination 'platform=macOS' \
  2>&1 | grep -E "Test Suite|passed|failed|error:"
```

Expected: `BUILD SUCCEEDED`, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add OllamaDock/OllamaDockApp.swift
git commit -m "feat: wire DaemonController and two-dot label into app entry point"
```

---

### Task 6: PopoverView — Start Ollama button + Quit Ollama confirmation

**Files:**
- Modify: `OllamaDock/Views/PopoverView.swift`

- [ ] **Step 1: Replace PopoverView.swift**

Replace the full content of `OllamaDock/Views/PopoverView.swift`:

```swift
import SwiftUI

struct PopoverView: View {
    @Bindable var monitor: ModelMonitor
    @State private var showQuitDaemonConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            if let error = monitor.lastUnloadError
                            ?? monitor.lastLoadError
                            ?? monitor.lastDaemonError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            footer
        }
        .padding(12)
        .frame(width: 340)
        .onAppear {
            monitor.startTicking()
            monitor.clearActionErrors()
        }
        .onDisappear { monitor.stopTicking() }
        .confirmationDialog(
            "Quit the Ollama daemon?",
            isPresented: $showQuitDaemonConfirm,
            titleVisibility: .visible
        ) {
            Button("Quit Ollama", role: .destructive) {
                Task { await monitor.quitDaemon() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Running models will be unloaded.")
        }
    }

    private var header: some View {
        HStack {
            Text("OllamaDock")
                .font(.headline)
            Spacer()
            Text("\(monitor.models.count) running · \(ByteFormatter.format(monitor.totalVRAM))")
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
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                if monitor.daemonNotInstalled {
                    Text("Ollama isn't installed")
                        .font(.subheadline)
                    Link(
                        "Get Ollama at ollama.com",
                        destination: URL(string: "https://ollama.com")!
                    )
                    .font(.caption)
                } else {
                    Text("Ollama isn't running")
                        .font(.subheadline)
                    Button("Start Ollama") {
                        Task { await monitor.startDaemon() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80)

        case .protocolError(let message):
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                Text("Ollama responded unexpectedly")
                    .font(.subheadline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
                        SectionHeader("Running")
                        ForEach(monitor.models) { model in
                            ModelRow(
                                model: model,
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
            Button {
                Task {
                    await monitor.refresh()
                    await monitor.refreshLibrary()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .clipShape(Circle())
            .padding(.leading, -8)
            .help("Refresh")

            Spacer()

            Button("Stop All") {
                Task { await monitor.unloadAll() }
            }
            .buttonStyle(.bordered)
            .disabled(monitor.models.isEmpty)

            Button("Quit Ollama") {
                showQuitDaemonConfirm = true
            }
            .buttonStyle(.bordered)
            .disabled(!monitor.daemonUp)
            .help("Quit the Ollama daemon")

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .clipShape(Circle())
            .padding(.trailing, -8)
            .help("Quit OllamaDock")
        }
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

- [ ] **Step 2: Run full test suite**

```bash
xcodebuild test \
  -project OllamaDock.xcodeproj \
  -scheme OllamaDock \
  -destination 'platform=macOS' \
  2>&1 | grep -E "Test Suite|passed|failed|error:"
```

Expected: `BUILD SUCCEEDED`, all tests pass.

- [ ] **Step 3: Build a runnable Release binary and smoke-test manually**

```bash
xcodebuild build \
  -project OllamaDock.xcodeproj \
  -scheme OllamaDock \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tail -3

open build/Build/Products/Release/OllamaDock.app
```

Manually verify:
- Menu bar shows two dots + VRAM when Ollama is running.
- Both dots grey, no VRAM text when Ollama is stopped.
- "Start Ollama" button appears in popover when daemon is down; clicking it launches Ollama.app.
- "Quit Ollama" button in footer; clicking triggers the confirmation dialog; confirming quits the daemon.
- `lastDaemonError` message shows in red if quit fails (test by quitting when already stopped — `osascript` returns 0 for this, so no error; just verify the button does not crash).

- [ ] **Step 4: Clean up build artifacts**

```bash
rm -rf build
```

- [ ] **Step 5: Commit**

```bash
git add OllamaDock/Views/PopoverView.swift
git commit -m "feat: Start Ollama button + Quit Ollama confirmation in popover"
```

---

## Done

All six tasks complete. Run the full suite one final time to confirm a clean state:

```bash
xcodebuild test \
  -project OllamaDock.xcodeproj \
  -scheme OllamaDock \
  -destination 'platform=macOS' \
  2>&1 | grep -E "Test Suite|passed|failed"
```

Expected: All tests pass (the suite should now include the new `ModelMonitorDaemonTests`).
