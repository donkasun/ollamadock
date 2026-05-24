import SwiftUI

struct ModelRow: View {
    let model: RunningModel
    let totalRAM: UInt64
    let now: Date
    let onUnload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.name)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(action: onUnload) {
                    Image(systemName: "eject.fill")
                }
                .buttonStyle(.borderless)
                .help("Unload \(model.name)")
            }

            ProgressView(value: model.vramFraction(ofTotalRAM: totalRAM))
                .progressViewStyle(.linear)

            HStack {
                Text(MenuBarLabel.format(model.sizeVRAM))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(model.countdownString(now: now))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
