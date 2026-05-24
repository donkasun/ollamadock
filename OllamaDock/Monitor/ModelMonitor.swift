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
    private(set) var library: [LibraryModel] = []

    let totalRAM: UInt64

    var availableModels: [LibraryModel] {
        let loadedNames = Set(models.map(\.name))
        return library.filter { !loadedNames.contains($0.name) }
    }

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

    func refreshLibrary() async {
        guard let fetched = try? await client.fetchLibrary() else { return }
        library = fetched
    }

    func unload(_ modelName: String) async {
        do {
            try await client.unload(modelName: modelName)
            lastUnloadError = nil
        } catch {
            lastUnloadError = "Failed to unload \(modelName)"
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
