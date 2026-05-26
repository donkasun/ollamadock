// OllamaDockTests/ModelMonitorDaemonTests.swift
import XCTest
@testable import OllamaDock

@MainActor
final class ModelMonitorDaemonTests: XCTestCase {

    // MARK: - Stub

    final class StubDaemonController: DaemonControlling, @unchecked Sendable {
        var startCalls = 0
        var startError: Error?

        func start() async throws {
            startCalls += 1
            if let e = startError { throw e }
        }
    }

    struct StubError: Error {}

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
        daemon.startError = StubError()
        let monitor = ModelMonitor(client: client, daemonController: daemon)

        await monitor.startDaemon()

        XCTAssertFalse(monitor.daemonNotInstalled)
        XCTAssertNotNil(monitor.lastDaemonError)
    }

    func test_startDaemon_resetsIsDaemonStartingAfterCompletion() async {
        let client = StubClient()
        let daemon = StubDaemonController()
        let monitor = ModelMonitor(client: client, daemonController: daemon)

        await monitor.startDaemon()

        XCTAssertFalse(monitor.isDaemonStarting)
    }

    func test_startDaemon_resetsIsDaemonStartingOnError() async {
        let client = StubClient()
        let daemon = StubDaemonController()
        daemon.startError = StubError()
        let monitor = ModelMonitor(client: client, daemonController: daemon)

        await monitor.startDaemon()

        XCTAssertFalse(monitor.isDaemonStarting)
    }

    // MARK: - clearActionErrors

    func test_clearActionErrors_clearsDaemonFields() async {
        let client = StubClient()
        let daemon = StubDaemonController()
        daemon.startError = StubError()
        let monitor = ModelMonitor(client: client, daemonController: daemon)
        await monitor.startDaemon()          // sets lastDaemonError

        monitor.clearActionErrors()

        XCTAssertNil(monitor.lastDaemonError)
        XCTAssertFalse(monitor.daemonNotInstalled)
    }
}
