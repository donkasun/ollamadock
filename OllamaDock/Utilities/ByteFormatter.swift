import Foundation

// Shared byte-size formatting for the menu bar label and the model rows.
// Lives outside any view so no single view "owns" the formatter.
enum ByteFormatter {
    static func format(_ bytes: UInt64) -> String {
        guard bytes > 0 else { return "0 GB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
