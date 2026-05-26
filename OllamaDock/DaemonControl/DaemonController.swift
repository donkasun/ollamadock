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
