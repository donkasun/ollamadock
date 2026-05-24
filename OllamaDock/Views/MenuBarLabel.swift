import SwiftUI

struct MenuBarLabel: View {
    let totalVRAM: UInt64

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Text(Self.format(totalVRAM))
                .monospacedDigit()
        }
    }

    static func format(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
