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
