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

    // The 1 s countdown tick only matters while the popover is on screen.
    // Drive it from the popover's lifecycle so a closed menu bar item
    // doesn't keep waking the app once per second.
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

    // A reachability failure (daemon down, no socket) means "Ollama isn't
    // running". A bad status or undecodable body means the daemon answered
    // but spoke a dialect we don't understand — a different problem.
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

    // Cleared when the popover reopens so a stale failure doesn't linger.
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
