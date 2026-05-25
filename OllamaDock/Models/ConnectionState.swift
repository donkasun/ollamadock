import Foundation

enum ConnectionState: Equatable {
    case loading
    case connected
    case unreachable
    // Reachable, but the daemon returned something we couldn't use —
    // a non-2xx status or a payload that didn't decode. Distinct from
    // `.unreachable` so the UI can say "talking funny" vs "not running".
    case protocolError(String)
}
