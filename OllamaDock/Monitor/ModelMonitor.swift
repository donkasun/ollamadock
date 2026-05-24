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
