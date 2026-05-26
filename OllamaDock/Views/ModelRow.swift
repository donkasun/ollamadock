import SwiftUI

struct ModelRow: View {
    let model: RunningModel
    let now: Date
    let onUnload: () -> Void

    @State private var confirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                Text(model.countdownString(now: now))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { confirming = true }
                } label: {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderless)
                .help("Stop \(model.name)")
            }

            if confirming {
                confirmation
            }
        }
        .padding(10)
        .background(Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .overlay(Color.white.opacity(0.25))
            HStack {
                Text("Stop this model?")
                    .font(.caption)
                    .foregroundStyle(.white)
                Spacer()
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.15)) { confirming = false }
                }
                .foregroundStyle(.white.opacity(0.75))
                Button("Stop") {
                    confirming = false
                    onUnload()
                }
                .foregroundStyle(.white)
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
