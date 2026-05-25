import SwiftUI

struct MenuBarLabel: View {
    let totalVRAM: UInt64

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Text(ByteFormatter.format(totalVRAM))
                .monospacedDigit()
        }
    }
}
