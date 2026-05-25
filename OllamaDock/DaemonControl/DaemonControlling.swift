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
