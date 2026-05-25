import SwiftUI

struct MenuBarLabel: View {
    let daemonUp: Bool
    let modelRunning: Bool
    let totalVRAM: UInt64

    var body: some View {
        HStack(spacing: 4) {
            // Top dot = model loaded; bottom dot = daemon up.
            VStack(spacing: 2) {
                Circle()
                    .fill(modelRunning ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(daemonUp ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
            }
            if daemonUp {
                Text(ByteFormatter.format(totalVRAM))
                    .monospacedDigit()
            }
        }
    }
}
