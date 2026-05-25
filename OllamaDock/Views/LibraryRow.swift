import SwiftUI

struct LibraryRow: View {
    let model: LibraryModel
    let isLoading: Bool
    let onLoad: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(ByteFormatter.format(model.sizeOnDisk) + " on disk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            } else {
                Button(action: onLoad) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .help("Load \(model.name)")
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
