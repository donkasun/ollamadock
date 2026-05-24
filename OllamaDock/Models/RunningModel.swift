import Foundation

struct RunningModel: Equatable, Identifiable {
    let name: String
    let sizeVRAM: UInt64
    let expiresAt: Date

    var id: String { name }

    func vramFraction(ofTotalRAM totalRAM: UInt64) -> Double {
        guard totalRAM > 0 else { return 0 }
        let raw = Double(sizeVRAM) / Double(totalRAM)
        return min(max(raw, 0), 1)
    }

    func countdownString(now: Date = Date()) -> String {
        let remaining = expiresAt.timeIntervalSince(now)
        if remaining <= 0 { return "unloading…" }
        let total = Int(remaining.rounded(.down))
        let minutes = total / 60
        let seconds = total % 60
        return minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
    }
}

extension RunningModel: Decodable {
    private enum CodingKeys: String, CodingKey {
        case name
        case sizeVRAM = "size_vram"
        case expiresAt = "expires_at"
    }
}
