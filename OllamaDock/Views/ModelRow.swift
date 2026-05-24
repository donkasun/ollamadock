import SwiftUI

struct ModelRow: View {
    let model: RunningModel
    let now: Date
    let onUnload: () -> Void

    @State private var confirming = false

    var body: some View {
        HStack {
            Text(model.name)
                .font(.system(.body, design: .rounded).weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if confirming {
                HStack(spacing: 6) {
                    Button("Stop?") {
                        confirming = false
                        onUnload()
                    }
                    .foregroundStyle(.red)
                    Button("Cancel") {
                        confirming = false
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            } else {
                Text(model.countdownString(now: now))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button {
                    confirming = true
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("Stop \(model.name)")
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
