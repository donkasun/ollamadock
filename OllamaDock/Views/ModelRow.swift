import SwiftUI

struct ModelRow: View {
    let model: RunningModel
    let now: Date
    let onUnload: () -> Void

    var body: some View {
        HStack {
            Text(model.name)
                .font(.system(.body, design: .rounded).weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(model.countdownString(now: now))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button(action: onUnload) {
                Image(systemName: "eject.fill")
            }
            .buttonStyle(.borderless)
            .help("Unload \(model.name)")
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
