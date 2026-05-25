import SwiftUI

struct ModelRow: View {
    let model: RunningModel
    let now: Date
    let onUnload: () -> Void

    @State private var confirming = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.white)
                Text(ByteFormatter.format(model.sizeVRAM) + " VRAM")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            if confirming {
                HStack(spacing: 6) {
                    Button("Stop?") {
                        confirming = false
                        onUnload()
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    Button("Cancel") {
                        confirming = false
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }
                .buttonStyle(.borderless)
                .font(.caption)
            } else {
                Text(model.countdownString(now: now))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
                Button {
                    confirming = true
                } label: {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderless)
                .help("Stop \(model.name)")
            }
        }
        .padding(10)
        .background(Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
