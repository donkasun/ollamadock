import SwiftUI

struct PopoverView: View {
    @Bindable var monitor: ModelMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            if let error = monitor.lastUnloadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            footer
        }
        .padding(12)
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            Text("Ollama")
                .font(.headline)
            Spacer()
            Text("\(monitor.models.count) loaded · \(MenuBarLabel.format(monitor.totalVRAM))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch monitor.state {
        case .loading:
            HStack { ProgressView(); Text("Checking…") }
                .frame(maxWidth: .infinity, minHeight: 80)
        case .unreachable:
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                Text("Ollama isn't running")
                    .font(.subheadline)
                Text("Start Ollama, then press Refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        case .connected where monitor.models.isEmpty:
            VStack(spacing: 4) {
                Text("No models loaded")
                    .font(.subheadline)
                Text("Run a model to see it here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        case .connected:
            VStack(spacing: 6) {
                ForEach(monitor.models) { model in
                    ModelRow(
                        model: model,
                        totalRAM: monitor.totalRAM,
                        now: monitor.now,
                        onUnload: { Task { await monitor.unload(model.name) } }
                    )
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Refresh") {
                Task { await monitor.refresh() }
            }
            Button("Unload all") {
                Task { await monitor.unloadAll() }
            }
            .disabled(monitor.models.isEmpty)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .buttonStyle(.bordered)
    }
}
