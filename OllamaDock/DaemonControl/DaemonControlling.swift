import Foundation

enum DaemonControlError: Error, Equatable {
    /// `open -a Ollama` exited non-zero — the app is not installed.
    case appNotFound
}

protocol DaemonControlling: Sendable {
    /// Launches the Ollama.app via `open -a Ollama`.
    /// Throws `DaemonControlError.appNotFound` when the app isn't installed.
    func start() async throws
}
