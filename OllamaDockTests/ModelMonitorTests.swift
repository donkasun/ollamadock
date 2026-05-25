import XCTest
@testable import OllamaDock

@MainActor
final class ModelMonitorTests: XCTestCase {
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

    func test_refresh_sets_connected_with_models() async {
        let client = StubClient()
        client.fetchResult = .success([
            RunningModel(name: "a", sizeVRAM: 1, expiresAt: Date().addingTimeInterval(60))
        ])
        let monitor = ModelMonitor(client: client)

        await monitor.refresh()

        XCTAssertEqual(monitor.state, .connected)
        XCTAssertEqual(monitor.models.map(\.name), ["a"])
        XCTAssertEqual(monitor.totalVRAM, 1)
    }

    func test_refresh_sets_unreachable_on_throw() async {
        let client = StubClient()
        client.fetchResult = .failure(URLError(.cannotConnectToHost))
        let monitor = ModelMonitor(client: client)

        await monitor.refresh()

        XCTAssertEqual(monitor.state, .unreachable)
        XCTAssertTrue(monitor.models.isEmpty)
    }

    func test_unload_calls_client_then_refreshes() async {
        let client = StubClient()
        client.fetchResult = .success([])
        let monitor = ModelMonitor(client: client)

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
        let monitor = ModelMonitor(client: client)
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
        let monitor = ModelMonitor(client: client)

        await monitor.refresh()

        XCTAssertEqual(monitor.totalVRAM, 7)
    }

    func test_unload_failure_sets_lastUnloadError() async {
        let client = StubClient()
        client.fetchResult = .success([])
        client.unloadError = URLError(.timedOut)
        let monitor = ModelMonitor(client: client)

        await monitor.unload("qwen3.6:27b-mlx")

        XCTAssertEqual(monitor.lastUnloadError, "Failed to unload qwen3.6:27b-mlx")
    }

    func test_unload_success_clears_lastUnloadError() async {
        let client = StubClient()
        client.fetchResult = .success([])
        let monitor = ModelMonitor(client: client)
        client.unloadError = URLError(.timedOut)
        await monitor.unload("a")
        XCTAssertNotNil(monitor.lastUnloadError)
        client.unloadError = nil
        await monitor.unload("a")

        XCTAssertNil(monitor.lastUnloadError)
    }

    func test_refreshLibrary_populates_library() async {
        let client = StubClient()
        client.libraryResult = .success([
            LibraryModel(name: "gemma4:e2b-mlx", sizeOnDisk: 7_069_822_916),
            LibraryModel(name: "qwen3.6:27b-mlx", sizeOnDisk: 19_763_233_079)
        ])
        let monitor = ModelMonitor(client: client)

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
        let monitor = ModelMonitor(client: client)
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
        let monitor = ModelMonitor(client: client)
        await monitor.refresh()
        await monitor.refreshLibrary()

        XCTAssertEqual(monitor.availableModels.map(\.name), ["qwen3.6:27b-mlx"])
    }

    func test_availableModels_is_empty_when_library_not_loaded() async {
        let client = StubClient()
        let monitor = ModelMonitor(client: client)
        // no refreshLibrary call
        XCTAssertTrue(monitor.availableModels.isEmpty)
    }

    func test_load_calls_client_and_refreshes() async {
        let client = StubClient()
        client.fetchResult = .success([
            RunningModel(name: "gemma4:e2b-mlx", sizeVRAM: 1, expiresAt: Date().addingTimeInterval(300))
        ])
        let monitor = ModelMonitor(client: client)

        await monitor.load("gemma4:e2b-mlx")

        XCTAssertEqual(client.loadCalls, ["gemma4:e2b-mlx"])
        XCTAssertEqual(monitor.models.map(\.name), ["gemma4:e2b-mlx"],
                       "refresh after load should show model in loaded list")
    }

    func test_load_clears_loadingModels_after_completion() async {
        let client = StubClient()
        client.fetchResult = .success([])
        let monitor = ModelMonitor(client: client)

        await monitor.load("qwen3.6:27b-mlx")

        XCTAssertTrue(monitor.loadingModels.isEmpty,
                      "loadingModels must be empty after load completes")
    }

    func test_load_failure_sets_lastLoadError() async {
        let client = StubClient()
        client.fetchResult = .success([])
        client.loadError = URLError(.timedOut)
        let monitor = ModelMonitor(client: client)

        await monitor.load("qwen3.6:27b-mlx")

        XCTAssertEqual(monitor.lastLoadError, "Failed to load qwen3.6:27b-mlx")
    }

    func test_load_success_clears_lastLoadError() async {
        let client = StubClient()
        client.fetchResult = .success([])
        let monitor = ModelMonitor(client: client)
        client.loadError = URLError(.timedOut)
        await monitor.load("a")
        XCTAssertNotNil(monitor.lastLoadError)
        client.loadError = nil
        await monitor.load("a")

        XCTAssertNil(monitor.lastLoadError)
    }

    func test_load_failure_still_clears_loadingModels() async {
        let client = StubClient()
        client.fetchResult = .success([])
        client.loadError = URLError(.timedOut)
        let monitor = ModelMonitor(client: client)

        await monitor.load("qwen3.6:27b-mlx")

        XCTAssertTrue(monitor.loadingModels.isEmpty,
                      "loadingModels must be empty even when load() throws")
    }
}
